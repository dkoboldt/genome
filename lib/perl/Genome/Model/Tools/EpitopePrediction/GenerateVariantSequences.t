#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';
use Test::More;
use Test::Exception;
use Genome::Utility::Test qw(compare_ok);

my $TEST_DATA_VERSION = 1;
my $class = 'Genome::Model::Tools::EpitopePrediction::GenerateVariantSequences';
use_ok($class);

my $test_dir = Genome::Utility::Test->data_dir_ok($class, $TEST_DATA_VERSION);
my $input_file = File::Spec->join($test_dir, "input.tsv");
for my $length (qw(17 21 31)) {
    subtest "input file with length $length" => sub {
        test_for_length($length, $test_dir, $input_file);
    };
}

sub test_for_length {
    my ($length, $test_dir, $input_file) = @_;

    my $expected_output = File::Spec->join($test_dir, "output_" . $length ."mer");
    my $output_dir = Genome::Sys->create_temp_directory;

    my $cmd = $class->create(
        input_file => $input_file,
        output_directory => $output_dir,
        peptide_sequence_length => $length,
    );
    ok($cmd, "Created a command for length $length");

    ok($cmd->execute, "Command executed for length $length");

    compare_ok($cmd->output_file, $expected_output, "Output file is as expected for length $length");
}

subtest 'input file with mutations at relative end of full sequence' => sub {
    my $input_file_2 = File::Spec->join($test_dir, "input_2.tsv");
    my $output_dir = Genome::Sys->create_temp_directory;
    my $expected_output = File::Spec->join($test_dir, "output_2_21mer");

    my $cmd = $class->create(
        input_file => $input_file_2,
        output_directory => $output_dir,
        peptide_sequence_length => 21,
    );
    ok($cmd, "Created a command");

    ok($cmd->execute, "Command executed");

    compare_ok($cmd->output_file, $expected_output, "Output file is as expected");
};

subtest 'input file with mutations at relative beginning of full sequence' => sub {
    my $input_file_2 = File::Spec->join($test_dir, "input_3.tsv");
    my $output_dir = Genome::Sys->create_temp_directory;
    my $expected_output = File::Spec->join($test_dir, "output_3_21mer");

    my $cmd = $class->create(
        input_file => $input_file_2,
        output_directory => $output_dir,
        peptide_sequence_length => 21,
    );
    ok($cmd, "Created a command");

    ok($cmd->execute, "Command executed");

    compare_ok($cmd->output_file, $expected_output, "Output file is as expected");
};

subtest 'input file with wildtype sequence shorter than desired peptite sequence length' => sub {
    my $input_file = File::Spec->join($test_dir, 'input_short_wildtype_sequence.tsv');
    my $output_dir = Genome::Sys->create_temp_directory;
    my $expected_output = File::Spec->join($test_dir, 'output_short_wildtype_sequence');

    my $cmd = $class->create(
        input_file => $input_file,
        output_directory => $output_dir,
        peptide_sequence_length => 21,
    );
    ok($cmd, 'Created a command');

    ok($cmd->execute, 'Command executed');
    like($cmd->status_message, qr/Wildtype sequence length is shorter than desired peptide sequence length/, 'Command executed with status message');
    compare_ok($cmd->output_file, $expected_output, 'Output file is as expected');

};

done_testing();
