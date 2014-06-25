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

my $pkg = 'Genome::VariantReporting::Reporter::TumorOnlyReporter';
use_ok($pkg);

my $factory = Genome::VariantReporting::Factory->create();
isa_ok($factory->get_class('reporters', $pkg->name), $pkg);

my $data_dir = __FILE__.".d";

my $reporter = $pkg->create(file_name => 'tumor-only');
ok($reporter, "Reporter created successfully");

my $output_dir = Genome::Sys->create_temp_directory();
$reporter->initialize($output_dir);

my %interpretations = (
    'position' => {
        T => {
            chromosome_name => 1,
            start => 1,
            stop => 1,
            reference => 'A',
            variant => 'T',
        },
        G => {
            chromosome_name => 1,
            start => 1,
            stop => 1,
            reference => 'A',
            variant => 'G',
        },
    },
    'vep' => {
        T => {
            transcript_name   => 'ENST00000452176',
            trv_type          => 'DOWNSTREAM',
            amino_acid_change => '',
            default_gene_name => 'RP5-857K21.5',
            ensembl_gene_id   => 'ENSG00000223659',
            gene_name_source  => 'HGNC',
            c_position        => 'c.456',
            canonical         => 1,
            sift              => 'deleterious(5.4)',
        },
        G => {
            transcript_name   => 'ENST00000452176',
            trv_type          => 'DOWNSTREAM',
            amino_acid_change => '',
            default_gene_name => 'RP5-857K22.5',
            ensembl_gene_id   => 'ENSG00000223695',
            gene_name_source  => 'HGNC',
            c_position        => 'c.456',
            canonical         => 1,
        },
    },
    'rsid' => {
        T => {
            rsid => "rs1",
        },
        G => {
            rsid => "rs1",
        },
    },
    'gmaf' => {
        T => {
            gmaf => ".1",
        },
        G => {
            gmaf => ".1",
        },
    },
    'vaf' => {
        T => {
            vaf => "30",
            ref_count => 0,
            var_count => 200,
        },
        G => {
            vaf => "70",
            ref_count => 0,
            var_count => 1000,
        },
    },
);

$reporter->report(\%interpretations);
$reporter->finalize();

compare_ok(File::Spec->join($output_dir, 'tumor-only'), File::Spec->join($data_dir, "expected.out"), "Output as expected");
done_testing;
