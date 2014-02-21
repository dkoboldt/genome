#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
};

use above 'Genome';

use Data::Dumper;
require File::Temp;
require File::Compare;
use Test::More;

use_ok('Genome::Model::GenotypeMicroarray::GenotypeFile::ReadTsv') or die;
use_ok('Genome::Model::GenotypeMicroarray::GenotypeFile::ReadTsvAndAnnotate') or die;
use_ok('Genome::Model::GenotypeMicroarray::GenotypeFile::WriteCsv') or die;
use_ok('Genome::Model::GenotypeMicroarray::GenotypeFile::WriteVcf') or die;

my $testdir = $ENV{GENOME_TEST_INPUTS} . '/GenotypeMicroarray/';
my $variation_list_build = _init();
my %snp_id_mapping = (
    'rs3094315' => 'rs3094315',
    'rs3131972' => 'rs3131972',
    'rs11240777' => 'rs11240777',
    'rs6681049' => 'rs6681049',
    'rs4970383' => 'rs4970383',
    'rs4475691' => 'rs4475691',
    'rs7537756' => 'rs7537756',
    'rs1110052' => 'rs1110052',
    'rs2272756' => 'rs2272756',
);
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

###
# TSV to annotate to TSV
my $reader = Genome::Model::GenotypeMicroarray::GenotypeFile::ReadTsvAndAnnotate->create(
    input => $testdir.'/rw/input.csv',
    variation_list_build => $variation_list_build,
    snp_id_mapping => \%snp_id_mapping,
);
ok($reader, 'create');
my $output_tsv = $tmpdir.'/genotypes.tsv';
my $writer = Genome::Model::GenotypeMicroarray::GenotypeFile::WriteCsv->create(
    output => $output_tsv,
);
ok($writer, 'create writer');

my @genotypes_from_read_tsv_and_annotate;
my $write_cnt = 0;
while ( my $genotype = $reader->read ) {
    push @genotypes_from_read_tsv_and_annotate, $genotype;
    $write_cnt++ if $writer->write_one($genotype);
}
is_deeply(\@genotypes_from_read_tsv_and_annotate, _expected_genotypes(), 'read tsv and annotate genotypes match');
is($write_cnt, @genotypes_from_read_tsv_and_annotate, 'wrote all genotypes');
is(File::Compare::compare($output_tsv, $testdir.'/rw/output.tsv'), 0, 'read tsv and annotate, write to tsv output file matches');
#print "gvimdiff $output_tsv $testdir/rw/write.tsv\n"; <STDIN>;

###
# TSV to VCF
$reader = Genome::Model::GenotypeMicroarray::GenotypeFile::ReadTsv->create(
    input => $output_tsv,
);
ok($reader, 'create');
my $output_vcf = $tmpdir.'/genotypes.vcf';
$writer = Genome::Model::GenotypeMicroarray::GenotypeFile::WriteVcf->create(
    output => $output_vcf,
);
ok($writer, 'create writer');

my @genotypes_from_read_tsv;
$write_cnt = 0;
while ( my $genotype = $reader->read ) {
    push @genotypes_from_read_tsv, $genotype;
    $write_cnt++ if $writer->write_one($genotype);
}
is_deeply(\@genotypes_from_read_tsv, \@genotypes_from_read_tsv, 'genotypes match');
is($write_cnt, @genotypes_from_read_tsv, 'wrote all genotypes');
is(File::Compare::compare($output_vcf, $testdir.'/rw/write.vcf'), 0, 'read tsv, write to vcf output file matches');
#print "gvimdiff $output_vcf $testdir/rw/write.vcf\n"; <STDIN>;

done_testing();

###

sub _init {

    my $base_testdir = $ENV{GENOME_TEST_INPUTS} . '/GenotypeMicroarray/';
    my $fl = Genome::Model::Tools::DetectVariants2::Result::Manual->__define__(
        description => '__TEST__DBSNP132__',
        username => 'apipe-tester',
        file_content_hash => 'c746fb7b7a88712d27cf71f8262dd6e8',
        output_dir => $testdir.'/dbsnp',
    );
    $fl->lookup_hash($fl->calculate_lookup_hash());
    ok($fl, 'create dv2 result');
    my $refseq_build = Genome::Model::Build::ReferenceSequence->__define__();
    my $variation_list_build = Genome::Model::Build::ImportedVariationList->__define__(
        model => Genome::Model->get(2868377411),
        snv_result => $fl,
        version => 132,
        reference_id => $refseq_build->id,
    );
    ok($variation_list_build, 'create variation list build');

    my $alloc_for_snpid_mapping = Genome::Disk::Allocation->__define__(
        disk_group_name => $ENV{GENOME_DISK_GROUP_ALIGNMENTS},
        group_subdirectory => '',
        mount_path => $testdir.'/dbsnp',
        allocation_path => 'microarray_data/infinium-test-1',
    );
    ok($alloc_for_snpid_mapping, 'define snpid mapping allocation');

    my %sequence_at = (
        752566 => 'A',
        752721 => 'A',
        798959 => 'T',
        800007 => 'A',
        838555 => 'C',
        846808 => 'G',
        854250 => 'A',
        873558 => 'C',
        882033 => 'G',
    );
    no warnings;
    *Genome::FeatureList::file_path = sub{ return $testdir.'/dbsnp/snvs.hq.bed'; };
    *Genome::Model::Build::ReferenceSequence::sequence = sub{ $sequence_at{$_[2]}; };
    use warnings;

    return $variation_list_build
}

sub _expected_genotypes {
    return [
    {
        'log_r_ratio' => '-0.3639',
        'position' => '752566',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'A',
        'id' => 'rs3094315',
        'gc_score' => '0.8931',
        'alleles' => 'AG',
        'reference' => 'A',
        'allele2' => 'G',
        'sample_id' => '2879594813',
    },
    {
        'log_r_ratio' => '-0.0539',
        'position' => '752721',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'A',
        'id' => 'rs3131972',
        'gc_score' => '0.9256',
        'alleles' => 'AG',
        'reference' => 'A',
        'allele2' => 'G',
        'sample_id' => '2879594813',
    },
    {
        'log_r_ratio' => '-0.0192',
        'position' => '798959',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'A',
        'id' => 'rs11240777',
        'gc_score' => '0.8729',
        'alleles' => 'AG',
        'reference' => 'T',
        'allele2' => 'G',
        'sample_id' => '2879594813',
    },
    {
        'log_r_ratio' => '0.2960',
        'position' => '800007',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'T',
        'id' => 'rs6681049',
        'gc_score' => '0.7156',
        'alleles' => 'TC',
        'reference' => 'A',
        'allele2' => 'C',
        'sample_id' => '2879594813',
    },
    {
        'log_r_ratio' => '0.4694',
        'position' => '838555',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'C',
        'id' => 'rs4970383',
        'gc_score' => '0.8749',
        'alleles' => 'CC',
        'reference' => 'C',
        'allele2' => 'C',
        'sample_id' => '2879594813',
    },
    {
        'log_r_ratio' => '-0.0174',
        'position' => '846808',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'C',
        'id' => 'rs4475691',
        'gc_score' => '0.8480',
        'alleles' => 'CC',
        'reference' => 'G',
        'allele2' => 'C',
        'sample_id' => '2879594813',
    },
    {
        'log_r_ratio' => '0.0389',
        'position' => '854250',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'A',
        'id' => 'rs7537756',
        'gc_score' => '0.8670',
        'alleles' => 'AA',
        'reference' => 'A',
        'allele2' => 'A',
        'sample_id' => '2879594813',
    },
    {
        'log_r_ratio' => '0.1487',
        'position' => '873558',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'T',
        'id' => 'rs1110052',
        'gc_score' => '0.7787',
        'alleles' => 'TT',
        'reference' => 'C',
        'allele2' => 'T',
        'sample_id' => '2879594813',
    },
    {
        'log_r_ratio' => '-0.0801',
        'position' => '882033',
        'cnv_confidence' => 'NA',
        'cnv_value' => '2.0',
        'chromosome' => '1',
        'allele1' => 'G',
        'id' => 'rs2272756',
        'gc_score' => '0.8677',
        'alleles' => 'GG',
        'reference' => 'G',
        'allele2' => 'G',
        'sample_id' => '2879594813',
    }
    ];
}
