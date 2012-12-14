#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 7;
}

use_ok('Genome::Model::Tools::DetectVariants2::Filter::FalseIndel');

my $test_base_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-Model-Tools-DetectVariants2-Filter-FalseIndel';
my $test_data_dir = $test_base_dir. "/input.v3";
my $detector_vcf_directory = $test_base_dir. "/detector_vcf_result";

#These aren't very good test files.
my $bam_file = join('/', $test_data_dir, 'tumor.tiny.bam');
my $variant_file = join('/', $test_data_dir, 'indels.hq.bed');

my $expected_result_dir = join('/', $test_base_dir, '5');
my $expected_output_file = join('/', $expected_result_dir, 'indels.hq.bed');
my $expected_filtered_file = join('/', $expected_result_dir, 'indels.lq.bed');

my $tmpdir = File::Temp::tempdir('DetectVariants2-Filter-FalseIndelXXXXX', DIR => "$ENV{GENOME_TEST_TEMP}/", CLEANUP => 1);
my $output_directory = $tmpdir . "/filter";
my $output_file = join('/', $output_directory, 'indels.hq.bed');
my $filtered_file = join('/', $output_directory, 'indels.lq.bed');
my $readcount_file = $output_file . '.readcounts';
my $vcf_version = Genome::Model::Tools::Vcf->get_vcf_version;

my $reference = Genome::Model::Build::ImportedReferenceSequence->get_by_name('NCBI-human-build36');
isa_ok($reference, 'Genome::Model::Build::ImportedReferenceSequence', 'loaded reference sequence');

my $detector_result = Genome::Model::Tools::DetectVariants2::Result->__define__(
    output_dir => $test_data_dir,
    detector_name => 'Genome::Model::Tools::DetectVariants2::VarscanSomatic',
    detector_params => '',
    detector_version => 'awesome',
    aligned_reads => $bam_file,
    reference_build_id => $reference->id,
);
$detector_result->lookup_hash($detector_result->calculate_lookup_hash());
my $detector_vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Detector->__define__(
    input => $detector_result,
    output_dir => $detector_vcf_directory,
    aligned_reads_sample => "TEST",
    vcf_version => $vcf_version,
);
$detector_vcf_result->lookup_hash($detector_vcf_result->calculate_lookup_hash());

$detector_result->add_user(user => $detector_vcf_result, label => 'uses');

my $filter_command = Genome::Model::Tools::DetectVariants2::Filter::FalseIndel->create(
    previous_result_id => $detector_result->id,
    output_directory => $output_directory,
    min_strandedness => 0.01,
    min_var_freq => 0.05,
    min_var_count => 2,
    min_read_pos => 0.10,
    max_mm_qualsum_diff => 50,
    min_good_coverage => 30,
    max_mapqual_diff => 30,
    max_readlen_diff => 15,
    min_var_dist_3 => 0.20,
    min_homopolymer => 4,
    bam_readcount_version => 0.3,
    bam_readcount_min_base_quality => 1, 
);

$filter_command->dump_status_messages(1);
isa_ok($filter_command, 'Genome::Model::Tools::DetectVariants2::Filter::FalseIndel', 'created filter command');
ok($filter_command->execute(), 'executed filter command');

my $output_diff = Genome::Sys->diff_file_vs_file($expected_output_file, $output_file);
ok(!$output_diff, 'output file matches expected result: indels.hq.bed')
    or diag("diff:\n" . $output_diff);

my $filtered_diff = Genome::Sys->diff_file_vs_file($expected_filtered_file, $filtered_file);
ok(!$filtered_diff, 'filtered file matches expected result: indels.lq.bed')
    or diag("diff:\n" . $filtered_diff);

my $expected_vcf = "$expected_result_dir/indels.vcf.gz";
my $output_vcf   = "$output_directory/indels.vcf.gz";
my $expected     = `zcat $expected_vcf | grep -v fileDate`;
my $output       = `zcat $output_vcf | grep -v fileDate`;
my $diff = Genome::Sys->diff_text_vs_text($output, $expected);
ok(!$diff, 'filtered vcf file matches expected result: indels.vcf.gz')
    or diag("diff results:\n" . $diff);
done_testing();
