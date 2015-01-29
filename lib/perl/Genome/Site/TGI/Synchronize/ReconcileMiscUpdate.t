#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
};

use strict;
use warnings;

use above 'Genome';

use List::MoreUtils 'uniq';
use Test::More;

use_ok('Genome::Site::TGI::Synchronize::ReconcileMiscUpdate') or die;

my $cnt = 0;

# Invalid start_from
my $reconcile = Genome::Site::TGI::Synchronize::ReconcileMiscUpdate->create(start_from => 'BLAH-01');
ok($reconcile, 'Create reconcile command to test start from_value of "BLAH-01"');
my @errors = $reconcile->__errors__;
ok(@errors, 'Errors') or die;
is($errors[0]->__display_name__, 'INVALID: property \'start_from\': Invalid date format => BLAH-01', 'Error is correct');
$reconcile->delete;

my $start_from = Date::Format::time2str("%Y-%m-%d %X", time()); # now
my $stop_at = '2000-01-01 23:59:59'; # set stop at so we only do the updates for Jan 01 01
$reconcile = Genome::Site::TGI::Synchronize::ReconcileMiscUpdate->create(
    start_from => $start_from,
    _stop_at => $stop_at,
);
ok($reconcile, 'Create reconcile command to test start_from after _stop_at');
@errors = $reconcile->__errors__;
ok(@errors, 'Errors') or die;
is(
    $errors[0]->__display_name__,
    "INVALID: property \'start_from\': Start from date ($start_from) is after stop at date ($stop_at)!",
    'Error is correct',
);
$reconcile->delete;

# Define entities
my $entity_attrs = _entity_attrs();
my $entities = _define_entities($entity_attrs);
ok($entities, 'Define entities');
my $genome_entities = map { $_->{genome_entity} } map { @{$entities->{$_}} } keys %$entities;
is($genome_entities, @$entity_attrs, "Define $genome_entities genome entities");
my $site_tgi_entities = map { $_->{site_tgi_entities} } map { @{$entities->{$_}} } keys %$entities;
is($site_tgi_entities, @$entity_attrs, "Define $site_tgi_entities site tgi entities");

# Define misc updates
my $update_params = _update_params();
my @misc_updates = _define_misc_updates($entities, $update_params);
ok(@misc_updates, 'Define misc updates');
my $update_cnt = @$update_params;
is(@misc_updates, $update_cnt, "Defined $update_cnt defined misc updates");
my @sub_attr_misc_updates = _define_subject_attr_misc_updates();
ok(@sub_attr_misc_updates, 'Define subject attr misc updates');
is(@sub_attr_misc_updates, 24, 'Defined 24 misc indels');
my @misc_updates_that_skip_or_fail = _define_misc_updates_that_skip_or_fail();
ok(@misc_updates_that_skip_or_fail, 'Define misc updates that fail');
my $misc_update_not_in_date_range = _define_misc_update_not_in_date_range();
ok($misc_update_not_in_date_range, 'Define misc update not in date range');

# Reconcile
$reconcile = Genome::Site::TGI::Synchronize::ReconcileMiscUpdate->create(start_from => '2000-01-01 00:00:00');
ok($reconcile, 'Create reconcile command');
@errors = $reconcile->__errors__;
ok(!@errors, 'No errors for test date');

$reconcile->_stop_at('2000-01-08 23:59:59'); # set stop at so we only do the updates for Jan 01 01
diag('Check that the correct misc updates were retrieved');
ok($reconcile->_load_misc_updates, 'load misc updates');
is(@{$reconcile->_misc_updates}, 43, 'loaded 43 misc updates');
is_deeply(
    [ map { $_->id } grep { $_->description eq 'UPDATE' } @{$reconcile->_misc_updates} ], 
    [ map { $_->id } grep { $_->description eq 'UPDATE' } @misc_updates, @sub_attr_misc_updates, @misc_updates_that_skip_or_fail ],
    'Retrieved the correct misc updates in the correct order for UPDATE',
) or die;
is_deeply(
    [ map { $_->id } grep { $_->description ne 'UPDATE' } @{$reconcile->_misc_updates} ], 
    [ map { $_->id } grep { $_->description ne 'UPDATE' } @misc_updates, @sub_attr_misc_updates, @misc_updates_that_skip_or_fail ],
    'Retrieved the correct misc updates in the correct order for INSERT/DELETE',
) or die;
ok(!grep({ $_->id eq $misc_update_not_in_date_range->id } @{$reconcile->_misc_updates}), 'Did not get misc update out of date range') or die;

ok($reconcile->execute, 'Execute reconcile command');

diag('Checking successful UPDATES...');
for my $misc_update ( @misc_updates ) {
    next if $misc_update->{_skip_check};
    my $new_value = $misc_update->new_value;
    my $genome_entity = $misc_update->genome_entity;
    my $site_tgi_class_name = $misc_update->site_tgi_class_name;
    my $genome_property_name = $site_tgi_class_name->lims_property_name_to_genome_property_name($misc_update->subject_property_name);
    is($genome_entity->$genome_property_name, $misc_update->new_value, 'Set new value ('.$new_value.') on '.$genome_entity->class.' '.$genome_entity->id);
    is($misc_update->result, 'PASS', 'Correct result');
    ok($misc_update->status, 'Set status');
    is($misc_update->is_reconciled, 1, 'Misc update correctly reconciled');
}

diag('Checking successful INDELS...');
my %multi_misc_updates_to_check;
foreach my $sub_attr_misc_updates ( @sub_attr_misc_updates ) {
    my %multi_misc_update_params = map { $_ => $sub_attr_misc_updates->$_ } (qw/ subject_class_name subject_id edit_date description /);
    my $multi_misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate::SubjectAttribute->get(%multi_misc_update_params);
    $multi_misc_updates_to_check{$multi_misc_update->subject_id}=$multi_misc_update;
}

for my $multi_misc_update (values %multi_misc_updates_to_check) {
    ok($multi_misc_update->perform_update, 'performed update: '.$multi_misc_update->description);
    my %genome_entity_params = $multi_misc_update->_resolve_genome_entity_params;
    ok(%genome_entity_params, 'Got genome entity params') or die;
    is(scalar(keys %genome_entity_params), 4, 'Correct number of genome entity params');
    my $genome_entity = Genome::SubjectAttribute->get(%genome_entity_params);
    if ( $multi_misc_update->description eq 'INSERT' ) {
        ok($genome_entity, 'INSERT genome entity: '.$genome_entity->__display_name__);
    }
    else {
        ok(!$genome_entity, 'DELETE genome entity: '.$multi_misc_update->__display_name__);
    }
    is($multi_misc_update->result, 'PASS', 'Correct result');
    ok(!$multi_misc_update->error_message, 'No errors set on multi misc update!');
    is(scalar(grep {defined} map {$_->error_message} $multi_misc_update->misc_updates), 0, 'No errors set on misc updates!');
}

diag('Checking SKIP/FAIL updates...');
my ($skip_cnt, $fail_cnt, $error_cnt, $not_reconciled) = (qw/ 0 0 0 0 /);
for my $misc_update ( @misc_updates_that_skip_or_fail ) {
    $not_reconciled++ if $misc_update->is_reconciled eq 0;
    $error_cnt++ if defined $misc_update->error_message;
    if ( $misc_update->result eq 'SKIP' ) {
        $skip_cnt++;
        ok(!defined $misc_update->error_message, "SKIP misc update does not have an error");
        is($misc_update->status_message,  $misc_update->{_expected_msg}, 'Correct SKIP status message');
    }
    else {#FAIL
        $fail_cnt++;
        is($misc_update->error_message,  $misc_update->{_expected_msg}, 'Correct FAIL error message');
    }
}
is($skip_cnt, @misc_updates_that_skip_or_fail - $fail_cnt, 'SKIP expected number misc updates');
is($fail_cnt, @misc_updates_that_skip_or_fail - $skip_cnt, 'FAIL expected number of misc updates');
is($not_reconciled, @misc_updates_that_skip_or_fail, 'SKIP/FAIL misc updates are not reconciled');

done_testing();

sub _entity_attrs {
    return [
        # Taxon
        { _type => 'Taxon', _site_tgi_subclass => 'OrganismTaxon', id => -100, estimated_genome_size => 1000, },
        { _type => 'Taxon', _site_tgi_subclass => 'OrganismTaxon', id => -101, estimated_genome_size => 1000, },
        # Individual
        { _type => 'Individual', _site_tgi_subclass => 'OrganismIndividual', id => -200, taxon_id => -100, },
        { _type => 'Individual', _site_tgi_subclass => 'OrganismIndividual', id => -201, taxon_id => -100, },
        { _type => 'Individual', _site_tgi_subclass => 'OrganismIndividual', id => -202, taxon_id => -100, },
        # Pop Group
        { _type => 'PopulationGroup', id => -300, taxon_id => -100, },
        { _type => 'PopulationGroup', id => -301, taxon_id => -100, },
        # Sample
        { _type => 'Sample', _site_tgi_subclass => 'OrganismSample', id => -400, source_id => -200, nomenclature => 'WUGC', },
        { _type => 'Sample', _site_tgi_subclass => 'OrganismSample', id => -401, source_id => -201, nomenclature => 'WUGC', },
        { _type => 'Sample', _site_tgi_subclass => 'OrganismSample', id => -402, source_id => -202, nomenclature => 'WUGC', },
    ];
}

sub _define_entities {
    my $entity_attrs = shift;
    my $entities = {};
    for my $attrs ( @$entity_attrs ) {
        my $type = delete $attrs->{_type};
        my $site_tgi_subclass = delete $attrs->{_site_tgi_subclass} || $type;
        $attrs->{name} = '__TEST_'.uc($type).'__',
        my $genome_class = 'Genome::'.$type;
        my $genome_entity = $genome_class->create(%$attrs);
        my $site_tgi_class = 'Genome::Site::TGI::Synchronize::Classes::'.$site_tgi_subclass;
        my $site_tgi_entity = $site_tgi_class->create(%$attrs);
        push @{$entities->{$type}}, {
            genome_entity => $genome_entity,
            site_tgi_entity => $site_tgi_entity,
        };
    }

    return $entities;
}

sub _update_params {
    return [
        # Taxon
        [ 'Taxon', 0, 'domain', 'Eukaryota' ],# is undef
        [ 'Taxon', 0, 'estimated_genome_size', '1000000' ],# has value
        [ 'Taxon', 0, 'estimated_genome_size', '5000000' ],# another value
        [ 'Taxon', 1, 'name', 'NEW_NAME' ],# has value
        # Individual
        [ 'Individual', 0, 'common_name', 'NEW_COMMON_NAME' ], # is undef
        [ 'Individual', 0, 'name', 'NEW_NAME' ], # has value
        [ 'Individual', 1, 'taxon_id', -101 ], # has value, is FK
        # PopulationGroup
        [ 'PopulationGroup', 0, 'description', 'NEW_DESCRIPTION' ], # is undef
        [ 'PopulationGroup', 0, 'name', 'NEW_NAME' ], # has value
        [ 'PopulationGroup', 1, 'taxon_id', -101 ], # has value, is FK
        # Sample
        [ 'Sample', 0, 'extraction_label', 'NEW_EXTRACTION_LABEL' ], # has value
        [ 'Sample', 1, 'source_id', -201 ],# has value, is FK
    ];
}

sub _define_misc_updates {
    my ($entities, $update_params) = @_;

    my %type_to_subject_class_name = (
        'Taxon' => 'organism_taxon',
        'PopulationGroup' => 'population_group',
        'Individual' => 'organism_individual',
        'Sample' => 'organism_sample',
    );

    my $prev_update_id = 'blah';
    my $prev_update_value = 'blah';
    my @misc_updates;
    for my $update ( @$update_params ) {
        my ($type, $pos, $property_name, $new_value) = @$update;
        my $obj = $entities->{$type}->[$pos]->{site_tgi_entity};
        next if not $obj;
        my $subject_property_name = $obj->lims_property_name_to_genome_property_name($property_name);
        my $current_update_id = join(' ', $type, $pos, $property_name);
        my $old_value = ( $prev_update_id eq $current_update_id ) ? $prev_update_value : $obj->$property_name;
        my $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->create(
            subject_class_name => 'test.'.$type_to_subject_class_name{$type},
            subject_id => $obj->id,
            subject_property_name => $subject_property_name,
            editor_id => 'lims',
            edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
            old_value => $old_value,
            new_value => $new_value,
            description => 'UPDATE',
            is_reconciled => 0,
        );
        $misc_updates[$#misc_updates]->{_skip_check} = 1 if $prev_update_id eq $current_update_id;
        $prev_update_id = $current_update_id;
        $prev_update_value = $new_value;
        push @misc_updates, $misc_update;
    }

    return @misc_updates;
}

sub _define_subject_attr_misc_updates {
    my %subject_class_names_to_properties= (
        population_group_member => [qw/ member_id pg_id /],
        sample_attribute => [qw/ attribute_label attribute_value nomenclature organism_sample_id /],
    );

    my @updates = (
        # PopulationGroup
        # sub_name                      desc        member_id   pg_id 
        [ 'population_group_member',    'INSERT',   -301,      -200, ],
        [ 'population_group_member',    'INSERT',   -302,      -200, ],
        [ 'population_group_member',    'DELETE',   -302,      -200, ],
        [ 'population_group_member',    'INSERT',   -302,      -201, ],
        # Sample
        # sub_name              desc        label   val     nom     sample_id 
        [ 'sample_attribute',   'INSERT',   'foo',  'bar',  'baz',  -100, ],
        [ 'sample_attribute',   'INSERT',   'foo',  'bar',  'baz',  -101, ],
        [ 'sample_attribute',   'INSERT',   'foo',  'bar',  'qux',  -101, ],
        [ 'sample_attribute',   'DELETE',   'foo',  'bar',  'baz',  -100, ],
    );

    my @sub_attr_misc_updates;
    for my $update ( @updates ) {
        my ($subject_class_name, $description, @ids) = @$update;
        my $subject_id = join('-', @ids);
        my %params = (
            subject_class_name => 'test.'.$subject_class_name,
            subject_id => $subject_id,
            description => $description,
            edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
        );
        my $subject_property_names = $subject_class_names_to_properties{$subject_class_name};
        for ( my $i = 0; $i < @{$subject_class_names_to_properties{$subject_class_name}}; $i++ ) {
            my $sub_attr_misc_updates = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->create(
                %params,
                subject_property_name => $subject_class_names_to_properties{$subject_class_name}->[$i],
                editor_id => 'lims',
                old_value => $ids[$i],
                new_value => $ids[$i],
                is_reconciled => 0,
            );
            push @sub_attr_misc_updates, $sub_attr_misc_updates;
        }
    }

    return @sub_attr_misc_updates;
}

sub _define_misc_updates_that_skip_or_fail {
    my @skip_or_fail;

    # Invalid genome class
    my $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.blah',
        subject_id => -100,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-02 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_TAXON__',
        new_value => 'FAIL',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    $misc_update->{_expected_msg} = 'Unsupported subject class name! test.blah';
    push @skip_or_fail, $misc_update;

    # No obj for subject id
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.organism_taxon',
        subject_id => -10000,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-03 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_TAXON__',
        new_value => 'FAIL',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    $misc_update->{_expected_msg} = 'Failed to get Genome::Taxon for id => -10000';
    push @skip_or_fail, $misc_update;

    # Can not update sample attr
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.sample_attribute',
        subject_id => -100,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-04 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_SAMPLE_ATTR__',
        new_value => 'FAIL',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    $misc_update->{_expected_msg} = 'Cannot UPDATE sample attribute! It must be deleted and then inserted!';
    push @skip_or_fail, $misc_update;

    # Can not update pop group member
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.population_group_member',
        subject_id => -301,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-05 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_POP_GROUP_MEMBER__',
        new_value => 'FAIL',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    $misc_update->{_expected_msg} = 'Cannot UPDATE population group member attribute! It must be deleted and then inserted!';
    push @skip_or_fail, $misc_update;

    # Old value ne to current
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.organism_taxon',
        subject_id => -100,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-06 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_TAXON2__',
        new_value => 'FAIL',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    $misc_update->{_expected_msg} = 'Current APipe value (__TEST_TAXON__) does not match the LIMS old value (__TEST_TAXON2__)!';
    push @skip_or_fail, $misc_update;

    # No genome entity for id
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.organism_sample',
        subject_id => -100,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-07 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_SAMPLE__',
        new_value => 'FAIL',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    $misc_update->{_expected_msg} = 'Failed to get Genome::Sample for id => -100';
    push @skip_or_fail, $misc_update;

    # Unsupported attr
    $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.organism_sample',
        subject_id => -400,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-08 00:00:'.sprintf('%02d', $cnt++),
        old_value => '__TEST_SAMPLE__',
        new_value => 'SKIP',
        description => 'UPDATE',
        is_reconciled => 0,
    );
    $misc_update->{_expected_msg} = 'Update for genome property name not supported => name';
    push @skip_or_fail, $misc_update;

    return @skip_or_fail;
}

sub _define_misc_update_not_in_date_range {
    # Later date
    return Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
        subject_class_name => 'test.organism_sample',
        subject_id => -555,
        subject_property_name => 'name',
        editor_id => 'lims',
        edit_date => '2000-01-09 00:00:'.sprintf('%02d', $cnt++), # must be diff year for now
        old_value => '__TEST_SAMPLE__',
        new_value => 'OUT OF DATE RANGE',
        description => 'UPDATE',
        is_reconciled => 0,
    );
}

