#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use File::Path;
use File::Temp;
use File::Compare;
use Test::More;
use above 'Genome';
use Genome::SoftwareResult;
use Genome::Test::Factory::SoftwareResult::User;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from a 64-bit machine";
}

use_ok('Genome::Model::Tools::DetectVariants2::GatkGermlineSnv');

my $refbuild_id = 101947881;
my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get($refbuild_id);
ok($ref_seq_build, 'human36 reference sequence build') or die;

my $test_data = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants2-GatkGermlineSnv";
my $expected_base = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-DetectVariants2-GatkGermlineSnv/";
# V2 adds the actual score and depth values to the bed
# V3 adjusts the column used for score -- QUAL instead of GQ
my $expected_data = "$expected_base/expected.v3";
my $tumor =  $test_data."/flank_tumor_sorted.13_only.bam";

my $tmpbase = File::Temp::tempdir('GatkGermlineSnvXXXXX', CLEANUP => 1, TMPDIR => 1);
my $tmpdir = "$tmpbase/output";

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build => $ref_seq_build,
);

my $gatk_somatic_indel = Genome::Model::Tools::DetectVariants2::GatkGermlineSnv->create(
        aligned_reads_input=>$tumor, 
        reference_build_id => $refbuild_id,
        output_directory => $tmpdir, 
        mb_of_ram => 3000,
        version => 5336,
        result_users => $result_users,
);

ok($gatk_somatic_indel, 'gatk_germline_snv command created');
$gatk_somatic_indel->dump_status_messages(1);
my $rv = $gatk_somatic_indel->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

# snvs.hq - ref seq path will be different, so do this to compare the file
my ($expected_snvs_hq_params, $expected_snvs_hq_data) = _load_snvs_hq("$expected_data/snvs.hq");
my ($got_snvs_hq_params, $got_snvs_hq_data) = _load_snvs_hq("$tmpdir/snvs.hq");

# We should not care about the input dir path so this doesnt break when test data moves
delete $got_snvs_hq_params->{input_file};
delete $expected_snvs_hq_params->{input_file};

is_deeply($got_snvs_hq_params, $expected_snvs_hq_params, 'snvs.hq params match');
is_deeply($got_snvs_hq_data, $expected_snvs_hq_data, 'snvs.hq data matches');

my @files = qw|     gatk_output_file
                    snvs.hq.bed
                    snvs.hq.v1.bed
                    snvs.hq.v2.bed |;

for my $file (@files){
    my $expected_file = "$expected_data/$file";
    my $actual_file = "$tmpdir/$file";
    
    is(compare($actual_file,$expected_file),0,"Actual file $actual_file is the same as the expected file: $expected_file");
}

done_testing();


###

sub _load_snvs_hq {
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

    # Don't check reference sequence because it is cached locally and the path will vary
    delete $params{reference_sequence};

    return (\%params, \@data);
}
