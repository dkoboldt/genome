#!/usr/bin/env genome-perl

use strict;
use warnings;

use File::Path;
use File::Temp;
use File::Compare;
use Test::More;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from a 64-bit machine";
}

my $refbuild_id = 101947881;
my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get($refbuild_id);
ok($ref_seq_build, 'human36 reference sequence build') or die;

my $test_data = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants2-GatkGermlineIndelUnifiedGenotyper";
# V3 adds the actual score and depth values to the bed
# V4 corrects the value used for score (use QUAL instead of GQ)
my $expected_data = "$test_data/expected.v4";
my $tumor =  $test_data."/flank_tumor_sorted.13.tiny.bam";

my $tmpbase = File::Temp::tempdir('GatkGermlineIndelUnifiedGenotyperXXXXX', DIR => "$ENV{GENOME_TEST_TEMP}/", CLEANUP => 1);
my $tmpdir = "$tmpbase/output";

my $gatk_somatic_indel = Genome::Model::Tools::DetectVariants2::GatkGermlineIndelUnifiedGenotyper->create(
        aligned_reads_input=>$tumor, 
        reference_build_id => $refbuild_id,
        output_directory => $tmpdir, 
        mb_of_ram => 3000,
        version => 5336,
);

ok($gatk_somatic_indel, 'gatk_germline_indel command created');
$gatk_somatic_indel->dump_status_messages(1);
my $rv = $gatk_somatic_indel->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

# indels.hq - ref seq path will be different, so do this to compare the file
my ($expected_indels_hq_params, $expected_indels_hq_data) = _load_indels_hq("$expected_data/indels.hq");
my ($got_indels_hq_params, $got_indels_hq_data) = _load_indels_hq("$tmpdir/indels.hq");

# We should not care about the input dir path so this doesnt break when test data moves
delete $got_indels_hq_params->{input_file};
delete $expected_indels_hq_params->{input_file};

is_deeply($got_indels_hq_params, $expected_indels_hq_params, 'indels.hq params match');
is_deeply($got_indels_hq_data, $expected_indels_hq_data, 'indels.hq data matches');

# other files
my @files = qw|
                    indels.hq.bed
                    indels.hq.v1.bed
                    indels.hq.v2.bed |;

for my $file (@files){
    my $expected_file = "$expected_data/$file";
    my $actual_file = "$tmpdir/$file";
    is(compare($actual_file,$expected_file),0,"Actual file is the same as the expected file: $file")
        || system("diff -u $expected_file $actual_file");
}

done_testing();


###

sub _load_indels_hq {
    my ($file) = @_;

    print "$file\n";
    my $fh = IO::File->new($file, 'r');
    die "Failed to open $file" if not $fh;
    my %params;
    my @data;
    while ( my $line = $fh->getline ) {
        if ( $line !~ s/^##UnifiedGenotyper=// ) {
            push @data, $line;
            next;
        }
        chomp $line;
        %params = map { split('=') } split(/\s/, $line);
    }

    # Don't check reference sequence in the params because it will be cached locally in a different path
    delete $params{reference_sequence};

    return (\%params, \@data);
}
