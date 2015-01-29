package Genome::Model::RnaSeq::Command::InstrumentDataAlignmentBams;

use strict;
use warnings;

use Genome;

class Genome::Model::RnaSeq::Command::InstrumentDataAlignmentBams {
    is => 'Command::V2',
    doc => "List the paths of the instrument data alignment BAMs for the provided build.",
    has => [
        build_id => {
            is => 'Number',
            shell_args_position => 1,
        },
    ],
    has_optional => [
        outdir => {
            is => 'FileSystemPath'
        },
    ],
};


sub help_detail {
    return "List the paths of the instrument data alignment BAMs for the provided build. If outdir is specified results are written to a file in outdir else results are written to STDOUT.";
}


sub execute {
    my $self  = shift;
    my $build = Genome::Model::Build->get($self->build_id);

    die $self->error_message('Please provide valid build id') unless $build;
    
     unless ($build->model->type_name eq 'reference alignment' ||
             $build->model->type_name eq 'rna seq') {
         die $self->error_message('The provided build '.$build->id. ' is not reference alignment or rna seq build. The type name is : '. $build->type_name);
     }
    my $op_fh;
    if($self->outdir) {
        open $op_fh, ">",$self->outdir."/".$build->id.".instrumentdataalignmentbams.txt";
    } else {
        open $op_fh, ">-";
    }
    print $op_fh join("\t", 'INSTRUMENT_DATA_ID', 'FLOW_CELL_ID', 'LANE', 'BAM_PATH', 'BAMQC_PATH') . "\n";
    for my $instrument_data ($build->instrument_data) {
        my $instrument_data_id = $instrument_data->id;
        my $flow_cell_id = eval { $instrument_data->flow_cell_id } || '-';
        my $lane = eval { $instrument_data->lane } || '-';

        my ($alignment_result) = $build->alignment_results_for_instrument_data($instrument_data);

        my $bam_path = $alignment_result ? $alignment_result->output_dir . '/all_sequences.bam' : '-';
        my $bamqc_path = $self->_get_bamqc_path($alignment_result);
        print $op_fh join("\t", $instrument_data_id, $flow_cell_id, $lane, $bam_path, $bamqc_path) . "\n";
    }
    close $op_fh;
    return 1;
}

#fills a hash reference, lane_bamqcpath, key is the lane
sub get_lane_bamqc_path {
    my $self = shift;
    my $build = shift;
    my $lane_bamqcpath = shift;
    for my $instrument_data ($build->instrument_data) {
        my $instrument_data_id = $instrument_data->id;
        my $flow_cell_id = eval { $instrument_data->flow_cell_id } || '-';
        my $lane = eval { $instrument_data->lane } || '-';
        my ($alignment_result) = $build->alignment_results_for_instrument_data($instrument_data);
        #Get the latest bamqc result
        my $bamqc_path = $self->_get_bamqc_path($alignment_result);
        $lane_bamqcpath->{$lane} = $bamqc_path;
    }
}

sub _get_bamqc_path {
    my $self = shift;
    my $alignment_result = shift;
    my @bamqc_results =  Genome::InstrumentData::AlignmentResult::Merged::BamQc->get(
        alignment_result_id => $alignment_result->id
    );
    my $max = '0';
    my $bamqc_result;
    for(@bamqc_results) {
        my $earliest_time = $_->best_guess_date_numeric;
        if ($earliest_time > $max) {
            $max = $earliest_time;
            $bamqc_result = $_;
        }
    }
    my $bamqc_path = $bamqc_result ? $bamqc_result->output_dir : '-';
}

1;
