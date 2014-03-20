#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
}

use strict;
use warnings;

require File::Compare;
use Workflow::Simple;
use Test::More;

use above 'Genome';

ok(init(), 'succesfully completed init');
ok(test_dependent_cron_ref_align(), 'successfully completed test_dependent_cron_ref_align');
ok(test_run_build(), 'successfully completed test_run_build');
done_testing();

###
sub init {
    ok($ENV{UR_DBI_NO_COMMIT} = 1, 'UR_DBI_NO_COMMIT is enabled') or die;
    ok($ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1, 'UR_USE_DUMMY_AUTOGENERATED_IDS is enabled') or die;

    use_ok('Genome::Model::GenotypeMicroarray') or die;
    use_ok('Genome::Model::GenotypeMicroarray::Test') or die;

    return 1;
}

sub test_dependent_cron_ref_align {
    # test_dependent_cron_ref_align_init creates several models, see sub for more details
    ok(test_dependent_cron_ref_align_init(), 'successfully completed test_dependent_cron_ref_align_init') or return;

    my $gm_m = Genome::Model::GenotypeMicroarray->get(name => 'Test Genotype Microarray');
    isa_ok($gm_m, 'Genome::Model::GenotypeMicroarray', 'gm_m') or return;

    my @dependent_cron_ref_align = $gm_m->dependent_cron_ref_align;
    my %names = map {$_->name, 1} @dependent_cron_ref_align;
    is(scalar keys %names, 2, 'got two models from dependent_cron_ref_align') or return;
    ok(exists $names{'Another Test Build 36 Reference Alignment'}, 'other model was "Another Test Build 36 Reference Alignment"') or return;
    ok(exists $names{'Test Build 36 Reference Alignment'}, 'one model was "Test Build 36 Reference Alignment"') or return;

    return 1;
}


sub test_dependent_cron_ref_align_init {
    # this create several models needed to test the expected behavior of dependent_cron_ref_align
    # build 36 ref align and build 36 genotype - just as prep work
    # build 37 ref align - for testing compatible reference_sequence_build
    # build 36 ref align with alternate genotype_microarray_model and  alternate build 36 genotype - for testing existing genotype_microarray_model input

    my $ra_pp = Genome::ProcessingProfile::ReferenceAlignment->create(
        name => 'Test Reference Alignment Processing Profile',
        sequencing_platform => 'solexa',
        dna_type => 'genomic dna',
        read_aligner_name => 'bwa',
    );
    isa_ok($ra_pp, 'Genome::ProcessingProfile::ReferenceAlignment', 'ra_pp') or return;

    # only getting this real thing because the class is preventing me from creating one due to valid values
    my $gm_pp = Genome::ProcessingProfile::GenotypeMicroarray->get(name => 'infinium wugc');
    isa_ok($gm_pp, 'Genome::ProcessingProfile::GenotypeMicroarray', 'gm_pp') or return;

    my $individual = Genome::Individual->create(name => 'Test Individual');
    isa_ok($individual, 'Genome::Individual', 'created individual') or return;

    my $subject = Genome::Sample->create(name => 'Test Sample');
    isa_ok($subject, 'Genome::Sample', 'subject') or return;

    my $other_subject = Genome::Sample->create(name => 'Another Test Sample');
    isa_ok($other_subject, 'Genome::Sample', 'another test subject created') or return;

    my $library = Genome::Library->create(name => 'Test Sample Library', sample_id => $subject->id);
    isa_ok($library, 'Genome::Library', 'library') or return;

    my $other_library = Genome::Library->create(name => 'Another Test Library', sample_id => $other_subject->id);
    isa_ok($other_library, 'Genome::Library', 'other library') or return;

    my $genotype_data = Genome::InstrumentData::Imported->create(
        library => $library,
        import_format => 'genotype file',
        sequencing_platform => 'infinium',
    );
    isa_ok($genotype_data, 'Genome::InstrumentData::Imported', 'genotype data') or return;

    $other_subject->default_genotype_data($genotype_data);

    my $build_36 = Genome::Model::Build::ReferenceSequence->get(name => 'NCBI-human-build36');
    isa_ok($build_36, 'Genome::Model::Build::ReferenceSequence', 'build_36') or return;
    my $dbsnp_36 = Genome::Model::ImportedVariationList->dbsnp_build_for_reference($build_36); # FIXME!

    my $build_37 = Genome::Model::Build::ReferenceSequence->get(name => 'GRCh37-lite-build37');
    isa_ok($build_37, 'Genome::Model::Build::ReferenceSequence', 'build_37') or return;
    my $dbsnp_37 = Genome::Model::ImportedVariationList->dbsnp_build_for_reference($build_37); # FIXME!

    my $gm_m = Genome::Model::GenotypeMicroarray->create(
        name => 'Test Genotype Microarray',
        processing_profile => $gm_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        dbsnp_build => $dbsnp_36,
        instrument_data => [$genotype_data],
    );
    isa_ok($gm_m, 'Genome::Model::GenotypeMicroarray', 'gm_m') or return;

    my $alt_gm_m = Genome::Model::GenotypeMicroarray->create(
        name => 'Test Alternate Genotype Microarray',
        processing_profile => $gm_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        dbsnp_build => $dbsnp_36,
    );
    isa_ok($alt_gm_m, 'Genome::Model::GenotypeMicroarray', 'alt_gm_m') or return;

    my $build_36_ref_align = Genome::Model::ReferenceAlignment->create(
        name => 'Test Build 36 Reference Alignment',
        processing_profile => $ra_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        reference_sequence_build => $build_36,
        auto_assign_inst_data => 1,
    );
    isa_ok($build_36_ref_align, 'Genome::Model::ReferenceAlignment', 'build_36_ref_align') or return;

    my $other_build_36_ref_align = Genome::Model::ReferenceAlignment->create(
        name => 'Another Test Build 36 Reference Alignment',
        processing_profile => $ra_pp,
        subject_id => $other_subject->id,
        subject_class_name => $other_subject->class,
        reference_sequence_build => $build_36,
        auto_assign_inst_data => 1,
    );
    isa_ok($other_build_36_ref_align, 'Genome::Model::ReferenceAlignment', 'build_36_ref_align') or return;
    $other_build_36_ref_align->genotype_microarray_model(undef);

    my $build_36_ref_align_with_existing_gm_model = Genome::Model::ReferenceAlignment->create(
        name => 'Test Build 36 Reference Alignment with Genotype Microarray Model',
        processing_profile => $ra_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        reference_sequence_build => $build_36,
        genotype_microarray_model => $alt_gm_m,
        auto_assign_inst_data => 1,
    );
    isa_ok($build_36_ref_align_with_existing_gm_model, 'Genome::Model::ReferenceAlignment', 'build_36_ref_align_with_existing_gm_model') or return;

    my $build_37_ref_align = Genome::Model::ReferenceAlignment->create(
        name => 'Test Build 37 Reference Alignment',
        processing_profile => $ra_pp,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
        reference_sequence_build => $build_37,
        auto_assign_inst_data => 1,
    );
    isa_ok($build_37_ref_align, 'Genome::Model::ReferenceAlignment', 'build_37_ref_align') or return;

    return 1;
}

sub test_run_build {

    my $build = Genome::Model::GenotypeMicroarray::Test->build;
    ok($build, 'genotype microarray build');
    my $example_build = Genome::Model::GenotypeMicroarray::Test->example_build;
    ok($example_build, 'example genotype microarray build');

    my $workflow = $build->model->_resolve_workflow_for_build($build);
    $workflow->validate();
    ok($workflow->is_valid, 'workflow validated');

    my %workflow_inputs = $build->model->map_workflow_inputs($build);
    my %expected_workflow_inputs = (
        build => $build,
    );
    is_deeply(\%workflow_inputs, \%expected_workflow_inputs, 'map_workflow_inputs succeeded');

    my $workflow_xml = $workflow->save_to_xml();
    my $success = Workflow::Simple::run_workflow($workflow_xml, %workflow_inputs);
    ok($success, 'run workflow');
    
    my $original_genotype_vcf = $build->original_genotype_vcf_file_path;
    is($original_genotype_vcf, $build->data_directory.'/'.$build->subject->id.'.original.vcf', 'original genotype vcf name');
    is(File::Compare::compare($original_genotype_vcf, $example_build->original_genotype_vcf_file_path), 0, 'original VCF file matches');

    my $original_genotype_file = $build->original_genotype_file_path;
    is($original_genotype_file, $build->data_directory.'/'.$build->subject->id.'.original', 'oringinal genotype file name');
    is(File::Compare::compare($original_genotype_file, $example_build->original_genotype_file_path), 0, 'oringinal genotype file matches');

    my $genotype_file = $build->genotype_file_path;
    is($genotype_file, $build->data_directory.'/'.$build->subject->id.'.genotype', 'genotype file name');
    is(File::Compare::compare($genotype_file, $example_build->genotype_file_path), 0, 'genotype file matches');
    is(File::Compare::compare($build->formatted_genotype_file_path, $example_build->formatted_genotype_file_path), 0, 'formatted genotype file matches');

    my $gold2geno_file = $build->gold2geno_file_path;
    is($gold2geno_file, $build->data_directory.'/formatted_genotype_file_path.genotype.gold2geno', 'gold2geno file name');
    is(File::Compare::compare($gold2geno_file, $example_build->gold2geno_file_path), 0, 'gold2geno file matches');

    my $copy_number_file = $build->copy_number_file_path;
    is($copy_number_file, $build->data_directory.'/'.$build->subject->id.'.copynumber', 'copy number file name');
    is(File::Compare::compare($copy_number_file, $example_build->copy_number_file_path), 0, 'copy number file matches');

    my $snvs_bed = $build->snvs_bed;
    is($snvs_bed, $build->data_directory.'/gold_snp.v2.bed', 'snvs bed name');
    is(File::Compare::compare($snvs_bed, $example_build->snvs_bed), 0, 'snvs bed file matches');

    # print $build->data_directory."\n";<STDIN>;
    return 1;
}

