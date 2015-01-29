package Genome::Model::Tools::CopyNumber::Cnmops;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::CopyNumber::Cnmops {
  is => 'Command::V2',
  has_input => [
  tumor_refalign => {
    is => 'Genome::Model::ReferenceAlignment',
    doc => 'Tumor refalign model',
    is_optional => 1,
  },
  normal_refalign => {
    is => 'Genome::Model::ReferenceAlignment',
    doc => 'Normal refalign model',
    is_optional => 1,
  },
  clinseq_model => {
    is => 'Genome::Model::ClinSeq',
    doc => 'Clinseq model(the ref-align models will be extracted from the somatic-exome or somatic-wgs models of this model)',
    is_optional => 1,
  },
  outdir => {
    is => 'FilesystemPath',
    doc => 'Directory to write results',
  },
  roi_bed => {
    is => 'FilesystemPath',
    doc => 'Optional BED file specifying regions to call CNVs on. The intersection of the tumor and normal ROI beds are considered by default if an roi file is not specified.',
    is_optional => 1,
  },
  test => {
    is => 'Boolean',
    doc => 'True for tests, just calls CNVs on some chromosomes',
    default_value => 0,
    is_optional => 1,
  },
  annotation_build_id => {
    is => 'Genome::Model::Build::ImportedAnnotation',
    doc => 'Supply an annotation build id (e.g., 124434505 for NCBI-human.ensembl/67_37l_v2)',
    default_value => '124434505',
    is_optional => 1,
  },
  cancer_annotation_db => {
    is => 'Genome::Db::Tgi::CancerAnnotation',
    doc => 'cancer annotation db to be used.(not required if using a clinseq model as input)',
    example_values  => ['tgi/cancer-annotation/human/build37-20130401.1'],
    default => 'tgi/cancer-annotation/human/build37-20130401.1',
    is_optional => 1,
  },
  ],
  doc => 'Call CNVs on refalign models(especially Exome) using CnMops',
};

sub help_synopsis {
  return <<EOS
        gmt copy-number cnmops microarray-cnv --outdir=/gscuser/gscuser1/tmp/ --clinseq-model=2887519760
        gmt copy-number cnmops microarray-cnv --outdir=/gscuser/gscuser1/tmp/ --clinseq-model=2887519760 --roi-bed=region_of_interest.bed
        gmt copy-number cnmops microarray-cnv --outdir=/gscuser/gscuser1/tmp/ --tumor-refalign=123456788 --normal-refalign=98765432
EOS
}

sub help_detail {
  return <<EOS
Call CNVs on exome data using CnMops. CnMops has been shown to perform well on WEx data but can be used on WGS data as well. A clinseq model with underlying refalign models for normal, tumor  [OR] separate refalign models for the normal, tumor have to be provided as input for this tool. A BED file with the regions of interest can be supplied as an optional input, if this is not passed as an input then the intersection of the ROI files from the normal and tumor refalign builds will be used.
EOS
}

sub __errors__ {
  my $self = shift;
  my @errors = $self->SUPER::__errors__(@_);

  unless (-e $self->outdir && -d $self->outdir) {
    push @errors, UR::Object::Tag->create(
      type => 'error',
      properties => ['outdir'],
      desc => "Outdir: " . $self->outdir . " not found or not a directory",
    );
  }
  return @errors;
}

sub get_tumor_normal_refalign_models {
  my $self = shift;
  my $tumor_refalign;
  my $normal_refalign;
  if($self->tumor_refalign and $self->normal_refalign) {
    $tumor_refalign = $self->tumor_refalign;
    $normal_refalign = $self->normal_refalign;
  } elsif($self->clinseq_model) {
    my $base_model;
    if($self->clinseq_model->exome_model) {
      $base_model = $self->clinseq_model->exome_model;
    } else {
      die $self->error_message("Please specify a clinseq model with an exome-sv model");
    }
    if($base_model->tumor_model && $base_model->normal_model) {
      $tumor_refalign = $base_model->tumor_model;
      $normal_refalign = $base_model->normal_model;
    } else {
      die $self->error_message("Please specify a clinseq model with an exome-sv model with refalign builds");
    }
  } else {
    die $self->error_message("Please specify one clinseq model [or] two ref-align models as input!");
  }
  return $tumor_refalign, $normal_refalign;
}

sub get_refalign_bam {
  my $self = shift;
  my $refalign = shift;
  if($refalign->last_succeeded_build->whole_rmdup_bam_file) {
    return $refalign->last_succeeded_build->whole_rmdup_bam_file;
  } else {
    die $self->error_message("Unable to find alignment file for " . $refalign->name);
  }
}

sub get_ROI_bed{
  my $self = shift;
  my $refalign = shift;

  if($self->roi_bed) {
    return $self->roi_bed;
  }

  my $bed_path = Genome::Sys->create_temp_file_path();
  my $roi_bed_file = $refalign->last_succeeded_build->region_of_interest_set_bed_file($bed_path);
  if ($roi_bed_file) {
    return $roi_bed_file;
  }

  die $self->error_message("Unable to find ROI_set_bed file for " . $refalign->name);
}

sub call_cnmops {
  my $self = shift;
  my $tumor_bam = shift;
  my $normal_bam = shift;
  my $ROI_bed = shift;
  my $outdir = $self->outdir;
  my $cnmops_rscript = __FILE__.".R";
  my $cnmops_rcmd = $cnmops_rscript . " " . $tumor_bam . " " . $normal_bam . " " . $ROI_bed . " " . $outdir ; 
  if($self->test) {
    Genome::Sys->status_message("Running test mode.");
    $cnmops_rcmd = $cnmops_rcmd . " --test";
  } else {
    $cnmops_rcmd = $cnmops_rcmd . " --no-test";
  }
  Genome::Sys->shellcmd(cmd => $cnmops_rcmd);
}

sub plot_cnvs {
  my $self = shift;
  my $cnmops_hq = $self->outdir . "/cnmops.cnvs.hq";
  my $cnmops_hmm = $self->outdir . "/cnmops.cnvhmm";
  my $cnmops_cnvs = $self->outdir . "/cnmops.cnvs.txt";
  my $cnmops_bed_logrr = $self->outdir . "/cnmops.bed_logrr.txt";
  my $cnmops_hq_cmd = 'awk \' BEGIN { print "CHR\tPOS\tTUMOR\tNORMAL\tDIFF" } !/chr/ { print $1"\t"$2"\t"2^($4+1)"\t2\t"2^($4+1)-2} \' ' . $cnmops_bed_logrr . " > " .
  $cnmops_hq;
  my $cnmops_hmm_cmd = 'awk \' !/chr/ { status = "Loss"; if($5>0) { status = "Gain"; } print $1"\t"$2"\t"$3"\t"$3-$2"\t"$3-$2"\t"2^($5+1)"\t"2^($5+1)"\t2\t2\tNA\t"status } \' ' . $cnmops_cnvs . " > " .
  $cnmops_hmm;
  Genome::Sys->shellcmd(cmd => $cnmops_hq_cmd);
  Genome::Sys->shellcmd(cmd => $cnmops_hmm_cmd);
  my $cancer_annotation_db = $self->cancer_annotation_db;
  my @cnv_symbols;
  if($self->test) {
    @cnv_symbols = qw(Kinase_dGene);
  } else {
    @cnv_symbols = qw (Kinase_dGene CancerGeneCensusPlus_Sanger AntineoplasticTargets_DrugBank All);
  }
  my $gene_symbol_dir = $cancer_annotation_db->data_directory . "/GeneSymbolLists/";
  foreach my $symbol(@cnv_symbols){
    my $symbol_outdir =  $self->outdir;
    my $cnview_cmd;
    if ($symbol eq "All") {
      $cnview_cmd = Genome::Model::Tools::CopyNumber::CnView->create(annotation_build => $self->annotation_build_id, cnv_file => $cnmops_hq, segments_file => $cnmops_hmm, output_dir => $symbol_outdir, name => $symbol, cancer_annotation_db => $cancer_annotation_db, window_size => 0, verbose => 1);
    } else {
      my $gene_targets_file = "$gene_symbol_dir/$symbol" . ".txt";
      $cnview_cmd = Genome::Model::Tools::CopyNumber::CnView->create(annotation_build =>  $self->annotation_build_id, cnv_file => $cnmops_hq, segments_file => $cnmops_hmm, output_dir => $symbol_outdir, gene_targets_file => $gene_targets_file, name => $symbol, cancer_annotation_db => $cancer_annotation_db, window_size => 0, verbose => 1);
    }
    $cnview_cmd->execute();
  }
}

sub annotate_cnvs {
  my $self = shift;
  my $cnmops_bed = $self->outdir . "/cnmops.cnvs.filtered.txt";
  if(-e $cnmops_bed) {
    my $cnmops_bedpe = $self->outdir . "/cnmops.cnv.bedpe";
    my $cnmops_annotated = $self->outdir . "/cnmops.cnv.bedpe.annotated";
    my $create_bedpe_cmd = "awk \'!/chr/ { print \"cnv\\t\"\$1\"\\t\"\$2\"\\t\"\$2\"\\t\"\$1\"\\t\"\$3\"\\t\"\$3\"\\t\"\$4\"\\t\"\$5\"\\t+\" }\' $cnmops_bed > $cnmops_bedpe";
    Genome::Sys->shellcmd(cmd=>$create_bedpe_cmd);
    my $annotate = Genome::Model::Tools::Annotate::Sv::Transcripts->create(input_file => $cnmops_bedpe,
          output_file => $cnmops_annotated, print_flanking_genes => 1, annotation_build=>$self->annotation_build_id);
    $annotate->execute();
  }
}

sub intersect_bed {
  my $self = shift;
  my $bed_a = shift;
  my $bed_b = shift;
  my $bed_intersect = shift;
  Genome::Sys->shellcmd(cmd => "bedtools intersect -a $bed_a -b $bed_b > $bed_intersect");
}

sub get_ROI {
  my $self = shift;
  my $tumor_refalign = shift;
  my $normal_refalign = shift;
  my $tumor_ROI_bed = $self->get_ROI_bed($tumor_refalign);
  my $normal_ROI_bed = $self->get_ROI_bed($normal_refalign);
  my $intersected_bed = $self->outdir . "/tumor.normal.ROI.intersect.bed";
  $self->intersect_bed($tumor_ROI_bed, $normal_ROI_bed, $intersected_bed);
  return $intersected_bed;
}

sub execute {
  my $self = shift;
  my $normal_refalign;
  my $tumor_refalign;
  ($tumor_refalign, $normal_refalign) = $self->get_tumor_normal_refalign_models();
  my $tumor_bam = $self->get_refalign_bam($tumor_refalign);
  my $normal_bam = $self->get_refalign_bam($normal_refalign);
  my $ROI_bed = $self->get_ROI($tumor_refalign, $normal_refalign);
  $self->call_cnmops($tumor_bam, $normal_bam, $ROI_bed);
  $self->status_message("\nCnmops tumor, normal bams are $tumor_bam , $normal_bam");
  $self->status_message("\nROI bed is $ROI_bed");
  $self->plot_cnvs();
  $self->annotate_cnvs();
  return 1;
}

1;
