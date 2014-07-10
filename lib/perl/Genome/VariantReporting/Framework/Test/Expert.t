#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use above 'Genome';
use Genome::VariantReporting::Framework::TestHelpers qw(
    test_dag_xml
    test_dag_execute
    test_expert_is_registered
);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
};

my $pkg = 'Genome::VariantReporting::Framework::Test::Expert';
use_ok($pkg) || die; 
test_expert_is_registered($pkg->name);

my $code_test_dir = __FILE__ . '.d';
my $test_dir = Genome::Sys->create_temp_directory;
Genome::Sys->rsync_directory($code_test_dir, $test_dir);

my $expert = $pkg->create();
my $dag = $expert->dag();
my $expected_xml = File::Spec->join($test_dir, 'expected.xml');
test_dag_xml($dag, $expected_xml);

my $plan = Genome::VariantReporting::Framework::Plan::MasterPlan->create_from_file(
    File::Spec->join($test_dir, 'plan.yaml'),
);
$plan->validate();

my $variant_type = 'snvs';
my $expected_vcf = File::Spec->join($test_dir, "expected.vcf");
my $input_vcf = File::Spec->join($test_dir, "input.vcf.gz");

my $provider = Genome::VariantReporting::Framework::Component::ResourceProvider->create(
    attributes => {
        __provided__ => [$input_vcf, $input_vcf],
        translations => {},
    },
);

test_dag_execute($dag, $expected_vcf, $input_vcf, $provider, $variant_type, $plan);

done_testing();