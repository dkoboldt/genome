package Genome::Model::MutationalSignificance::Command::CreateROI;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance::Command::CreateROI {
    is => ['Command::V2'],
    has_input => [
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation'
        },
        excluded_reference_sequence_patterns => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => "Exclude transcripts on these reference sequences",
        },
        included_feature_type_patterns => {
            is => 'Text',
            is_many => 1,
            is_optional => 1,
            doc => 'Include only entries that match one of these patterns',
        },
        include_flank => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'Include the flanking regions of transcripts',
        },
        condense_feature_name => {
            is => 'Boolean',
            doc => 'Use only gene name as feature name',
            default_value => 1,
        },
        flank_size => {
            is => 'Integer',
            doc => 'Add this number of base pairs on each side of the feature', #to do: check this
            default_value => 0,
        },
        extra_rois => {
            is => 'Genome::FeatureList',
            is_many => 1,
            is_optional => 1,
        },
        filter_on_regulome_db => {
            is => 'Boolean',
            is_optional => 1,
        },
        valid_regdb_scores => {
            is => 'String',
            is_many => 1,
            is_optional => 1,
            valid_values => [qw(1 2 3 4 5 6 1a 1b 1c 1d 1e 1f 2a 2b 2c 3a 3b)],
        },
    ],
    has_output => [
        roi_path => {
            is => 'String',
        },
    ],
};

sub execute {
    my $self = shift;

    my @params;

    if ($self->excluded_reference_sequence_patterns) {
        push @params, excluded_reference_sequence_patterns => [$self->excluded_reference_sequence_patterns];
    }
    if ($self->included_feature_type_patterns) {
        push @params, included_feature_type_patterns => [$self->included_feature_type_patterns];
    }
    if ($self->condense_feature_name) {
        push @params, condense_feature_name => $self->condense_feature_name;
    }
    if ($self->flank_size && $self->flank_size > 0) {
        push @params, flank_size => $self->flank_size;
    }
    if ($self->include_flank) {
        push @params, include_flank => 1;
    }
    push @params, one_based => 1;

    my $feature_list = $self->annotation_build->get_or_create_roi_bed(@params);

    unless ($feature_list) {
        $self->error_message('ROI file not available from annotation build '.$self->annotation_build->id);
        return;
    }

    $self->status_message("Basing ROI on ".$feature_list->id);

    $self->roi_path($feature_list->file_path);
    
    my $new_name = $feature_list->name;
    my @files;
    for my $extra_roi ($self->extra_rois) {
        my $roi_name = $extra_roi->name;
        $self->status_message("Adding roi $roi_name");
        $new_name .= "_$roi_name";
        push @files, $extra_roi->get_one_based_file;
    }

    my $new_feature_list = Genome::FeatureList->get(name => $new_name);

    unless ($new_feature_list) {
        my $sorted_out = Genome::Sys->create_temp_file_path;
        my $rv = Genome::Model::Tools::Joinx::Sort->execute(
            input_files => [$feature_list->file_path, @files],
            unique => 1,
            output_file => $sorted_out,
        );
        my $file_content_hash = Genome::Sys->md5sum($sorted_out);

        my $format = $feature_list->format;

        $new_feature_list = Genome::FeatureList->create(
            name => $new_name,
            format => $format,
            file_content_hash => $file_content_hash,
            subject => $feature_list->subject,
            reference => $feature_list->reference,
            file_path => $sorted_out,
            content_type => "roi",
            description => "Feature list with extra rois",
            source => "WUTGI",
        );

        unless ($new_feature_list) {
            $self->error_message("Failed to create ROI file with extra ROIs");
            return;
        }
    }
    if ($self->filter_on_regulome_db) {
        my $filtered_name = join("_", $new_feature_list->name, "filtered_by_regulome_v1");
        my $filtered_list = Genome::FeatureList->get($filtered_name);
        unless ($filtered_list) {
            #transform to 0-based
            my $zero_based = $new_feature_list->processed_bed_file(
                short_name => 0,
            );

            #filter
            my $filtered_out_zero_based = Genome::Sys->create_temp_file_path;
            my $rv = Genome::Model::Tools::RegulomeDb::ModifyRoisBasedOnScore->execute(
                roi_list => $zero_based,
                output_file => $filtered_out_zero_based,
                valid_scores => [$self->valid_regdb_scores],
            );

            #convert back to 1-based
            my $filtered_out = Genome::FeatureList::transform_zero_to_one_based(
                $filtered_out_zero_based,
                $new_feature_list->is_multitracked,
            );

            my $file_content_hash = Genome::Sys->md5sum($filtered_out);
            my $filtered_feature_list = Genome::FeatureList->create(
                name => $filtered_name,
                format => $new_feature_list->format,
                file_content_hash => $file_content_hash,
                subject => $new_feature_list->subject,
                reference => $new_feature_list->reference,
                file_path => $filtered_out,
                content_type => "roi",
                description => "Feature list with extra rois filtered by regulome db",
                source => "WUTGI",
            );

            $new_feature_list = $filtered_feature_list;
        }
    }
    
    $self->roi_path($new_feature_list->file_path);
    $self->status_message('Using ROI file: '.$self->roi_path);
    return 1;
}

1;
