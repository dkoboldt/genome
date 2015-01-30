package Genome::Model::SomaticValidation::Command::VerifyBam;

use strict;
use warnings;
use Genome;

class Genome::Model::SomaticValidation::Command::VerifyBam {
    is => ['Genome::Model::SomaticValidation::Command::WithMode'],
    has_transient_optional_output => [
        result => {
            is => 'Genome::InstrumentData::VerifyBamIdResult',
        },
    ],
    has_param => [
        lsf_resource => {
            default_value => "-R 'select[mem>12000] rusage[mem=12000]' -M 12000000",
            is_optional => 1,
            doc => 'default LSF resource expectations',
        },
    ],
};

sub shortcut {
    my $self = shift;

    unless ($self->should_run) {
        $self->debug_message("Skipping VerifyBam id");
        return 1;
    }

    my $params = $self->params_for_result;
    my $result = Genome::InstrumentData::VerifyBamIdResult->get_with_lock(
        %{$params}
    );
    if ($result) {
        $self->debug_message("Using existing result ".$result->__display_name__);
        return $self->link_result_to_build($result);
    }
    return;
}

sub execute {
    my $self = shift;

    unless($self->should_run) {
        return 1;
    }

    my $params = $self->params_for_result;
    my $result = Genome::InstrumentData::VerifyBamIdResult->get_or_create(
        %{$params}
    );
    if ($result) {
        $self->debug_message("Created result ".$result->__display_name__);
        return $self->link_result_to_build($result);
    }
    else {
        $self->error_message("Failed to create result");
        return;
    }
}

sub should_run {
    my $self = shift;

    unless ($self->SUPER::should_run) {
        return 0;
    }

    unless($self->build->model->verify_bam_id_version) {
        $self->debug_message('No Verify BAM ID version specified. Skipping run.');
        return 0;
    }

    unless (defined $self->sample_for_mode->default_genotype_data) {
        $self->debug_message('No default genotype data for sample '.$self->sample_for_mode->__display_name__.' Skipping VerifyBamId');
        return 0;
    }

    return 1;
}

sub params_for_result {
    my $self = shift;

    my $user_data = Genome::SoftwareResult::User->user_hash_for_build($self->build);

    my %params = (
        sample => $self->sample_for_mode,
        known_sites_build => $self->build->previously_discovered_variations_build,
        genotype_filters => ["chromosome:exclude=".$self->build->previously_discovered_variations_build->reference->allosome_names],
        aligned_bam_result => $self->alignment_result_for_mode,
        max_depth => 1000,
        precise => 1,
        version => $self->build->model->verify_bam_id_version,
        result_version => 2,
        test_name => $ENV{GENOME_SOFTWARE_RESULT_TEST_NAME},
        users => $user_data,
    );
    if (defined $self->build->target_region_set) {
        $params{on_target_list} = $self->build->target_region_set;
    }
    return \%params;
}

sub link_result_to_build {
    my $self = shift;
    my $result = shift;
    $self->result($result);
    return $self->SUPER::link_result_to_build($result, "verifyBamId", "verify_bam_id");
}

1;

