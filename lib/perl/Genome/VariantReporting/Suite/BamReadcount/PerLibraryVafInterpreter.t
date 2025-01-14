#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::Deep qw(cmp_bag);
use Test::More;
use Test::Exception;
use Genome::VariantReporting::Suite::BamReadcount::TestHelper qw(
    create_default_entry
    create_deletion_entry
    create_long_deletion_entry
);

my $pkg = 'Genome::VariantReporting::Suite::BamReadcount::PerLibraryVafInterpreter';
use_ok($pkg);
my $factory = Genome::VariantReporting::Framework::Factory->create();
isa_ok($factory->get_class('interpreters', $pkg->name), $pkg);

my $library_names = [qw(Solexa-135853 Solexa-135852)];

subtest "one alt allele - multiple samples" => sub {
    my $interpreter = $pkg->create(
        sample_names => ["S1", "S2", "S3"],
        library_names => $library_names
    );
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        G => {
            'Solexa-135852_var_count' => '155',
            'Solexa-135853_var_count' => '186',
            'Solexa-135852_ref_count' => '2',
            'Solexa-135853_ref_count' => '1',
            'Solexa-135852_vaf' => '87.0786516853933',
            'Solexa-135853_vaf' => '99.4652406417112',
        }
    );

    my $entry = create_default_entry;
    my %result = $interpreter->interpret_entry($entry, ['G']);
    is(keys %result, keys %expected, "First level keys as expected");
    is_deeply(\%result, \%expected, "Values are as expected");
    cmp_bag([$interpreter->available_fields], [keys %{$expected{G}}], 'Available fields as expected');
};

subtest "one alt allele" => sub {
    my $interpreter = $pkg->create(
        sample_names => ["S1"],
        library_names => $library_names
    );
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        G => {
            'Solexa-135852_var_count' => '155',
            'Solexa-135853_var_count' => '186',
            'Solexa-135852_ref_count' => '2',
            'Solexa-135853_ref_count' => '1',
            'Solexa-135852_vaf' => '87.0786516853933',
            'Solexa-135853_vaf' => '99.4652406417112',
        }
    );

    my $entry = create_default_entry();
    my %result = $interpreter->interpret_entry($entry, ['G']);
    is_deeply(\%result, \%expected, "Values are as expected");
};

subtest "insertion" => sub {
    my $interpreter = $pkg->create(
        sample_names => ["S4"],
        library_names => $library_names
    );
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        AA => {
            'Solexa-135852_var_count' => '20',
            'Solexa-135853_var_count' => '0',
            'Solexa-135852_ref_count' => '2',
            'Solexa-135853_ref_count' => '1',
            'Solexa-135852_vaf' => '11.2359550561798',
            'Solexa-135853_vaf' => '0',
        }
    );

    my $entry = create_default_entry();
    my %result = $interpreter->interpret_entry($entry, ['AA']);
    is_deeply(\%result, \%expected, "Values are as expected");
};

subtest "deletion" => sub {
    my $interpreter = $pkg->create(
        sample_names => ["S1"],
        library_names => $library_names
    );
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        A => {
            'Solexa-135852_var_count' => '20',
            'Solexa-135853_var_count' => '0',
            'Solexa-135852_ref_count' => '3',
            'Solexa-135853_ref_count' => '2',
            'Solexa-135852_vaf' => '11.0497237569061',
            'Solexa-135853_vaf' => '0',
        }
    );

    my $entry = create_deletion_entry();
    my %result = $interpreter->interpret_entry($entry, ['A']);
    is_deeply(\%result, \%expected, "Values are as expected");
};

subtest "long indel" => sub {
    my $interpreter = $pkg->create(
        sample_names => ["H_KA-174556-1309245"],
        library_names => [qw(H_KA-174556-1309245-lg3-lib1 H_KA-174556-1309245-lg5-lib1)]
    );
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        'GTATA' => {
            'H_KA-174556-1309245-lg3-lib1_ref_count' => 29,
            'H_KA-174556-1309245-lg3-lib1_vaf' => 6.25,
            'H_KA-174556-1309245-lg3-lib1_var_count' => 2,
            'H_KA-174556-1309245-lg5-lib1_ref_count' => 18,
            'H_KA-174556-1309245-lg5-lib1_vaf' => 9.52380952380952,
            'H_KA-174556-1309245-lg5-lib1_var_count' => 2,
        }
    );

    my $entry = create_long_deletion_entry();
    my %result = $interpreter->interpret_entry($entry, ['GTATA']);
    is_deeply(\%result, \%expected, "Values are as expected");
};

subtest 'additional libraries' => sub {
    my $interpreter = $pkg->create(
        sample_names => ["S1"],
        library_names => [@$library_names, 'additional_library'],
    );
    lives_ok(sub {$interpreter->validate}, "Interpreter validates");

    my %expected = (
        G => {
            'Solexa-135852_var_count' => '155',
            'Solexa-135853_var_count' => '186',
            'Solexa-135852_ref_count' => '2',
            'Solexa-135853_ref_count' => '1',
            'Solexa-135852_vaf' => '87.0786516853933',
            'Solexa-135853_vaf' => '99.4652406417112',
            'additional_library_var_count' => '.',
            'additional_library_ref_count' => '.',
            'additional_library_vaf' => '.',
        }
    );

    my $entry = create_default_entry();
    my %result = $interpreter->interpret_entry($entry, ['G']);
    is_deeply(\%result, \%expected, "Values are as expected");

};

done_testing;
