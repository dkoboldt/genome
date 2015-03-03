#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More;
use Genome::Utility::Test 'compare_ok';
use File::Spec;

my ($class,$params) = Genome::Model::RnaSeq->_parse_strategy("htseq-count 0.5.4p1 [--mode intersect-strict --minaqual 1 --blacklist-alignments-flags 0x0104 --results-version 1]");
is($class, 'Genome::Model::Tools::Htseq::Count', 'got expected tool class');
my $params_expected = {
    'app_version' => '0.5.4p1',              
    'mode' => 'intersect-strict',              
    'blacklist_alignments_flags' => '0x0104',
    'results_version' => '1',
    'minaqual' => '1'            
};
is_deeply($params, $params_expected, "got expected params with []");


($class,$params) = Genome::Model::RnaSeq->_parse_strategy("htseq-count 0.5.4p1");
is($class, 'Genome::Model::Tools::Htseq::Count', 'got expected tool class');
$params_expected = {
    'app_version' => '0.5.4p1',              
};
is_deeply($params, $params_expected, "got expected params with no []");

my $rnaseq_build = Genome::Model::Build->get(135296493);
my $rnaseq_model = $rnaseq_build->model;
my %inputs = $rnaseq_model->map_workflow_inputs($rnaseq_build);
my $expected_inputs = {
    'build_id' => $rnaseq_build->id,
    'digital_expression_minaqual' => '1',
    'annotation_reference_transcripts_mode' => [
                                                'reference only'
                                                ],
    'digital_expression_mode' => 'intersection-strict',
    'digital_expression_app_version' => '0.5.4p1',
    'digital_expression_result_version' => '1',
    'digital_expression_blacklist_alignments_flags' => '0x0104',
    'digital_expression_sponsor' => Genome::SoftwareResult::User->user_hash_for_build($rnaseq_build)->{sponsor},
    'digital_expression_requestor' => $rnaseq_build,
    'digital_expression_user' => $rnaseq_build,
    'digital_expression_label' => 'digital_expression_result',
    'digital_expression_output_dir' => File::Spec->join($rnaseq_build->data_directory, 'results', 'digital_expression_result'),
};
is_deeply(\%inputs, $expected_inputs, "inputs match") or do { print Data::Dumper::Dumper($expected_inputs,\%inputs) };

my $workflow = $rnaseq_model->_resolve_workflow_for_build($rnaseq_build);
ok($workflow, "Got a workflow");

# Test expected workflow xml
my $test_dir = Genome::Utility::Test->data_dir('Genome::Model::RnaSeq', '2015-01-22');
my $xml_file = Genome::Sys->create_temp_file_path;
my $expected_xml_file = "$test_dir/workflow.xml";
$workflow->save_to_xml(OutputFile => $xml_file);

ok(-s $expected_xml_file, "Expected xml file exists at $expected_xml_file");
ok(-s $xml_file, "Current xml file exists at $xml_file");
compare_ok($expected_xml_file, $xml_file, name => "Xml file is as expected for the workflow",
    replace => [
        [qr(lsfQueue="apipe"), q(lsfQueue="GENOME_LSF_QUEUE_BUILD_WORKER_ALT")],
        [qr(lsfQueue="apipe-pd"), q(lsfQueue="GENOME_LSF_QUEUE_BUILD_WORKER_ALT")],
    ],
);

done_testing();
