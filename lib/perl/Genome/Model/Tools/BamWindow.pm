package Genome::Model::Tools::BamWindow;

use strict;
use warnings;

use Genome;
use Carp qw(confess);

class Genome::Model::Tools::BamWindow {
    is => 'Command::V2',
    has_input => {
        version => {
            is => 'Text',
            default => '0.4',
            doc => 'Version of bam-window to run',
        },
        options => {
            is => 'Text',
            doc => 'String of command line options to pass to bam-window.  Superseeds all other options',
            is_optional => 1,
        },
        bam_file => {
            is => 'Path',
            doc => 'Bam file to window',
        },
        output_file => {
            is => 'Path',
            is_output => 1,
            doc => 'Window output file',
        },
        quality => {
            is => 'Number',
            doc => 'filtering reads with mapping quality less than INT [0]',
            is_optional => 1,
        },
        window_size => {
            is => 'Number',
            doc => 'window size to count reads within [1000]',
            is_optional => 1,
        },
        paired_reads_only => {
            is => 'Boolean',
            doc => 'only include paired reads',
            is_optional => 1,
        },
        properly_paired_reads_only => {
            is => 'Boolean',
            doc => 'only include properly paired reads',
            is_optional => 1,
        },
        leftmost_only => {
            is => 'Boolean',
            doc => 'only count a read as in the window if its leftmost mapping position is within the window',
            is_optional => 1,
        },
        per_library => {
            is => 'Boolean',
            doc => 'output a column for each library in each window',
            is_optional => 1,
        },
        per_read_length => {
            is => 'Boolean',
            doc => 'output a column for each read length in each window',
            is_optional => 1,
        },
        probability => {
            is => 'Number',
            doc => 'probability of reporting a read [1.000000]',
            is_optional => 1,
        },
        filter_to_chromosomes => {
            is => 'Text',
            is_many => 1,
            doc => 'chromosomes to filter output to',
            is_optional => 1,
        }
    },
};

my %versions_ = (
    "0.4" => {
        path => "/usr/bin/bam-window",
        per_seq => 0,
    },
    "0.5" => {
        path => "/usr/bin/bam-window0.5",
        per_seq => 1,
    },
);

sub get_version {
    my $self = shift;
    my $v = $self->version;
    if (!exists $versions_{$v}) {
        confess sprintf "Invalid version for bam-window: %s", $v;
    }
    return $versions_{$v};
}

sub execute {
    my $self = shift;
    my $ver = $self->get_version;

    my $base_cmd = $ver->{path};
    my $bam_file = $self->bam_file;

    my $options_string = $self->options;
    unless($options_string){
        $options_string = $self->_get_options_string;
    }

    my $tmp_file = Genome::Sys->create_temp_file_path;
    my $output_file = $self->output_file;

    #make sure we can write the output before wasting an hour generating it
    Genome::Sys->validate_file_for_writing($output_file);

    my $cmd = join(" ", $base_cmd, $bam_file, $options_string, " > $tmp_file");
    Genome::Sys->shellcmd(
        cmd => $cmd,
        input_files => [ $bam_file ],
        output_files => [ $tmp_file ],
        skip_if_output_is_present => 0,
    );

    if ($self->filter_to_chromosomes){
       $self->_filter_to_chromosomes($tmp_file, $output_file);
    }else{
        Genome::Sys->copy_file($tmp_file, $output_file);
    }

    return 1;
}

sub _get_options_string {
    my $self = shift;
    my $options_string = "";

    if ($self->quality){
        $options_string = join(" ", $options_string, "-q", $self->quality);
    }

    if($self->window_size){
        $options_string = join(" ", $options_string, "-w", $self->window_size);
    }

    if($self->paired_reads_only){
        $options_string = join(" ", $options_string, "-p");
    }

    if($self->properly_paired_reads_only){
        $options_string = join(" ", $options_string, "-P");
    }

    if($self->leftmost_only){
        $options_string = join(" ", $options_string, "-s");
    }

    if($self->per_library){
        $options_string = join(" ", $options_string, "-l");
    }

    if($self->per_read_length){
        $options_string = join(" ", $options_string, "-r");
    }

    if($self->probability){
        $options_string = join(" ", $options_string, "-d", $self->probability);
    }

    return $options_string;
}

sub _filter_to_chromosomes{
    my ($self, $tmp_file, $output_file) = @_;
    my @filter_to_chromosomes = $self->filter_to_chromosomes;
    my $ifh = Genome::Sys->open_file_for_reading($tmp_file);
    my $ofh = Genome::Sys->open_file_for_writing($output_file);

    my $line = <$ifh>; #handle the header
    print $ofh $line;

    while(my $line = <$ifh>){
        chomp $line;
        my($chr) = split("\t", $line);
        if(grep{$chr eq $_} @filter_to_chromosomes){
            print $ofh $line, "\n";
        }
    }
    return 1;
}

1;
