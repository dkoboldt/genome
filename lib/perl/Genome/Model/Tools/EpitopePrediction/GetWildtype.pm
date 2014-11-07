package Genome::Model::Tools::EpitopePrediction::GetWildtype;

use strict;
use warnings;

use Genome;
use Workflow;
use Carp;

class Genome::Model::Tools::EpitopePrediction::GetWildtype {
    is => ['Genome::Model::Tools::EpitopePrediction::Base'],
    doc => "Get the Wildtype protein sequence from the specified Annotation Database for the variant proteins which have been annotated",
    has_input => [
        input_tsv_file => {
            is => 'Text',
            doc => 'A tab separated input file from the annotator',
        },
        output_directory => {
            is => 'Text',
            doc => 'Location of the output',
        },
        anno_db => {
            is => 'Text',
            is_optional=> 1,
            doc => 'The name of the annotation database.  Example: NCBI-human.combined-annotation',
        },
        anno_db_version => {
            is => 'Text',
            is_optional=> 1,
            doc => 'The version of the annotation database. Example: 54_36p_v2',
        },
    ],
    has_output => {
        output_tsv_file => {
            is => 'Text',
            doc => 'A tab separated output file with the amino acid sequences both wildtype and mutant',
            calculate_from => ['output_directory'],
            calculate => q| return File::Spec->join($output_directory, "snvs_wildtype.tsv"); |,
        },
    },
};

sub execute {
    my $self = shift;
    my $input = $self->input_tsv_file;
    my $output = $self->output_tsv_file;

    $self->validate_input_tsv_file();

    my $cmd = Genome::Model::Tools::Annotate::VariantProtein->execute(
        input_tsv_file  => $input,
        output_tsv_file => $output,
        anno_db         => $self->anno_db,
        version => $self->anno_db_version,
    );
    unless ($cmd->result) {
        confess $self->error_message("Couldn't execute Genome::Model::Tools::Annotate::VariantProtein $!");
    }

    return 1;
}

sub validate_input_tsv_file {
    my $self = shift;

    # Ensure that the input_tsv_file has a header
    unless (Genome::Model::Tools::Annotate::TranscriptVariants->file_has_header($self->input_tsv_file)) {
        die $self->error_message("The input_tsv_file does not have a header: %s", $self->input_tsv_file);
    }
}

1;
