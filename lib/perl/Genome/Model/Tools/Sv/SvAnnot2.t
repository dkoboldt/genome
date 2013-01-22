#!/gsc/bin/perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::Model::Tools::Sv::SvAnnot2");

my $base_dir = $ENV{GENOME_TEST_INPUTS}."/Genome-Model-Tools-Sv-SvAnnot2";
my $version = 2;
my $data_dir = "$base_dir/v$version";

my $temp_file = Genome::Sys->create_temp_file_path;
my $cmd = Genome::Model::Tools::Sv::SvAnnot2->create(
    breakdancer_files => ["$data_dir/in.svs",],
    output_file => $temp_file,
);

ok($cmd, "Created command");

ok($cmd->execute, "Command executed successfully");

my $expected_file = "$data_dir/expected.out";
my $diff = Genome::Sys->diff_file_vs_file($temp_file, $expected_file);
ok(-s $temp_file, "Output file created");
ok(-s $expected_file, "Expected file exists");
ok(!$diff, "No diffs with expected output");

done_testing;
