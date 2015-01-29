package Genome::Model::Tools::EpitopePrediction::Pipeline;

use strict;
use warnings;

use Genome;
use Workflow::Simple;

class Genome::Model::Tools::EpitopePrediction::Pipeline {
    is => 'Command::V2',
    doc => 'Run the epitope binding prediction pipeline',
    has => [
        output_directory => {
            is => 'Text',
            doc => 'the directory where you want results stored',
        },
        somatic_variation_build => {
            is => 'Genome::Model::Build::SomaticVariation',
            is_optional => 1,
            doc => 'The somatic variation build to use for analysis',
        },
        input_tsv_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'The custom input tsv file to use for analysis if no somatic variation build is used',
        },
        anno_db => {
            is => 'Text',
            is_optional => 1,
            doc => 'The name of the annotation database to use for retrieving the wildtypes.  Example: NCBI-human.combined-annotation',
        },
        anno_db_version => {
            is => 'Text',
            is_optional => 1,
            doc => 'The version of the annotation databaseto use for retrieving the wildtypes. Example: 54_36p_v2',
        },
        peptide_sequence_length => {
            is => 'Text',
            doc => 'The length of the peptide sequences to be used when generating variant sequences',
            valid_values => [17, 21, 31],
            default_value => 21,
        },
        alleles => {
            is => 'Text',
            doc => 'A list of allele names to be used for epitope prediction with NetMHC',
            is_many => 1,
        },
        epitope_length => {
            is => 'Text',
            doc => 'Length of subpeptides to predict with NetMHC',
        },
        netmhc_version => {
            is => 'Text',
            doc => 'The NetMHC version to use',
            valid_values => ['3.0','3.4'],
            default_value => '3.4',
        },
        output_filter => {
            is => 'Text',
            doc =>
                'Type of epitopes to report in the final output - select \'top\' to report the top epitopes in terms of fold changes,  \'all\' to report all predictions ',
            valid_values => ['top', 'all'],
        },
        sample_name => {
            is => 'Text',
            doc => 'The sample name of the file being processed',
            is_optional => 1,
        },
    ],
};

sub command_class_prefix {
    return "Genome::Model::Tools::EpitopePrediction";
}

sub execute {
    my $self = shift;

    $self->debug_message("Validating Inputs...");
    $self->_validate_inputs();

    $self->debug_message("Constructing Workflow...");
    my $workflow = $self->_construct_workflow();

    $self->debug_message("Getting Workflow Inputs...");
    my $inputs = $self->_get_workflow_inputs();

    $self->debug_message("Running Workflow...");
    my $result = $workflow->execute(%$inputs);

    unless($result){
        $self->error_message( join("\n", map($_->name . ': ' . $_->error, @Workflow::Simple::ERROR)) );
        die $self->error_message("Workflow did not return correctly.");
    }

    return 1;
}

sub _construct_workflow {
    my ($self) = @_;

    my $workflow = Genome::WorkflowBuilder::DAG->create(
        name => 'EpitopePredictionWorkflow',
        log_dir => $self->output_directory,
    );

    my $get_wildtype_command = $self->_attach_get_wildtype_command($workflow);
    my $generate_variant_sequences_command = $self->_attach_generate_variant_sequences_command($workflow);
    my $filter_sequences_command = $self->_attach_filter_sequences_command($workflow);
    my $generate_fasta_key_command = $self->_attach_generate_fasta_key_command($workflow);

    $workflow->create_link(
        source => $get_wildtype_command,
        source_property => 'output_tsv_file',
        destination => $generate_variant_sequences_command,
        destination_property => 'input_file',
    );
    $workflow->create_link(
        source => $generate_variant_sequences_command,
        source_property => 'output_file',
        destination => $filter_sequences_command,
        destination_property => 'input_file',
    );
    $workflow->create_link(
        source => $filter_sequences_command,
        source_property => 'output_file',
        destination => $generate_fasta_key_command,
        destination_property => 'input_file',
    );

    my $netmhc_workflow = $self->create_netmhc_workflow;
    $workflow->add_operation($netmhc_workflow);
    for my $property (qw/allele epitope_length netmhc_version sample_name output_directory output_filter/) {
        $workflow->connect_input(
            input_property => $property,
            destination => $netmhc_workflow,
            destination_property => $property,
        );
    }

    $workflow->create_link(
        source => $filter_sequences_command,
        source_property => 'output_file',
        destination => $netmhc_workflow,
        destination_property => 'fasta_file',
    );
    $workflow->create_link(
        source => $generate_fasta_key_command,
        source_property => 'output_file',
        destination => $netmhc_workflow,
        destination_property => 'key_file',
    );

    $workflow->connect_output(
        output_property => "output_file",
        source => $netmhc_workflow,
        source_property => 'output_file',
    );

    return $workflow;
}

sub create_netmhc_workflow {
    my $self = shift;

    my $netmhc_workflow = Genome::WorkflowBuilder::DAG->create(
        name => 'NetmhcWorkflow',
        log_dir => $self->output_directory,
        parallel_by => 'allele',
    );
    my $run_netmhc_command = $self->_attach_run_netmhc_command($netmhc_workflow);
    my $parse_netmhc_command = $self->_attach_parse_netmhc_command($netmhc_workflow);

    $netmhc_workflow->create_link(
        source => $run_netmhc_command,
        source_property => 'output_file',
        destination => $parse_netmhc_command,
        destination_property => 'netmhc_file',
    );

    $netmhc_workflow->connect_output(
        output_property => "output_file",
        source => $parse_netmhc_command,
        source_property => 'parsed_file',
    );

    return $netmhc_workflow;
}

sub _attach_get_wildtype_command {
    my $self = shift;
    my $workflow = shift;

    my $get_wildtype_command = Genome::WorkflowBuilder::Command->create(
        name => 'GetWildTypeCommand',
        command => $self->get_wildtype_command_name,
    );
    $workflow->add_operation($get_wildtype_command);
    $self->_add_common_inputs($workflow, $get_wildtype_command);
    for my $property (qw/input_tsv_file anno_db anno_db_version/) {
        $workflow->connect_input(
            input_property => $property,
            destination => $get_wildtype_command,
            destination_property => $property,
        );
    }
    return $get_wildtype_command;
}

sub _attach_generate_variant_sequences_command {
    my $self = shift;
    my $workflow = shift;

    my $generate_variant_sequences_command = Genome::WorkflowBuilder::Command->create(
        name => 'GenerateVariantSequencesCommand',
        command => $self->generate_variant_sequences_command_name,
    );
    $workflow->add_operation($generate_variant_sequences_command);
    $self->_add_common_inputs($workflow, $generate_variant_sequences_command);
    for my $property (qw/peptide_sequence_length/) {
        $workflow->connect_input(
            input_property => $property,
            destination => $generate_variant_sequences_command,
            destination_property => $property,
        );
    }
    return $generate_variant_sequences_command;
}

sub _attach_filter_sequences_command {
    my $self = shift;
    my $workflow = shift;

    my $filter_sequences_command = Genome::WorkflowBuilder::Command->create(
        name => 'FilterSequencesCommand',
        command => $self->filter_sequences_command_name,
    );
    $workflow->add_operation($filter_sequences_command);
    $self->_add_common_inputs($workflow, $filter_sequences_command);
    return $filter_sequences_command;
}

sub _attach_generate_fasta_key_command {
    my $self = shift;
    my $workflow = shift;

    my $generate_fasta_key_command = Genome::WorkflowBuilder::Command->create(
        name => 'GenerateFastaKeyCommand',
        command => $self->generate_fasta_key_command_name,
    );
    $workflow->add_operation($generate_fasta_key_command);
    $self->_add_common_inputs($workflow, $generate_fasta_key_command);
    return $generate_fasta_key_command;
}

sub _attach_run_netmhc_command {
    my $self = shift;
    my $workflow = shift;

    my $run_netmhc_command = Genome::WorkflowBuilder::Command->create(
        name => "RunNetMHCCommand",
        command => $self->run_netmhc_command_name,
    );
    $workflow->add_operation($run_netmhc_command);
    for my $property (qw/allele epitope_length netmhc_version sample_name fasta_file output_directory/) {
        $workflow->connect_input(
            input_property => $property,
            destination => $run_netmhc_command,
            destination_property => $property,
        );
    }

    return $run_netmhc_command;
}

sub _attach_parse_netmhc_command{
    my $self = shift;
    my $workflow = shift;

    my $parse_netmhc_command = Genome::WorkflowBuilder::Command->create(
        name => "ParseNetMHCCommand",
        command => $self->parse_netmhc_command_name,
    );
    $workflow->add_operation($parse_netmhc_command);
    for my $property (qw/output_filter netmhc_version key_file output_directory/) {
        $workflow->connect_input(
            input_property => $property,
            destination => $parse_netmhc_command,
            destination_property => $property,
        );
    }
    return $parse_netmhc_command;
}

sub get_wildtype_command_name {
    my $self = shift;

    return $self->command_class_prefix . "::GetWildtype";
}

sub generate_variant_sequences_command_name {
    my $self = shift;

    return $self->command_class_prefix . "::GenerateVariantSequences";
}

sub filter_sequences_command_name {
    my $self = shift;

    return $self->command_class_prefix . "::FilterSequences";
}

sub generate_fasta_key_command_name {
    my $self = shift;

    return $self->command_class_prefix . "::GenerateFastaKey";
}

sub run_netmhc_command_name {
    my $self = shift;

    return $self->command_class_prefix . "::RunNetmhc";
}

sub parse_netmhc_command_name {
    my $self = shift;

    return $self->command_class_prefix . "::ParseNetmhcOutput";
}

sub _add_common_inputs {
    my $self = shift;
    my $workflow = shift;
    my $command = shift;

    my @common_inputs = qw(
        output_directory
    );

    for my $prop_name (@common_inputs) {
        $workflow->connect_input(
            input_property => $prop_name,
            destination => $command,
            destination_property => $prop_name,
        );
    }
}

sub _validate_inputs {
    my $self = shift;

    if (!defined($self->somatic_variation_build) && !defined($self->input_tsv_file)) {
        die $self->error_message("Either somatic variation build or input tsv file needs to be provided");
    }

    if (defined($self->somatic_variation_build)) {
        if (defined($self->input_tsv_file)) {
            die $self->error_message("Custom tsv file cannot be used in combination with somatic variation build");
        }
        else {
            my $top_file = File::Spec->join(
                $self->somatic_variation_build->data_directory,
                'effects',
                'snvs.hq.tier1.v1.annotated.top'
            );
            my $top_header_file = "$top_file.header";

            my $tsv_file;
            if (-f $top_header_file) {
                $tsv_file = $top_header_file;
            }
            elsif (-f $top_file) {
                $tsv_file = $top_file;
            }
            else {
                die $self->error_message("Somatic variation tsv files ($top_header_file) and ($top_file) don't exist.");
            }
            $self->status_message("Somatic variation build given. Setting input_tsv_file to $tsv_file");
            $self->input_tsv_file($tsv_file);
        }

        if (defined($self->anno_db) || defined($self->anno_db_version)) {
            die $self->error_message("Custom anno db name and version cannot be used in combination with somatic variation build");
        }
        else {
            my $annotation_build = $self->somatic_variation_build->annotation_build;
            my $annotation_db_name = $annotation_build->model->name;
            my $annotation_db_version = $annotation_build->version;
            $self->status_message("Somatic variation build given. Setting anno_db to $annotation_db_name. Setting anno_db_version to $annotation_db_version");
            $self->anno_db($annotation_db_name);
            $self->anno_db_version($annotation_db_version);
        }

        if (defined($self->sample_name)) {
            $self->status_message("Custom sample name provided. Using custom sample name %s instead of somatic variation build sample name", $self->sample_name);
        }
        else {
            my $sample_name = $self->somatic_variation_build->subject_name;
            $self->status_message("Somatic variation build given. Setting sample name to $sample_name");
            $self->sample_name($sample_name);
        }
    }
    else {
        unless (defined($self->sample_name) && defined($self->input_tsv_file) && defined($self->anno_db) && defined($self->anno_db_version)) {
            die $self->error_message("Sample name, input tsv file, anno db, and anno db version must be defined if no somatic variation build is given")
        }
    }

    unless (-s $self->input_tsv_file) {
        die $self->error_message("Input tsv file %s does not exist or has no size", $self->input_tsv_file);
    }

    unless (Genome::Sys->create_directory($self->output_directory)) {
        die $self->error_message("Coult not create directory (%s)", $self->output_directory);
    }

    my $annotation_model = Genome::Model::Tools::Annotate::VariantProtein->get_model_for_anno_db($self->anno_db);
    unless ($annotation_model) {
        die $self->error_message("Anno DB invalid: " . $self->anno_db);
    }

    unless (Genome::Model::Tools::Annotate::VariantProtein->get_build_for_model_and_anno_db_version($annotation_model, $self->anno_db_version)) {
        die $self->error_message("Anno DB version invalid: " . $self->anno_db_version);
    }

    for my $allele ($self->alleles) {
        unless (Genome::Model::Tools::EpitopePrediction::RunNetmhc->is_valid_allele_for_netmhc_version($allele, $self->netmhc_version)) {
            die $self->error_message("Allele %s not valid for NetMHC version %s", $allele, $self->netmhc_version);
        }
    }

    return 1;
}

sub _get_workflow_inputs {
    my $self = shift;

    my %inputs = (
        input_tsv_file => $self->input_tsv_file,
        output_directory => $self->output_directory,
        anno_db => $self->anno_db,
        anno_db_version => $self->anno_db_version,
        peptide_sequence_length => $self->peptide_sequence_length,
        epitope_length => $self->epitope_length,
        netmhc_version => $self->netmhc_version,
        output_filter => $self->output_filter,
        sample_name => $self->sample_name,
        allele => [$self->alleles],
    );

    return \%inputs;
}

sub final_output_file {
    my $self = shift;
    my $allele = shift;

    my $file_name = join ('.', $self->sample_name, $allele, $self->epitope_length, 'netmhc', 'parsed', $self->output_filter);
    return File::Spec->join($self->output_directory, $file_name);
}

1;
