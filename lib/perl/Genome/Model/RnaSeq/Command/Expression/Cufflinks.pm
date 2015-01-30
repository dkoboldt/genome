package Genome::Model::RnaSeq::Command::Expression::Cufflinks;

use strict;
use warnings;

use version;

use Genome;

my $DEFAULT_LSF_RESOURCE = $ENV{GENOME_TESTING}
    ? "-R 'span[hosts=1]' -n 4"
    : "-R 'select[mem>=64000] rusage[mem=64000] span[hosts=1]' -M 64000000 -n 4";

class Genome::Model::RnaSeq::Command::Expression::Cufflinks {
    is => ['Command::V2'],
    has_input_output => [
        build_id => {},
    ],
    has_param => [
        lsf_resource => { default_value => $DEFAULT_LSF_RESOURCE },
    ],
    has_input => [
        annotation_reference_transcripts_mode => {
            default_value => 'de novo',
        },
    ],
    has => [
        build => {
            is => 'Genome::Model::Build::RnaSeq',
            id_by => 'build_id',
        },
        model => { via => 'build'},
    ],
    has_optional_output => [
        cufflinks_expression_result_id => {
            is => 'Number',
            doc => 'ID of the result from running this step',
        },
    ],
    has_optional => [
        cufflinks_expression_result => {
            is => 'Genome::InstrumentData::AlignmentResult::Merged::CufflinksExpression',
            id_by => 'cufflinks_expression_result_id',
            doc => 'The result from running this step',
        },
    ],
};

sub sub_command_category { 'pipeline steps' }

sub sub_command_sort_position { 8 }

sub shortcut {
    my $self = shift;
    my $build = $self->build;
    my $alignment_result = $build->alignment_result;
    if ($alignment_result->isa('Genome::InstrumentData::AlignmentResult::Merged')) {
        my %params = $self->params_for_result;
        my $result = Genome::InstrumentData::AlignmentResult::Merged::CufflinksExpression->get_with_lock(%params);
        if($result) {
            $self->debug_message('Using existing result ' . $result->__display_name__);
            return $self->link_result_to_build($result);
        }
    }
    return;
}

sub execute {
    my $self = shift;

    my $build = $self->build;
    my $alignment_result = $build->alignment_result;
    if ($alignment_result->isa('Genome::InstrumentData::AlignmentResult::Merged')) {
        my %params = (
            $self->params_for_result,
            log_directory => $build->log_directory,
        );

        my $result = Genome::InstrumentData::AlignmentResult::Merged::CufflinksExpression->get_or_create(%params);

        $self->link_result_to_build($result);
    } else {
        # Run the old way
        my %params = (
            $self->params_for_result,
            expression_directory => $build->expression_directory($self->annotation_reference_transcripts_mode),
            reference_build => $build->reference_sequence_build,
        );
        if (defined($build->annotation_build)) {
            $params{annotation_build} = $build->annotation_build;
        }
        delete($params{test_name});
        my $cmd = Genome::InstrumentData::AlignmentResult::Command::CufflinksExpression->create(%params);
        unless ($cmd and $cmd->execute) {
            return;
        }
    }
    return 1;
}

sub params_for_result {
    my $self = shift;
    my $build = $self->build;
    my $pp = $build->processing_profile;

    my $alignment_result = $build->alignment_result;

    unless ($alignment_result) {
        die $self->error_message('No alignment result found for build: '. $build->id);
    }

    my $result_users = Genome::SoftwareResult::User->user_hash_for_build($build);
    $result_users->{cufflinks_expression} = $build;

    my %params = (
        alignment_result_id => $alignment_result->id,
        cufflinks_version => $pp->expression_version,
        cufflinks_params => $pp->expression_params,
        annotation_reference_transcripts_mode  => $self->annotation_reference_transcripts_mode,
        test_name => ($ENV{GENOME_SOFTWARE_RESULT_TEST_NAME} || undef),
        users => $result_users,
    );
    if ( defined($pp->mask_reference_transcripts) ) {
        $params{mask_reference_transcripts} = $pp->mask_reference_transcripts;
    };
    return %params;
}

sub link_result_to_build {
    my $self = shift;
    my $result = shift;

    my $build = $self->build;
    my $mode = $self->annotation_reference_transcripts_mode;
    Genome::Sys->create_symlink($result->output_dir, $build->expression_directory($mode));
    if ($mode eq 'reference only') {
        # create the old expression directory for compatibility
        Genome::Sys->create_symlink($build->expression_directory($mode), $build->expression_directory);
    }

    $self->cufflinks_expression_result($result);

    return 1;
}


1;
