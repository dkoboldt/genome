#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";
use Test::More;
use Genome::Utility::Test qw(compare_ok);
use Genome::Test::Factory::Process;

my $pkg = 'Genome::VariantReporting::Framework::MergeReports';
use_ok($pkg) or die;
my $data_dir = __FILE__.".d";

my $process = Genome::Test::Factory::Process->setup_object();

sub get_data {
    return File::Spec->join($data_dir, @_);
}

sub get_report_result {
    my $report_filename = shift;

    my $report_path = get_data($report_filename);
    return Genome::VariantReporting::Framework::Test::Report->__define__(
        _report_path => $report_path,
    );
}

subtest "test with headers" => sub {
    my $result_a = get_report_result('report_a.header');
    my $result_b = get_report_result('report_b.header');
    my $expected = get_data('expected.header');

    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['chr', 'pos'],
        contains_header => 1,
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($cmd, $pkg);

    ok($cmd->execute, 'Executed the test command');
    compare_ok($cmd->output_result->report_path, $expected, 'Output file looks as expected');
};

subtest "merged test with headers" => sub {
    my $result_a = get_report_result('report_a.header');
    my $result_b = get_report_result('report_b.header');
    my $expected = get_data('expected.header');

    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['chr', 'pos'],
        contains_header => 1,
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($cmd, $pkg);

    ok($cmd->execute, 'Executed the test command');
    compare_ok($cmd->output_result->report_path, $expected, 'Output file looks as expected');

    my $result_d = get_report_result('report_d.header');
    my $expected_merged = get_data('expected_merged.header');
    my $second_cmd = $pkg->create(
        base_report => $cmd->output_result,
        supplemental_report => $result_d,
        sort_columns => ['chr', 'pos'],
        contains_header => 1,
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($second_cmd, $pkg);

    ok($second_cmd->execute, 'Executed the test command');
    compare_ok($second_cmd->output_result->report_path, $expected_merged, 'Output file looks as expected');
};

subtest "test with headers with source" => sub {
    my $result_a = get_report_result('report_a.header');
    my $result_b = get_report_result('report_b.header');
    my $expected = get_data('expected_with_source.header');

    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['chr', 'pos'],
        contains_header => 1,
        entry_sources => [
            sprintf("%s|%s", $result_a->id, 'report_a'),
            sprintf("%s|%s", $result_b->id, 'report_b'),
        ],
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($cmd, $pkg);

    ok($cmd->execute, 'Executed the test command');
    compare_ok($cmd->output_result->report_path, $expected, 'Output file looks as expected');
};

subtest "test with different orders of headers" => sub {
    my $result_a = get_report_result('report_a.header');
    my $result_b = get_report_result('report_b2.header');
    my $expected = get_data('expected.header');
    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['chr', 'pos'],
        use_header_from => $result_a,
        contains_header => 1,
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($cmd, $pkg);

    ok($cmd->execute, 'Executed the test command');
    compare_ok($cmd->output_result->report_path, $expected, 'Output file looks as expected');
};

subtest "test without headers" => sub {
    my $result_a = get_report_result('report_a.noheader');
    my $result_b = get_report_result('report_b.noheader');
    my $expected = get_data('expected.noheader');

    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['1', '2'],
        contains_header => 0,
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($cmd, $pkg);

    ok($cmd->execute, 'Executed the test command');
    compare_ok($cmd->output_result->report_path, $expected, 'Output file looks as expected');
};

subtest "test without headers with source" => sub {
    my $result_a = get_report_result('report_a.noheader');
    my $result_b = get_report_result('report_b.noheader');
    my $expected = get_data('expected_with_source.noheader');

    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['1', '2'],
        contains_header => 0,
        entry_sources => [
            sprintf("%s|%s", $result_a->id, 'report_a'),
            sprintf("%s|%s", $result_b->id, 'report_b'),
        ],
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($cmd, $pkg);

    ok($cmd->execute, 'Executed the test command');
    compare_ok($cmd->output_result->report_path, $expected, 'Output file looks as expected');
};

subtest "Source tags must be defined" => sub {
    my $result_a = get_report_result('report_a.noheader');
    my $result_b = get_report_result('report_b.noheader');
    my $expected = get_data('expected_with_source.noheader');

    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['1', '2'],
        contains_header => 0,
        entry_sources => [
            sprintf("%s|%s", $result_b->id, 'report_b'),
        ],
        process_id => $process->id,
        label => 'results',
    );
    ok(!$cmd->execute, "Execute returns false value");
    ok($cmd->error_message =~ qr/No entry source for report/,
        "Error if source tag is not defined for one report");
};

subtest "test one empty file" => sub {
    my $result_a = get_report_result('report_a.noheader');
    my $result_b = get_report_result('report_empty');
    my $expected = get_data('report_a.noheader');

    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['1', '2'],
        contains_header => 0,
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($cmd, $pkg);

    ok($cmd->execute, 'Executed the test command');
    compare_ok($cmd->output_result->report_path, $expected, 'Output file looks as expected');
};

subtest "test all empty files" => sub {
    my $result_a = get_report_result('report_empty');
    my $result_b = get_report_result('report_empty');
    my $expected = get_data('report_empty');

    my $cmd = $pkg->create(
        base_report => $result_a,
        supplemental_report => $result_b,
        sort_columns => ['1', '2'],
        contains_header => 0,
        process_id => $process->id,
        label => 'results',
    );
    isa_ok($cmd, $pkg);

    ok($cmd->execute, 'Executed the test command');
    compare_ok($cmd->output_result->report_path, $expected, 'Output file looks as expected');
};

done_testing();
