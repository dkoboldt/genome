#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test qw(compare_ok);

my $class = "Genome::Model::Tools::Gatk::RealignerTargetCreator";

use_ok($class);

my $version = "v1";
my $data_dir = Genome::Utility::Test->data_dir_ok($class, $version);

my $in = $data_dir."/in.bam";
my $expected_out = $data_dir."/expected.intervals";
my $expected_out2 = $data_dir."/expected_with_known.intervals";
my $reference = $data_dir."/reference.fasta";
my $known = $data_dir."/temp.vcf";
my $out = Genome::Sys->create_temp_file_path;
my $out2 = Genome::Sys->create_temp_file_path;

my $cmd = $class->create(
    input_bam => $in,
    reference_fasta => $reference,
    output_intervals => $out,
);
ok($cmd, "Command was created correctly");
is(
    $cmd->realigner_creator_command,
    $cmd->base_java_command . " -T RealignerTargetCreator -I $data_dir/in.bam -R $data_dir/reference.fasta -o $out",
    'base recalibrator command',
);
ok($cmd->execute, "Command was executed successfuly");
ok(-s $out, "Output file exists");
compare_ok($out, $expected_out, "Output file was as expected");

$cmd = $class->create(
    input_bam => $in,
    reference_fasta => $reference,
    output_intervals => $out2,
    known => [$known],
    version => "2.4",
    number_of_threads => 1,
);
ok($cmd, "Command was created correctly");
is(
    $cmd->realigner_creator_command,
    $cmd->base_java_command . " -T RealignerTargetCreator --known $data_dir/temp.vcf -I $data_dir/in.bam -R $data_dir/reference.fasta -o $out2 -nt 1",
    'base recalibrator command',
);
ok($cmd->execute, "Command was executed successfuly");
ok(-s $out2, "Output file exists");

compare_ok($out2, $expected_out2, "Output file was as expected");

done_testing();
