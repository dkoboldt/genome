#!/usr/bin/env genome-perl

use strict;
use warnings;

use Test::More;

BEGIN {
    if (`uname -a` =~ /x86_64/) {
        plan tests => 27;
    } else {
        plan skip_all => 'Must run on a 64 bit machine';
    }

    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use above 'Genome';
use Genome::Test::Factory::SoftwareResult::User;

use_ok('Genome::InstrumentData::AlignmentResult::Merged');
#
# Gather up versions for the tools used herein
#
###############################################################################
my $aligner_name = "bwa";
my $aligner_tools_class_name = "Genome::Model::Tools::" . Genome::InstrumentData::AlignmentResult->_resolve_subclass_name_for_aligner_name($aligner_name);
my $alignment_result_class_name = "Genome::InstrumentData::AlignmentResult::" . Genome::InstrumentData::AlignmentResult->_resolve_subclass_name_for_aligner_name($aligner_name);

my $samtools_version = Genome::Model::Tools::Sam->default_samtools_version;
my $picard_version = Genome::Model::Tools::Picard->default_picard_version;

my $aligner_version_method_name = sprintf("default_%s_version", $aligner_name);

my $aligner_version = $aligner_tools_class_name->default_version;
my $aligner_label   = $aligner_name.$aligner_version;
$aligner_label =~ s/\./\_/g;

my $expected_shortcut_path = $ENV{GENOME_TEST_INPUTS} . "/Genome-InstrumentData-AlignmentResult-Merged/bwa/",

my $FAKE_INSTRUMENT_DATA_ID=-123456;


#
# Gather up the reference sequences and instrument data.
#
###########################################################

my $reference_model = Genome::Model::ImportedReferenceSequence->get(name => 'TEST-human');
ok($reference_model, "got reference model");

my $reference_build = $reference_model->build_by_version('1');
ok($reference_build, "got reference build");

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build => $reference_build,
);

my @instrument_data = generate_fake_instrument_data();
my @individual_results = generate_individual_alignment_results(@instrument_data);


#
# Begin
#

my @params = (
     aligner_name=>$aligner_name,
     aligner_version=>$aligner_version,
     samtools_version=>$samtools_version,
     picard_version=>$picard_version,
     reference_build => $reference_build,

     merger_name => 'picard',
     merger_version => $picard_version,
     duplication_handler_name => 'picard',
     duplication_handler_version => $picard_version,
     instrument_data_id => [map($_->id, @instrument_data)],
     test_name => 'merged_unit_test',
     instrument_data_segment => [map {$_->id . ':A:2:read_group'} @instrument_data],
);

my $merged_alignment_result = Genome::InstrumentData::AlignmentResult::Merged->create(@params, _user_data_for_nested_results => $result_users);

isa_ok($merged_alignment_result, 'Genome::InstrumentData::AlignmentResult::Merged', 'produced merged alignment result');

my $expected_dir = $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData-AlignmentResult-Merged/expected';
my $diff = Genome::Sys->diff_file_vs_file($merged_alignment_result->bam_file, join('/', $expected_dir, '-120573001.bam'));
ok(!$diff, 'merged bam matches expected result')
    or diag("diff:\n". $diff);

my $flagstat_diff = Genome::Sys->diff_file_vs_file($merged_alignment_result->merged_alignment_bam_flagstat, join('/', $expected_dir, '-120573001.bam.flagstat'));
ok(!$flagstat_diff, 'flagstat matches expected result')
    or diag("diff:\n". $flagstat_diff);

my @individual_alignments = $merged_alignment_result->collect_individual_alignments;
is(scalar @individual_alignments, 2, 'got back expected number of alignments');
for my $i (@individual_alignments) {
    ok(!defined($i->filter_name), 'filter_name is not defined as expected');
}

my $existing_alignment_result = Genome::InstrumentData::AlignmentResult::Merged->get_or_create(@params, users => $result_users);
is($existing_alignment_result, $merged_alignment_result, 'got back the previously created result');

my @filtered_params = (
    @params,
    filter_name => [$instrument_data[0]->id . ':forward-only', $instrument_data[1]->id . ':forward-only'],
);

my $filtered_alignment_result = Genome::InstrumentData::AlignmentResult::Merged->get_or_create(@filtered_params, users => $result_users);
isa_ok($filtered_alignment_result, 'Genome::InstrumentData::AlignmentResult::Merged', 'produced merged alignment result with filter applied');

#same expected files since we faked the alignment results to use the same data
my $filtered_diff = Genome::Sys->diff_file_vs_file($filtered_alignment_result->bam_file, join('/', $expected_dir, '-120573001.bam'));
ok(!$filtered_diff, 'merged bam matches expected result')
    or diag("diff:\n". $filtered_diff);

my $filtered_flagstat_diff = Genome::Sys->diff_file_vs_file($filtered_alignment_result->merged_alignment_bam_flagstat, join('/', $expected_dir, '-120573001.bam.flagstat'));
ok(!$filtered_flagstat_diff, 'flagstat matches expected result')
    or diag("diff:\n". $filtered_flagstat_diff);

my @filtered_individual_alignments = $filtered_alignment_result->collect_individual_alignments;
is(scalar @filtered_individual_alignments, 2, 'got back expected number of alignments');
for my $i (@filtered_individual_alignments) {
    is($i->filter_name, 'forward-only', 'filter_name is defined as expected');
}

isnt($filtered_alignment_result, $existing_alignment_result, 'produced a different result when filter applied');

my $existing_filtered_alignment_result = Genome::InstrumentData::AlignmentResult::Merged->get_or_create(@filtered_params, users => $result_users);
is($existing_filtered_alignment_result, $filtered_alignment_result, 'got back the previously created filtered result');

my $gotten_alignment_result = Genome::InstrumentData::AlignmentResult::Merged->get_with_lock(@params, users => $result_users);
is($gotten_alignment_result, $existing_alignment_result, 'using get returns same result as get_or_create');

my @segmented_params = (
    @params, 
    instrument_data_segment => [$instrument_data[0]->id . ':test:read_group', $instrument_data[0]->id . ':test2:read_group'],
);

my $segmented_alignment_result = eval {
    Genome::InstrumentData::AlignmentResult::Merged->get_or_create(@segmented_params, users => $result_users);
};

my $error = $@;
ok(!defined $segmented_alignment_result, 'no result returned for nonexistent segments');
like($error, qr/Failed to find individual alignments for all instrument_data/, 'failed for expected reason');


# Setup methods

sub generate_individual_alignment_results {
    my @instrument_data = @_;

    my @alignment_results;
    my %params = (
        subclass_name    => $alignment_result_class_name,
        module_version   => '12345',
        aligner_name     => $aligner_name,
        aligner_version  => $aligner_version,
        samtools_version => $samtools_version,
        picard_version   => $picard_version,
        reference_build  => $reference_build,
        instrument_data_segment_type => "read_group",
        instrument_data_segment_id => "A:2",
    );

    for my $i (0,1) {
        my $alignment_result = $alignment_result_class_name->__define__(
            %params,
            id                 => -8765432+$i,
            output_dir         => $expected_shortcut_path . $i,
            instrument_data_id => $instrument_data[$i]->id,
            #test_name => 'merged_unit_test',
        );
        $alignment_result->lookup_hash($alignment_result->calculate_lookup_hash());

        isa_ok($alignment_result, 'Genome::InstrumentData::AlignmentResult');
        push @alignment_results, $alignment_result;
    }

    #also produce "fitered" versions--although these really point to the same locations
    for my $i (0,1) {
        my $alignment_result = $alignment_result_class_name->__define__(
            %params,
            id                 => -98765432+$i,
            output_dir         => $expected_shortcut_path . $i,
            instrument_data_id => $instrument_data[$i]->id,
            #test_name => 'merged_unit_test',
            filter_name => 'forward-only',
        );
        $alignment_result->lookup_hash($alignment_result->calculate_lookup_hash());
        
        isa_ok($alignment_result, 'Genome::InstrumentData::AlignmentResult');
        push @alignment_results, $alignment_result;
    }

    return @alignment_results;
}

sub generate_fake_instrument_data {

    my $fastq_directory = $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData-Align-Maq/test_sample_name';
    
    my @instrument_data;
    for my $i (0,2) {
        my $instrument_data = Genome::InstrumentData::Solexa->create(
            id => $FAKE_INSTRUMENT_DATA_ID + $i,
            sequencing_platform => 'solexa',
            flow_cell_id => '12345',
            lane => 4 + $i,
            #seq_id => $FAKE_INSTRUMENT_DATA_ID + $i,
            median_insert_size => '22',
            #sample_name => 'test_sample_name',
            #library_name => 'test_sample_name-lib1',
            run_name => 'test_run_name',
            subset_name => 4 + $i,
            run_type => 'Paired End Read 2',
            gerald_directory => $fastq_directory,
            bam_path => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData-AlignmentResult-Bwa/input.bam',
            #sample_type => 'dna',
            #sample_id => '2791246676',
            library_id => '2792100280',
        );

        isa_ok($instrument_data, 'Genome::InstrumentData::Solexa');
        push @instrument_data, $instrument_data;
    }

    return @instrument_data;
}
