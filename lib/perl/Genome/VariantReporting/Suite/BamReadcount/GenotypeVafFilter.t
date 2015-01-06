#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above 'Genome';
use Genome::VariantReporting::Suite::BamReadcount::TestHelper qw(
    create_default_entry
    create_deletion_entry
    create_no_readcount_entry);
use Genome::File::Vcf::Entry;
use Test::More;
use Test::Exception;

my $pkg = 'Genome::VariantReporting::Suite::BamReadcount::GenotypeVafFilter';
use_ok($pkg) or die;
my $factory = Genome::VariantReporting::Framework::Factory->create();
isa_ok($factory->get_class('filters', $pkg->name), $pkg);

my $entry = create_default_entry();

subtest "test het gt fail" => sub {
    my $filter = $pkg->create(
        sample_name => "S1",
        min_het_vaf => 10,
        max_het_vaf => 20,
        min_hom_vaf => 10,
        max_hom_vaf => 20,
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my %expected_return_values = (
        C => 0,
        G => 0,
        AA => 0,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values, "return values");
};

subtest "test het gt pass (G)" => sub {
    my $filter = $pkg->create(
        sample_name => "S1",
        min_het_vaf => 10,
        max_het_vaf => 100,
        min_hom_vaf => 10,
        max_hom_vaf => 20,
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my %expected_return_values = (
        C => 0,
        G => 1,
        AA => 0,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values, "return values");
};

subtest "test hom gt fail" => sub {
    my $filter = $pkg->create(
        sample_name => "S3",
        min_het_vaf => 10,
        max_het_vaf => 20,
        min_hom_vaf => 10,
        max_hom_vaf => 20,
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my %expected_return_values = (
        C => 0,
        G => 0,
        AA => 0,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values, "return values");
};

subtest "insertion" => sub {
    my $filter = $pkg->create(
        sample_name => "S4",
        min_het_vaf => 10,
        max_het_vaf => 20,
        min_hom_vaf => 1,
        max_hom_vaf => 10,
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my %expected_return_values = (
        C => 0,
        G => 0,
        AA => 1,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values, "return values");
};

subtest "deletion" => sub {
    my $deletion_entry = create_deletion_entry();
    my $filter = $pkg->create(
        sample_name => "S1",
        min_het_vaf => 1,
        max_het_vaf => 10,
        min_hom_vaf => 10,
        max_hom_vaf => 20,
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my %expected_return_values = (
        A => 1,
    );
    is_deeply({$filter->filter_entry($deletion_entry)}, \%expected_return_values, "return values");
};

subtest "test hom gt pass (G)" => sub {
    my $filter = $pkg->create(
        sample_name => "S3",
        min_het_vaf => 10,
        max_het_vaf => 20,
        min_hom_vaf => 10,
        max_hom_vaf => 100,
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");

    my %expected_return_values = (
        C => 0,
        G => 1,
        AA => 0,
    );
    is_deeply({$filter->filter_entry($entry)}, \%expected_return_values, "Sample 1 return values as expected");
};

subtest "no bam readcount entry" => sub {
    my $no_readcount_entry = create_no_readcount_entry();
    my $filter = $pkg->create(
        sample_name => "S1",
        min_het_vaf => 1,
        max_het_vaf => 10,
        min_hom_vaf => 10,
        max_hom_vaf => 20,
    );
    lives_ok(sub {$filter->validate}, "Filter validates ok");
    my %expected_return_values = (
        C => 0,
        G => 1,
        AA => 0,
    );
    is_deeply({$filter->filter_entry($no_readcount_entry)}, \%expected_return_values, "Sample 1 return values as expected");
};

subtest 'validate fails' => sub {
    my %params = (
        min_het_vaf => 10,
        max_het_vaf => 20,
        min_hom_vaf => 10,
        max_hom_vaf => 20,
    );
    my @param_names = keys %params;
    $params{sample_name} = 'S1';
    for my $param_name ( @param_names ) {
        my $param_value = delete $params{$param_name};

        my $filter = $pkg->create(%params);
        throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when $param_name is undef" );

        $params{$param_name} = 'STRING';
        $filter = $pkg->create(%params);
        throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when $param_name is a string" );

        $params{$param_name} = -1;
        $filter = $pkg->create(%params);
        throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when $param_name is < 0" );

        $params{$param_name} = 100.1;
        $filter = $pkg->create(%params);
        throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, "failed to validate when $param_name is > 100" );

        $params{$param_name} = ( $param_name =~ /^min/ ) ? 20 : 10;
        $filter = $pkg->create(%params);
        throws_ok( sub{ $filter->validate; }, qr/^Failed to validate/, 'failed to validate when min >= max' );

        $params{$param_name} = $param_value;
    }
};

done_testing();
