package Genome::Model::Tools::DetectVariants2::Combine;

use strict;
use warnings;

use Genome;
use Data::Dump qw(pp);
use File::Basename;

class Genome::Model::Tools::DetectVariants2::Combine {
    is  => ['Command::V2'],
    is_abstract => 1,
    has_input => [
        input_a_id => {
            is => 'Text',
        },
        input_b_id => {
            is => 'Text',
        },
        output_directory => {
            is => 'Text',
            is_output => 1,
        },
        aligned_reads_sample => {
            is => 'Text',
        },
        control_aligned_reads_sample => {
            is => 'Text',
            is_optional => 1,
        },
        result_users => {
            is => 'HASH',
            doc => 'mapping of labels to user objects. Will be added to any generated results',
        },
    ],
    has_param => [
        lsf_queue => {
            default => $ENV{GENOME_LSF_QUEUE_DV2_WORKER},
        },
    ],
    has_optional => [
        input_a => {
            is_transient => 1,
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            id_by => 'input_a_id',
        },
        input_b => {
            is_transient => 1,
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            id_by => 'input_b_id',
        },
        _result_id => {
            is => 'Text',
            is_output => 1,
        },
        _result_class => {
            is => 'Text',
            is_output => 1,
        },
        _result => {
            is => 'UR::Object',
            id_by => '_result_id', id_class_by => '_result_class',
        },
        _vcf_result => {
            is => 'UR::Object',
            doc => 'SoftwareResult for the vcf output of this detector',
            id_by => "_vcf_result_id",
            id_class_by => '_vcf_result_class',
            is_output => 1,
        },
        _vcf_result_class => {
            is => 'Text',
            is_output => 1,
        },
        _vcf_result_id => {
            is => 'Number',
            is_output => 1,
        },
    ],
};

sub help_brief {
    "A selection of variant detectors.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt detect-variants2 combine ...
EOS
}

sub help_detail {
    return <<EOS
Tools to run variant detectors with a common API and output their results in a standard format.
EOS
}

sub _variant_type { die 'override _variant_type' };

sub result_class {
    my $self = shift;
    my $result_class = $self->class;
    $result_class =~ s/DetectVariants2::Combine/DetectVariants2::Result::Combine/;
    return $result_class;
}

sub shortcut {
    my $self = shift;

    $self->_resolve_output_directory;

    $self->debug_message("Attempting to shortcut combine result");
    unless($self->shortcut_combine){
        $self->debug_message("Could not shortcut combine result.");
        return;
    }

    if($self->_try_vcf){
        $self->debug_message("Attempting to shortcut vcf result");
        unless($self->shortcut_vcf){
            $self->debug_message("Could not shortcut vcf result.");
            return;
        }
    }

    return 1;
}

sub shortcut_combine {
    my $self = shift;

    my ($params) = $self->params_for_combine_result;
    my $result_class = $self->result_class;
    $self->debug_message("Params for shortcut_combine: " . Data::Dumper::Dumper $params);
    my $result = $result_class->get_with_lock(%$params);
    unless($result) {
        $self->debug_message('No existing result found.');
        return;
    }

    $self->_result($result);
    $self->debug_message('Using existing result ' . $result->__display_name__);
    $self->_link_to_combine_result;

    return 1;
}

sub shortcut_vcf {
    my $self = shift;
    my ($params) = $self->params_for_vcf_result;
    $self->debug_message("Params for shortcut_vcf: " . Data::Dumper::Dumper $params);
    my $result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Combine->get_with_lock(%$params);
    unless($result) {
        $self->debug_message('No existing result found.');
        return;
    }

    $self->_vcf_result($result);
    $self->debug_message('Using existing result ' . $result->__display_name__);
    $self->_link_vcf_output_directory_to_result;

    return 1;
}

sub _try_vcf {
    my $self = shift;

    my $vcf_count = 0;
    for my $input_id ($self->input_a_id,$self->input_b_id){
        my $input_result = Genome::Model::Tools::DetectVariants2::Result::Base->get($input_id);
        unless($input_result){
            $self->debug_message("No software-result associated with input_id: ".$input_id);
            return 0;
        }
        my $input_vcf_result = $input_result->get_vcf_result($self->aligned_reads_sample, $self->control_aligned_reads_sample, $self->result_users);
        $vcf_count++ if $input_vcf_result;
    }
    if($vcf_count == 2){
        return 1;
    }

    return 0;
}

sub execute {
    my $self = shift;

    $self->_resolve_output_directory;

    unless($self->shortcut_combine){
        $self->debug_message("Summoning a combine result..");
        $self->_summon_combine_result;
    }
    if($self->_try_vcf){
        unless($self->shortcut_vcf){
            $self->_summon_vcf_result;
        }
    }

    return 1;
}

sub _summon_combine_result { 
    my $self = shift;

    my ($params) = $self->params_for_combine_result;
    my $result_class = $self->result_class;
    my $result = $result_class->get_or_create(%$params);

    unless($result) {
        die $self->error_message('Failed to create generate result!');
    }

    if(-e $self->output_directory) {
        unless(readlink($self->output_directory) eq $result->output_dir) {
            #die $self->error_message('Existing output directory ' . $self->output_directory . ' points to a different location!');
        }
    }

    $self->_result($result);
    $self->debug_message('Generated result.');
    $self->_link_to_combine_result;

    return 1;
}

sub _summon_vcf_result {
    my $self = shift;

    my ($params) = $self->params_for_vcf_result;
    my $result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Combine->get_or_create(%$params); #, _instance => $self);

    unless($result) {
        die $self->error_message('Failed to create generate vcf result!');
    }

    $self->_vcf_result($result);
    $self->debug_message('Generated vcf result.');
    $self->_link_vcf_output_directory_to_result;

    return 1;
}

sub _resolve_output_directory {
    my $self = shift;
    #Subclasses override this
    return 1;
}

sub test_name_from_input_results {
    my $self = shift;

    if (pp($self->input_a->test_name) eq pp($self->input_b->test_name)) {
        return $self->input_a->test_name;
    } else {
        die sprintf("The test_names on inputs do not match: input_a (%s) has test_name (%s) and input_b (%s) has (%s)",
            $self->input_a_id, pp($self->input_a->test_name),
            $self->input_b_id, pp($self->input_b->test_name),
        );
    }
}

sub params_for_combine_result {
    my $self = shift;

    my %params = (
        input_a_id => $self->input_a_id,
        input_b_id => $self->input_b_id,
        subclass_name => $self->_result_class,
        test_name => $self->test_name_from_input_results,
        users => $self->result_users,
    );

    return \%params;
}

sub params_for_vcf_result {
    my $self = shift;
    my $aligned_reads_sample = $self->aligned_reads_sample;
    my $control_aligned_reads_sample = $self->control_aligned_reads_sample;
    my $result_users = $self->result_users;

    my $prev_result_a = Genome::SoftwareResult->get($self->input_a_id);
    my $prev_result_b = Genome::SoftwareResult->get($self->input_b_id);

    my $prev_vcf_result_a = $prev_result_a->get_vcf_result($aligned_reads_sample, $control_aligned_reads_sample, $result_users);
    my $prev_vcf_result_b = $prev_result_b->get_vcf_result($aligned_reads_sample, $control_aligned_reads_sample, $result_users);

    my $vcf_version = Genome::Model::Tools::Vcf->get_vcf_version;
    my $joinx_version = Genome::Model::Tools::Joinx->get_default_version;

    unless($prev_vcf_result_a->vcf_version eq $vcf_version){
        die $self->error_message("Couldn't locate a vcf_result with the same vcf_version for result_id: ".$self->input_a_id);
    }
    unless($prev_vcf_result_a){
        die $self->error_message("Could not locate a vcf result to use as a previous vcf-result!");
    }
    unless($prev_vcf_result_b->vcf_version eq $vcf_version){
        die $self->error_message("Couldn't locate a vcf_result with the same vcf_version for result_id: ".$self->input_b_id);
    }
    unless($prev_vcf_result_b){
        die $self->error_message("Could not locate a vcf result to use as a previous vcf-result!");
    }

    my %params = (
        input_a_id => $self->input_a_id,
        input_b_id => $self->input_b_id,
        input_id => $self->_result->id,
        test_name => $self->test_name_from_input_results,
        incoming_vcf_result_a => $prev_vcf_result_a,
        incoming_vcf_result_b => $prev_vcf_result_b,
        vcf_version => $vcf_version,
        variant_type => $self->_variant_type,
        joinx_version => $joinx_version,
        users => $self->result_users,
    );

    return \%params;
}

sub _link_vcf_output_directory_to_result {
    my $self = shift;

    require Genome::Model::Tools::DetectVariants2::Base;
    return Genome::Model::Tools::DetectVariants2::Base::_link_vcf_output_directory_to_result($self);

    return 1;
}

sub _link_to_combine_result {
    my $self = shift;

    my $result = $self->_result;
    return unless $result;

    if (-e $self->output_directory) {
        return;
    }
    else {
        return Genome::Sys->create_symlink_and_log_change($result, $result->output_dir, $self->output_directory);
    }
}

1;
