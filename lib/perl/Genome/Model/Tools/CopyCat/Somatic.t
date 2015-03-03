#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 16;
use Test::Exception;
use Genome::Utility::Test;
use File::Spec;
use File::Compare;

my $class ='Genome::Model::Tools::CopyCat::Somatic'; 
use_ok($class);

my $test_version = 1;
my $test_dir = File::Spec->join(Genome::Utility::Test->data_dir($class), "v$test_version");
ok(-e $test_dir, "Test directory $test_dir exists");

my $tumor_window_file = File::Spec->join($test_dir, 'tumor.wind');
ok(-s $tumor_window_file, "tumor wind file exists");

my $normal_window_file = File::Spec->join($test_dir, 'normal.wind');
ok(-s $normal_window_file, "normal wind file exists");

my $tumor_samtools_file = File::Spec->join($test_dir, 'tumor_samtools', 'snvs.hq');
ok(-s $tumor_samtools_file, 'tumor samtools file exists');

my $normal_samtools_file = File::Spec->join($test_dir, 'normal_samtools', 'snvs.hq');
ok(-s $normal_samtools_file, 'normal samtools file exists');

my $reference_build_id = '106942997';

my $output_directory = Genome::Sys->create_temp_directory();
my $annotation_data_id = _create_test_annotation_data($reference_build_id, File::Spec->join($test_dir, 'annotation_data'));

my %params = (
    normal_window_file => $normal_window_file,
    tumor_window_file => $tumor_window_file,
    output_directory => $output_directory,
    per_library => 1,
    per_read_length => 1,
    normal_samtools_file => $normal_samtools_file,
    tumor_samtools_file => $tumor_samtools_file,
    samtools_file_format => "unknown",
    annotation_data_id => $annotation_data_id,
);

my $cmd = Genome::Model::Tools::CopyCat::Somatic->create( %params );
ok($cmd, "Created command successfully");
ok($cmd->execute, "Executed the command successfully");

my $expected_output_dir = File::Spec->join($test_dir, 'expected');
my @diffable_files = qw| libraries.tumor.txt
                         libraries.normal.txt |;

for my $file (@diffable_files){
    my $expected = File::Spec->join($expected_output_dir, $file);
    my $actual = File::Spec->join($output_directory, $file);
    is(compare($actual, $expected),0,"Actual file is the same as the expected file: $file");
}

my @non_diffable_files = qw| alts.paired.dat
                             segs.paired.dat |;

for my $file (@non_diffable_files){
    my $expected = File::Spec->join($expected_output_dir, $file);
    my $actual = File::Spec->join($output_directory, $file);
    my ($actual_wc) = split(" ", `wc -l $actual`);    
    my ($expected_wc) = split(" ", `wc -l $expected`);    
    ok(abs ($expected_wc - $actual_wc) <= 1, "$file line length is within tolerance");
}

#test that we're able to catch errors. This is a regression test.
my ($mfh, $malformed_file) = Genome::Sys->create_temp_file();
print $mfh "gobbledygook\n";
$mfh->close;

$params{normal_window_file} = $malformed_file;
my $fail_cmd = Genome::Model::Tools::CopyCat::Somatic->create( %params );
ok($fail_cmd, "Created command successfully");
dies_ok { $fail_cmd->execute } "Command failed correctly";

sub _create_test_annotation_data{
    my $reference_build_id = shift;
    my $annotation_dir = shift;
    my $version = 'copycat_somatic.t_test_set';
    my $reference_build = Genome::Model::Build->get($reference_build_id);
    my $cmd = Genome::Model::Tools::CopyCat::AddAnnotationData->create(
        version => $version,
        data_directory => $annotation_dir,
        reference_sequence => $reference_build,
    );
    ok($cmd, "Annotation data creation command exists");
    my $result_id = $cmd->execute;
    ok($result_id, 'Successfully created annotation data set');
    return $result_id;
}

1;
