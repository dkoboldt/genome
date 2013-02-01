package Genome::Model::ClinSeq::Util;

#Written by Malachi Griffith

require Exporter;

@ISA = qw( Exporter );
@EXPORT = qw();

@EXPORT_OK = qw(
                &createNewDir &checkDir &commify &memoryUsage &loadEnsemblMap &loadEntrezEnsemblData &mapGeneName &fixGeneName &importIdeogramData &getCytoband &getColumnPosition &listGeneCategories &importSymbolListNames &importGeneSymbolLists &getFilePathBase
               );

%EXPORT_TAGS = (
                all => [qw(&createNewDir &checkDir &commify &memoryUsage &loadEnsemblMap &loadEntrezEnsemblData &mapGeneName &fixGeneName &importIdeogramData &getCytoband &getColumnPosition &listGeneCategories &importSymbolListNames &importGeneSymbolLists &getFilePathBase)]
               );

use strict;
use warnings;
use Data::Dumper;
use Term::ANSIColor qw(:constants);


=head2 createNewDir

=over 3

=item Function:

Create a new directory cleanly in the specified location - Prompt user for confirmation

=item Return:

Full path to new directory

=item Args:

'-path' - Full path to new directoy

'-new_dir_name' - Name of new directory

'-force' - Clobber existing data

'-silent' - No user prompts, will make dir if it does not exist, otherwise do nothing

=item Example(s):

my $fasta_dir = &createNewDir('-path'=>$temp_dir, '-new_dir_name'=>"ensembl_genes_fasta");

=back

=cut

###############################################################################################################
#Create a new directory in a specified location                                                               #
###############################################################################################################
sub createNewDir{
  my %args = @_;
  my $base_path = $args{'-path'};
  my $name = $args{'-new_dir_name'};
  my $force = $args{'-force'};
  my $silent = $args{'-silent'};

  #Now make sure the desired new dir does not already exist
  unless ($base_path =~ /.*\/$/){
    $base_path = "$base_path"."/";
  }

  #First make sure the specified base path exists and is a directory
  unless (-e $base_path && -d $base_path){
    print RED, "\nSpecified working directory: $base_path does not appear valid! Create a working directory before proceeding\n\n", RESET;
    exit();
  }

  unless ($name =~ /.*\/$/){
    $name = "$name"."/";
  }

  my $new_path = "$base_path"."$name";

  if (-e $new_path && -d $new_path){

    if ($force){
      #If this directory already exists, and the -force option was provide, delete this directory and start it cleanly
      if ($force eq "yes"){
	print YELLOW, "\nForcing clean creation of $new_path\n\n", RESET;
	my $command = "rm -r $new_path";
	system ($command);
	mkdir($new_path);
      }else{
	print RED, "\nThe '-force' option provided to utility.pm was not understood!!", RESET;
	exit();
      }

    }elsif($silent){
      #Do nothing.
      
    }else{

      #If this directory already exists, ask the user if they wish to erase it and start clean
      print YELLOW, "\nNew dir: $new_path already exists.\n\tDo you wish to delete it and create it cleanly (y/n)? ", RESET;
      my $answer = <>;

      chomp($answer);

      if ($answer =~ /^y$/i | $answer =~ /^yes$/i){
	my $command = "rm -r $new_path";
	system ($command);
	mkdir($new_path);
      }else{
	print YELLOW, "\nUsing existing directory, some files may be over-written and others that are unrelated to the current analysis may remain!\n", RESET;
      }
    }

  }else{
    mkdir($new_path)
  }
  return($new_path);
}


=head2 checkDir

=over 3

=item Function:

Check validity of a directory and empty if the user desires - Prompt user for confirmation

=item Return:

Path to clean,valid directory

=item Args:

'-dir' - Full path to directory to be checked

'-clear' - 'yes/no' option to clear the specified directory of files

'-force' - 'yes/no' force clear without user prompt

=item Example(s):

my $working_dir = &checkDir('-dir'=>$working_dir, '-clear'=>"yes");

=back

=cut


#############################################################################################################################
#Check dir
#############################################################################################################################
sub checkDir{
  my %args = @_;
  my $dir = $args{'-dir'};
  my $clear = $args{'-clear'};
  my $force = $args{'-force'};
  my $recursive = $args{'-recursive'};

  unless ($dir =~ /\/$/){
    $dir = "$dir"."/";
  }
  unless (-e $dir && -d $dir){
    print RED, "\nDirectory: $dir does not appear to be valid!\n\n", RESET;
    exit();
  }

  unless ($force){
    $force = "no";
  }
  unless ($clear){
    $clear = "no";
  }
  unless ($recursive){
    $recursive = "no";
  }

  #Clean up the working directory
  opendir(DIRHANDLE, "$dir") || die "\nCannot open directory: $dir\n\n";
  my @temp = readdir(DIRHANDLE);
  closedir(DIRHANDLE);

  if ($clear =~ /y|yes/i){

    if ($force =~ /y|yes/i){
      if ($recursive =~ /y|yes/i){
        my $files_present = scalar(@temp) - 2;
        my $clean_dir_cmd = "rm -fr $dir"."*";
        print YELLOW, "\n\n$clean_dir_cmd\n\n", RESET;
        system($clean_dir_cmd);
      }else{
        my $files_present = scalar(@temp) - 2;
        my $clean_dir_cmd = "rm -f $dir"."*";
        print YELLOW, "\n\n$clean_dir_cmd\n\n", RESET;
        system($clean_dir_cmd);
      }
    }else{

      my $files_present = scalar(@temp) - 2;
      my $clean_dir_cmd = "rm $dir"."*";
      if ($recursive =~ /y|yes/i){
        $clean_dir_cmd = "rm -fr $dir"."*";
      }

      unless ($files_present == 0){
	print YELLOW, "\nFound $files_present files in the specified directory ($dir)\nThis directory will be cleaned with the command:\n\t$clean_dir_cmd\n\nProceed (y/n)? ", RESET;
	my $answer = <>;
	chomp($answer);
	if ($answer =~ /y|yes/i){
          if ($recursive =~ /y|yes/i){
            system($clean_dir_cmd);
          }else{
	    system($clean_dir_cmd);
          }
	}else{
	  print YELLOW, "\nContinuing and leaving files in place then ...\n\n", RESET;
	}
      }
    }
  }
  return($dir);
}


#######################################################################################################################################################################
#Load Ensembl Transcript ID - Gene ID - Gene Name mappings from flatfiles                                                                                             #
#######################################################################################################################################################################
sub loadEnsemblMap{
  my %args = @_;
  my $ensembl_version = $args{'-ensembl_version'};
  my $species = $args{-species} || 'human';

  my $clinseq_annotations_dir;
  if ($species eq 'human') {
    $clinseq_annotations_dir = "/gscmnt/sata132/techd/mgriffit/reference_annotations/";
  }
  my $ensembl_map_file = $clinseq_annotations_dir . "EnsemblGene/Ensembl_Genes_Human_v"."$ensembl_version".".txt";
  unless (-e $ensembl_map_file){
    print RED, "\n\nCould not file Ensembl ID map file with the specified reference annotations dir and ensembl version:\n$ensembl_map_file\n\n", RESET;
    exit(1);
  }
  my %ensembl_map;
  my $header = 1;
  open (ENSG, "$ensembl_map_file") || die "\n\nCould not open ensembl map file: $ensembl_map_file\n\n";
  while (<ENSG>){
    chomp($_);
    my @line = split("\t", $_);
    if ($header){
      $header = 0;
      next();
    }
    my $ensg_id = $line[0];
    my $enst_id = $line[1];
    my $ensg_name = $line[2];
    $ensembl_map{$enst_id}{ensg_id} = $ensg_id;
    $ensembl_map{$enst_id}{ensg_name} = $ensg_name;
  }
  close(ENSG);

  return(\%ensembl_map);
}




#######################################################################################################################################################################
#Load Entrez Data from flatfiles                                                                                                                                      #
#######################################################################################################################################################################
sub loadEntrezEnsemblData{
  my %args = @_;

  my $species = $args{-species} || 'human';

  my $taxon_id;
  my $entrez_dir;
  my $ensembl_dir;
  my $ucsc_dir;
  my @files;

  #Parse Entrez flatfiles and Ensembl files from BioMart
  #ftp://ftp.ncbi.nih.gov/gene/DATA/gene2accession.gz
  #ftp://ftp.ncbi.nih.gov/gene/DATA/gene_info.gz
  if ($species eq 'human') {
      $taxon_id = '9606';
      my $clinseq_annotations_dir = "/gscmnt/sata132/techd/mgriffit/reference_annotations/";
      $entrez_dir = $clinseq_annotations_dir . "EntrezGene/";
      $ensembl_dir = $clinseq_annotations_dir . "/EnsemblGene/";
      $ucsc_dir = $clinseq_annotations_dir . "/UcscGene/";
      @files = qw (Ensembl_Genes_Human_v70.txt Ensembl_Genes_Human_v69.txt Ensembl_Genes_Human_v68.txt Ensembl_Genes_Human_v67.txt Ensembl_Genes_Human_v66.txt Ensembl_Genes_Human_v65.txt Ensembl_Genes_Human_v64.txt Ensembl_Genes_Human_v63.txt Ensembl_Genes_Human_v62.txt Ensembl_Genes_Human_v61.txt Ensembl_Genes_Human_v60.txt Ensembl_Genes_Human_v59.txt Ensembl_Genes_Human_v58.txt Ensembl_Genes_Human_v56.txt Ensembl_Genes_Human_v55.txt Ensembl_Genes_Human_v54.txt Ensembl_Genes_Human_v53.txt Ensembl_Genes_Human_v52.txt Ensembl_Genes_Human_v51.txt);
  } elsif ($species eq 'mouse') {
      $taxon_id = '10090';
      my $clinseq_annotations_dir = "/gscmnt/sata132/techd/solexa/jwalker/RNAseq/annotation/mm9/";
      $entrez_dir = $clinseq_annotations_dir . 'entrez/';
      $ensembl_dir = $clinseq_annotations_dir . 'ensembl/';
      $ucsc_dir = $clinseq_annotations_dir . 'ucsc/';
      @files = qw (ensembl_v64_id_to_gene_name.txt ensembl_v63_id_to_gene_name.txt ensembl_v62_id_to_gene_name.txt ensembl_v61_id_to_gene_name.txt ensembl_v60_id_to_gene_name.txt ensembl_v59_id_to_gene_name.txt ensembl_v58_id_to_gene_name.txt ensembl_v57_id_to_gene_name.txt ensembl_v56_id_to_gene_name.txt ensembl_v55_id_to_gene_name.txt ensembl_v54_id_to_gene_name.txt ensembl_v53_id_to_gene_name.txt ensembl_v52_id_to_gene_name.txt ensembl_v51_id_to_gene_name.txt ensembl_v50_id_to_gene_name.txt);
  }

  my %edata;

  #Check input dirs
  unless (-e $entrez_dir && -d $entrez_dir){
    print RED, "\n\nEntrez dir not valid: $entrez_dir\n\n", RESET;
    exit();
  }
  unless ($entrez_dir =~ /\/$/){
    $entrez_dir .= "/";
  }
  unless (-e $ensembl_dir && -d $ensembl_dir){
    print RED, "\n\nEnsembl dir not valid: $ensembl_dir\n\n", RESET;
    exit();
  }
  unless ($ensembl_dir =~ /\/$/){
    $ensembl_dir .= "/";
  }

  #Load data from Ensembl files
  my %entrez_map;      #Entrez_id          -> symbol, synonyms
  my %ensembl_map;     #Ensembl_id         -> entrez_id(s) - from Entrez
  my %ensembl_map2;    #Ensembl_gene_id    -> symbol(s) - from Ensembl
  my %symbols_map;     #Symbols            -> entrez_id(s)
  my %synonyms_map;    #Synonyms           -> entrez_id(s)
  my %p_acc_map;       #Protein accessions -> entrez_id(s)
  my %g_acc_map;       #Genomic accessions -> entrez_id(s)

  my $gene2accession_file = "$entrez_dir"."gene2accession.$species";
  my $gene_info_file = "$entrez_dir"."gene_info.$species";
  open (GENE, "$gene_info_file") || die "\n\nCould not open gene_info file: $gene_info_file\n\n";
  while(<GENE>){
    chomp($_);
    if ($_ =~ /^\#/){
      next();
    }
    my @line = split("\t", $_);
    my $tax_id = uc($line[0]);
    #Skip all non-human records
    unless ($tax_id eq $taxon_id){
      next();
    }
    my $entrez_id = uc($line[1]);
    my $symbol = uc($line[2]);
    my $synonyms = uc($line[4]);
    my $ext_ids = uc($line[5]);

    #Get synonyms for each gene and divide each into a unique hash
    if ($synonyms eq "-"){
      $synonyms = "na";
    }
    my @synonyms_array = split("\\|", $synonyms);
    my %synonyms_hash;   
    foreach my $syn (@synonyms_array){
      $synonyms_hash{$syn} = 1;
    }

    #Parse the external IDs field for Ensembl gene IDs (Other possibilites include HGNC, MIM, HPRD)
    my %ensembl_hash;
    my @ext_ids_array = split("\\|", $ext_ids);
    $entrez_map{$entrez_id}{ensembl_id} = "na";
    foreach my $ext_string (@ext_ids_array){
      if ($ext_string =~ /ENSEMBL/i){
        if ($ext_string =~ /ENSEMBL\:(\w+)/){
          $entrez_map{$entrez_id}{ensembl_id} = $1;
          $ensembl_hash{$1} = 1;
        }else{
          print RED, "\n\nFormat of Ensembl field not understood: $ext_string\n\n", RESET;
          exit();
        }   
      }else{
        next();
      }
    }

    #Store entrez info keyed on entrez id
    #print "\n$entrez_id\t$symbol\t@synonyms_array";
    $entrez_map{$entrez_id}{symbol} = $symbol;
    $entrez_map{$entrez_id}{synonyms_string} = $synonyms;
    $entrez_map{$entrez_id}{synonyms_array} = \@synonyms_array;
    $entrez_map{$entrez_id}{synonyms_hash} = \%synonyms_hash;

    #Store entrez info keyed on symbol
    #print "\n$symbol\t$entrez_id";
    if ($symbols_map{$symbol}){
      my $ids = $symbols_map{$symbol}{entrez_ids};
      $ids->{$entrez_id} = 1;
    }else{
      my %tmp;
      $tmp{$entrez_id} = 1;
      $symbols_map{$symbol}{entrez_ids} = \%tmp;
    }

    #Store synonym to entrez_id mappings
    foreach my $syn (@synonyms_array){
      if ($synonyms_map{$syn}){
        my $ids = $synonyms_map{$syn}{entrez_ids};
        $ids->{$entrez_id} = 1;
      }else{
        my %tmp;
        $tmp{$entrez_id} = 1;
        $synonyms_map{$syn}{entrez_ids} = \%tmp;
      }
    }

    #Store ensembl to entrez_id mappings
    foreach my $ens (sort keys %ensembl_hash){
      if ($ensembl_map{$ens}){
        my $ids = $ensembl_map{$ens}{entrez_ids};
        $ids->{$entrez_id} = 1;
      }else{
        my %tmp;
        $tmp{$entrez_id} = 1;
        $ensembl_map{$ens}{entrez_ids} = \%tmp;
      }
    }
  }
  close (GENE);

  open (ACC, "$gene2accession_file") || die "\n\nCould not open gene2accession file: $gene2accession_file\n\n";
  while(<ACC>){
    chomp($_);
    if ($_ =~ /^\#/){
      next();
    }
    my @line = split("\t", $_);
    my $tax_id = uc($line[0]);
    #Skip all non-human records
    unless ($tax_id eq $taxon_id){
      next();
    }
    my $entrez_id = uc($line[1]);
    my $prot_id = uc($line[5]);
    my $genome_id = uc($line[7]);

    #Protein accession
    unless ($prot_id eq "-"){
      #If the prot is not defined, skip
      #Clip the version number
      if ($prot_id =~ /(\w+)\.\d+/){
        $prot_id = $1;
      }
      #print "\n$entrez_id\t$prot_id";
      if ($p_acc_map{$prot_id}){
        my $ids = $p_acc_map{$prot_id}{entrez_ids};
        $ids->{$entrez_id} = 1;
      }else{
        my %tmp;
        $tmp{$entrez_id} = 1;
        $p_acc_map{$prot_id}{entrez_ids} = \%tmp;
      }
    }

    #Genomic accession
    unless ($genome_id eq "-"){
      #If the genome accession is not defined, skip
      #Clip the version number
      if ($genome_id =~ /(\w+)\.\d+/){
        $genome_id = $1;
      }
      if ($g_acc_map{$genome_id}){
        my $ids = $g_acc_map{$genome_id}{entrez_ids};
        $ids->{$entrez_id} = 1;
      }else{
        my %tmp;
        $tmp{$entrez_id} = 1;
        $g_acc_map{$genome_id}{entrez_ids} = \%tmp;
      }
    }
  }
  close (ACC);

  #print Dumper %entrez_map;
  #print Dumper %symbols_map;
  #print Dumper %synonyms_map;
  #print Dumper %p_acc_map;

  #Now load ensembl gene id to gene name mappings from a series of legacy ensembl versions
  #Give preference to latest build

  foreach my $file (@files){
    my $path = "$ensembl_dir"."$file";
    open (ENSG, "$path") || die "\n\nCould not open file: $path\n\n";
    while(<ENSG>){
      chomp($_);
      my @line = split("\t", $_);
      my $ensg_id = uc($line[0]);
      my $enst_id = uc($line[1]);
      my $ensg_name = uc($line[2]);
      if ($ensg_name =~ /(.*)\.\d+$/){
        $ensg_name = $1;
      }
      #Create one hash that is simply ENSG id to associated gene name
      unless($ensembl_map2{$ensg_id}){
        $ensembl_map2{$ensg_id}{name}=$ensg_name;
        $ensembl_map2{$ensg_id}{source}=$file;
      }
    }
    close(ENSG);
  }

  #Now load UCSC gene/transcript to gene symbol mappings
  my $ucsc_file = "$ucsc_dir"."UCSC.Genes.info";
  open (UCSC, "$ucsc_file") || die "\n\nCould not open UCSC file: $ucsc_file in &loadEntrezEnsemblData()\n\n";
  my %ucsc_map;
  my $header = 1;
  while(<UCSC>){
    chomp($_);
    my @line = split("\t", $_);
    my $ucsc_id = uc($line[0]);
    my $ucsc_name = uc($line[1]);
    if ($header){
      $header = 0;
      next();
    }
    #Clip the version number from the ID
    if ($ucsc_id =~ /(.*)\.\d+$/){
      $ucsc_id = $1;
    }
    $ucsc_map{$ucsc_id}{name}=$ucsc_name;
  }
  close(UCSC);

  $edata{'entrez_ids'} = \%entrez_map;
  $edata{'ensembl_ids'} = \%ensembl_map;
  $edata{'ensembl_ids2'} = \%ensembl_map2;
  $edata{'symbols'} = \%symbols_map;
  $edata{'synonyms'} = \%synonyms_map;
  $edata{'protein_accessions'} = \%p_acc_map;
  $edata{'genome_accessions'} = \%g_acc_map;
  $edata{'ucsc_ids'} = \%ucsc_map;

  return(\%edata);
}


#######################################################################################################################################################################
#If possible translate the current gene name or ID into an official gene name from Entrez                                                                             #
#######################################################################################################################################################################
sub mapGeneName{
  my %args = @_;
  my $edata = $args{'-entrez_ensembl_data'};
  my $original_name = uc($args{'-name'});
  my $verbose = $args{'-verbose'};
  my $multiple_names_allowed;
  if (defined($args{'-multiple_names_allowed'})){
    $multiple_names_allowed = $args{'-multiple_names_allowed'};
  }


  my $ensembl_id;
  if (defined($args{'-ensembl_id'})){
    $ensembl_id = uc($args{'-ensembl_id'});
  }
  my $ucsc_id;
  if (defined($args{'-ucsc_id'})){
    $ucsc_id = uc($args{'-ucsc_id'});
    #If the incoming ucsc id has a trailing version number, strip it off before comparison
    if ($ucsc_id =~ /(.*)\.\d+$/){
      $ucsc_id = $1;
    }
  }
  
  #Unless a better match is found, the original name will be returned
  my $corrected_name = $original_name; 

  #If the incoming gene name has a trailing version number, strip it off before comparison
  if ($original_name =~ /(.*)\.\d+$/){
    $original_name = $1;
  }

  #Load the mapping hashes
  my $entrez_map = $edata->{'entrez_ids'};
  my $ensembl_map = $edata->{'ensembl_ids'};
  my $ensembl_map2 = $edata->{'ensembl_ids2'};
  my $symbols_map = $edata->{'symbols'};
  my $synonyms_map = $edata->{'synonyms'};
  my $prot_acc_map = $edata->{'protein_accessions'};
  my $genome_acc_map = $edata->{'genome_accessions'};
  my $ucsc_map = $edata->{'ucsc_ids'};

  my $any_match = 0;
  my %entrez_symbols;
  my $entrez_name_string = '';

  #Try mapping directly to the entrez symbols
  my $entrez_match = 0;
  if ($symbols_map->{$original_name}){
    $entrez_match = 1;
    $any_match = 1;
    my $entrez_ids = $symbols_map->{$original_name}->{entrez_ids};
    foreach my $entrez_id (keys %{$entrez_ids}){
      my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
      $entrez_symbols{$entrez_symbol}=1;
    }
  }
  if ($entrez_match){
    my @entrez_symbols = keys %entrez_symbols;
    $entrez_name_string = join(",", @entrez_symbols);
    $corrected_name = $entrez_name_string;
  }

  #Unless a match was already found, try mapping to ensembl IDs and then to entrez symbols
  #This assumes that the 'name' reported is actually an ensembl ID, something that happens routinely in the somatic variation pipeline...
  my $ensembl_match = 0;
  unless ($any_match){
    if ($ensembl_map->{$original_name}){
      $ensembl_match = 1;
      $any_match = 1;
      my $entrez_ids = $ensembl_map->{$original_name}->{entrez_ids};
      foreach my $entrez_id (keys %{$entrez_ids}){
        my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
        $entrez_symbols{$entrez_symbol}=1;
      }
    }
    if ($ensembl_match){
      my @entrez_symbols = keys %entrez_symbols;
      $entrez_name_string = join(",", @entrez_symbols);
      $corrected_name = $entrez_name_string;
    }
  }

  #Unless a match was already found, try mapping to ensembl IDs (from Ensembl) and then to Ensembl symbols
  unless ($any_match){
    if ($ensembl_map2->{$original_name}){
      $ensembl_match = 1;
      $any_match = 1;
      $corrected_name = $ensembl_map2->{$original_name}->{name};
    }
  }

  #Unless a match was already found, try mapping to protein accession IDs, and then to Entrez symbols
  unless ($any_match){
    my $protein_acc_match = 0;
    if ($prot_acc_map->{$original_name}){
      $protein_acc_match = 1;
      $any_match = 1;
      my $entrez_ids = $prot_acc_map->{$original_name}->{entrez_ids};
      foreach my $entrez_id (keys %{$entrez_ids}){
        my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
        $entrez_symbols{$entrez_symbol}=1;
      }
    }
    if ($protein_acc_match){
      my @entrez_symbols = keys %entrez_symbols;
      $entrez_name_string = join(",", @entrez_symbols);
      $corrected_name = $entrez_name_string;
    }
  }

  #Unless a match was already found, try mapping to genome IDs, and then to Entrez symbols
  unless ($any_match){
    my $genome_acc_match = 0;
    if ($genome_acc_map->{$original_name}){
      $genome_acc_match = 1;
      $any_match = 1;
      my $entrez_ids = $genome_acc_map->{$original_name}->{entrez_ids};
      foreach my $entrez_id (keys %{$entrez_ids}){
        my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
        $entrez_symbols{$entrez_symbol}=1;
      }
    }
    if ($genome_acc_match){
      my @entrez_symbols = keys %entrez_symbols;
      $entrez_name_string = join(",", @entrez_symbols);
      $corrected_name = $entrez_name_string;
    }
  }

  #Unless a match was already found, try mapping to Entrez synonyms, and then to Entrez symbols
  #Only allow 1-to-1 matches for synonyms...
  unless ($any_match){
    my $synonyms_match = 0;
    if ($synonyms_map->{$original_name}){
      my $entrez_ids = $synonyms_map->{$original_name}->{entrez_ids};
      my $match_count = keys %{$entrez_ids};
      if ($match_count == 1){
        $synonyms_match = 1;
        $any_match = 1;
        foreach my $entrez_id (keys %{$entrez_ids}){
          my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
          $entrez_symbols{$entrez_symbol}=1;
        }
      }
    }
    if ($synonyms_match){
      my @entrez_symbols = keys %entrez_symbols;
      $entrez_name_string = join(",", @entrez_symbols);
      $corrected_name = $entrez_name_string;
    }
  }

  #Unless a match was already found, try mapping to ensembl IDs (from Entrez) and then to entrez symbols - starting with an actual ensembl ID supplied separately
  if ($ensembl_id){
    unless ($any_match){
      if ($ensembl_map->{$ensembl_id}){
        $ensembl_match = 1;
        $any_match = 1;
        my $entrez_ids = $ensembl_map->{$ensembl_id}->{entrez_ids};
        foreach my $entrez_id (keys %{$entrez_ids}){
          my $entrez_symbol = $entrez_map->{$entrez_id}->{symbol};
          $entrez_symbols{$entrez_symbol}=1;
        }
      }
      if ($ensembl_match){
        my @entrez_symbols = keys %entrez_symbols;
        $entrez_name_string = join(",", @entrez_symbols);
        $corrected_name = $entrez_name_string;
      }
    }
  }

  #Unless a match was already found, try mapping to ensembl IDs (from Ensembl) and then to Ensembl symbols - starting with an actual ensembl ID supplied separately
  if ($ensembl_id){
    unless ($any_match){
      if ($ensembl_map2->{$ensembl_id}){
        $ensembl_match = 1;
        $any_match = 1;
        $corrected_name = $ensembl_map2->{$ensembl_id}->{name};
      }
    }
  }

  #Unless a match was already found, try mapping to UCSC IDs (from UCSC) - starting with an actual UCSC ID supplied separately
  my $ucsc_match = 0;
  if ($ucsc_id){
    unless ($any_match){
      if ($ucsc_map->{$ucsc_id}){
        $ucsc_match = 1;
        $any_match = 1;
        $corrected_name = $ucsc_map->{$ucsc_id}->{name};
      }
    }
  }

  #Note!
  #Do not return multiple names - unless specified, reset multiple names match to original name
  my @names = split(",", $corrected_name);
  my $name_count = scalar(@names);
  if ($name_count > 1){
    unless ($multiple_names_allowed){
      $corrected_name = $original_name;
    }
  }


  if ($verbose){
    if ($entrez_name_string eq $original_name){
      print BLUE, "\nSimple Entrez match: $original_name -> $corrected_name", RESET;
    }elsif($corrected_name eq $original_name){
      print YELLOW, "\nNo matches: $original_name -> $corrected_name", RESET;
    }else{
      print GREEN, "\nFixed name: $original_name -> $corrected_name", RESET;
    }
  }
  my $uc_corrected_name = uc($corrected_name);
  return($uc_corrected_name);
}


###################################################################################################################################
#Attempt to fix gene names to Entrez                                                                                              #
###################################################################################################################################
sub fixGeneName{
  my %args = @_;
  my $original_gene_name = $args{'-gene'};
  my $entrez_ensembl_data = $args{'-entrez_ensembl_data'};
  my $verbose = $args{'-verbose'};
  my $fixed_gene_name;
  if ($original_gene_name =~ /^ensg\d+/i){
    #If the gene name looks like an Ensembl name, try fixing it twice to allow: Ensembl->Name->Entrez Name
    $fixed_gene_name = &mapGeneName('-entrez_ensembl_data'=>$entrez_ensembl_data, '-name'=>$original_gene_name, '-ensembl_id'=>$original_gene_name, '-verbose'=>$verbose);
    $fixed_gene_name = &mapGeneName('-entrez_ensembl_data'=>$entrez_ensembl_data, '-name'=>$fixed_gene_name, '-verbose'=>$verbose);
  }elsif($original_gene_name =~ /^uc\w{6}\.\d+/i){
    $fixed_gene_name = &mapGeneName('-entrez_ensembl_data'=>$entrez_ensembl_data, '-name'=>$original_gene_name, '-ucsc_id'=>$original_gene_name, '-verbose'=>$verbose);
    $fixed_gene_name = &mapGeneName('-entrez_ensembl_data'=>$entrez_ensembl_data, '-name'=>$fixed_gene_name, '-verbose'=>$verbose);
  }else{
    $fixed_gene_name = &mapGeneName('-entrez_ensembl_data'=>$entrez_ensembl_data, '-name'=>$original_gene_name, '-verbose'=>$verbose);
  }
  return($fixed_gene_name)
}


###################################################################################################################################
#List gene category files and the number of genes, return the names and counts for each                                           #
###################################################################################################################################
sub listGeneCategories{
  my %args = @_;
  my $dir = $args{'-category_dir'};
  my $verbose = $args{'-verbose'};
  my %categories;
  #Clean up the working directory
  opendir(DIRHANDLE, "$dir") || die "\nCannot open directory: $dir\n\n";
  my @temp = readdir(DIRHANDLE);
  closedir(DIRHANDLE);
  foreach my $file (@temp){
    if ($file =~ /(.*)\.txt/){
      my $category_name = $1;
      my $path = "$dir"."$file";
      open(FILE, "$path") || die "\n\nCould not open file: $path\n\n";
      my %genes;
      while(<FILE>){
        chomp($_);
        $genes{$_}=1;
      }
      close(FILE);
      my $symbol_count = keys %genes;
      $categories{$category_name}=$symbol_count;
    }else{
      next();
    }
  }
  my $cat_count = keys %categories;
  if ($verbose){
    print BLUE, "\n\nFound $cat_count gene categories to chose from:", RESET;
  }
  foreach my $cat (sort keys %categories){
    if ($verbose){
      print YELLOW, "\n\t$categories{$cat} genes -> $cat", RESET;
    }
  }
  if ($verbose){
    print "\n\n";
  }
  return(\%categories)
}





###################################################################################################################################
#Import symbol list names                                                                                               #
###################################################################################################################################
sub importSymbolListNames{
  my %args = @_;
  my $gene_symbol_lists_dir = $args{'-gene_symbol_lists_dir'};
  my $verbose = $args{'-verbose'};

  my %lists;
  my %master_lists;
  my %master_groups;
  my %sublists;

  #The following file defines all the possible gene symbol lists that will be used for annotation purposes
  #Perform basic checks on these file and make sure no duplicates are being defined
  my $master_list_file = $gene_symbol_lists_dir . "config/MasterList.txt";
  open (MASTER, "$master_list_file") || die "\n\nCould not open master gene symbol list file: $master_list_file\n\n";
  my $header = 1;
  my $order = 0;
  while(<MASTER>){
    if ($header){
      $header = 0;
      next();
    }
    chomp($_);
    my @line = split("\t", $_);
    my $name = $line[0];
    my $filename = $line[1];
    my $readable = $line[2];
    my $source = $line[3];
    
    #Get the gene count of each of these files
    my $path = $gene_symbol_lists_dir . "$filename";
    open(IN, "$path") || die "\n\nCould not find expected gene list file: $path in $gene_symbol_lists_dir\n\n";
    my %genes;
    while(<IN>){
      chomp($_);
      if ($genes{$_}){
        if ($verbose){
          print YELLOW, "\n\nFound a duplicate gene name ($_) in $path", RESET;
        }
      }
      $genes{$_}=1;
    }
    close(IN);
    my $count = keys %genes;

    #Check to see if the master list name is unique, and if so, store it
    if (defined($master_lists{$name})){
      print RED, "\n\nFound a duplicate gene_symbol list name ($name) in $master_list_file\n\n", RESET;
      exit(1);
    }
    $order++;
    $master_lists{$name}{filename} = $filename;
    $master_lists{$name}{readable} = $readable;
    $master_lists{$name}{source} = $source;
    $master_lists{$name}{count} = $count;
    $master_lists{$name}{order} = $order;
  }
  close(MASTER);

  #The following file defines meta-groups of gene symbol lists
  #A group can be composed of one or more of the groups defined above
  my $master_group_file = $gene_symbol_lists_dir . "config/MasterGroups.txt";
  open (GROUP, "$master_group_file") || die "\n\nCould not open master group file: $master_group_file\n\n";
  $header = 1;
  $order = 0;
  while(<GROUP>){
    if ($header){
      $header = 0;
      next();
    }
    $order++;
    chomp($_);
    my @line = split("\t", $_);
    my $name = $line[0];
    my $readable = $line[1];
    my $members = $line[2];
    my @member_list = split(",", $members);
    my $member_count = scalar(@member_list);

    #Make sure every member in this group is in the master list
    my %genes;
    foreach my $member (@member_list){
      unless ($master_lists{$member}){
        print RED, "\n\nGene group file: $master_group_file contains a group ($name) with a member ($member) that is not in the master gene symbol list file: $master_list_file\n\n", RESET;
        exit(1);
      }
      my $filename = $master_lists{$member}{filename};
      my $path = $gene_symbol_lists_dir . "$filename";
      open(IN, "$path") || die "\n\nCould not find expected gene list file: $path in $gene_symbol_lists_dir\n\n";
      while(<IN>){
        chomp($_);
        $genes{$_}=1;
      }
      close(IN);
    }
    #Make sure this group name is not a duplicate
    if (defined($master_groups{$name})){
      print RED, "\n\nFound a duplicate gene group name ($name) in $master_group_file\n\n", RESET;
      exit(1);
    }
    my $gene_count = keys %genes;
    $master_groups{$name}{order} = $order;
    $master_groups{$name}{readable} = $readable;
    $master_groups{$name}{members} = \@member_list;
    $master_groups{$name}{member_count} = $member_count;
    $master_groups{$name}{gene_count} = $gene_count;
  }
  close(GROUP);

  #Load all the sublists of groups that are defined in:  $gene_symbol_lists_dir/config/group_lists/;
  my @result = `ls $gene_symbol_lists_dir/config/group_lists/*.txt`;
  chomp(@result);
  foreach my $file (@result){
    if ($file =~ /group_lists\/(\S+)\.txt$/){
      my $sublist_name = $1;
      $sublists{$sublist_name}{path} = $file;
      my %groups;
      my $header = 1;
      my $order = 0;
      open(SUBLIST, "$file") || die "\n\nCould not open file: $file in &importSymbolListNames()\n\n";
      while(<SUBLIST>){
        if ($header){
          $header = 0;
          next();
        }
        chomp($_);
        $order++;
        $groups{$_}{order}=$order;
      }
      close(SUBLIST);
      my $group_count = keys %groups;
      $sublists{$sublist_name}{groups} = \%groups;
      $sublists{$sublist_name}{group_count} = $group_count;
    }else{
      print RED, "\n\nCould not determine sublist name for $file in &importSymbolListNames()\n\n", RESET;
      exit(1);
    }
  }

  $lists{master_list} = \%master_lists;
  $lists{master_group_list} = \%master_groups;
  $lists{sublists} = \%sublists;
  
  return(\%lists);
}


###################################################################################################################################
#Import a set of gene symbol lists                                                                                                #
###################################################################################################################################
sub importGeneSymbolLists{
  my %args = @_;
  my $gene_symbol_lists_dir = $args{'-gene_symbol_lists_dir'};
  my @symbol_list_names = @{$args{'-symbol_list_names'}};
  my $entrez_ensembl_data = $args{'-entrez_ensembl_data'};
  my $verbose = $args{'-verbose'};
  my %symbol_lists;

  my $s = 0;
  foreach my $file (@symbol_list_names){
    $s++;
    my $file_path = $gene_symbol_lists_dir."$file".".txt";
    open(GENES, "$file_path") || die "\n\nCould not open gene symbol file: $file_path\n\n";
    my %symbols;
    while(<GENES>){
      chomp($_);
      my @line = split("\t", $_);
      my $symbol = $line[0];
      my $fixed_gene_name = &fixGeneName('-gene'=>$symbol, '-entrez_ensembl_data'=>$entrez_ensembl_data, '-verbose'=>$verbose);
      $symbols{$fixed_gene_name}=1;
    }
    close(GENES);
    $symbol_lists{$file}{symbols} = \%symbols;
    $symbol_lists{$file}{order} = $s;
  }

  #TODO: How many of the gene symbols actually match Entrez?  
  #This is important later for determining later how much a list of genes is enriched for members of the gene symbol list
  

  return(\%symbol_lists);
}


#############################################################################################################################
#Add commas to number.  e.g. 1000000 to 1,000,000                                                                           #
#############################################################################################################################
sub commify {
   local $_  = shift;
   1 while s/^(-?\d+)(\d{3})/$1,$2/;
   return $_;
}


#############################################################################################################################
#Return message describing memory usage of the current process                                                              #
#############################################################################################################################
sub memoryUsage{
  my $pid = $$;
  my $ps_query = `ps -p $pid -o pmem,rss`;
  my @process_info = split ("\n", $ps_query);
  my $memory_usage = '';
  my $memory_usage_p = '';
  if ($process_info[1] =~ /(\S+)\s+(\S+)/){
    $memory_usage_p = $1;
    $memory_usage = $2;
  }
  my $memory_usage_m = sprintf("%.1f", ($memory_usage/1024));
  my $message = "Memory usage: $memory_usage_m Mb ($memory_usage_p%)";
  return($message);
}


#############################################################################################################################
#Parse import the coordinates of the ideogram file using a subroutine                                                       #
#Example input file: /gscmnt/sata132/techd/mgriffit/reference_annotations/hg19/ideogram/ChrBandIdeogram.tsv                 #
#############################################################################################################################
sub importIdeogramData{
  my %args = @_;
  my $ideogram_file = $args{'-ideogram_file'};
  unless (-e $ideogram_file){
    print RED, "\n\n&importIdeogramData -> could not find ideogram file\n\n", RESET;
    exit();
  }
  open (IDEO, $ideogram_file) || die "\n\nCould not open ideogram file: $ideogram_file\n\n";
  my %ideo_data;
  while(<IDEO>){
    chomp($_);
    my @line = split("\t", $_);
    if ($_ =~ /^\#/){
      next();
    }
    my $chr = $line[0];
    my $chr_start = $line[1];
    my $chr_end = $line[2];
    my $name = $line[3];
    my $giemsa_stain = $line[4];

    my $chr_name = '';
    if ($chr =~ /chr(\w+)/){
      $chr_name = $1;
    }else{
      print RED, "\n\n&importIdeogramData -> could not understand chromosome name format\n\n", RESET;
      exit();
    }
    my $cytoname = "$chr_name"."$name";
    if ($ideo_data{$chr}){
      my $cytobands = $ideo_data{$chr}{cytobands};
      $cytobands->{$cytoname}->{chr_start} = $chr_start;
      $cytobands->{$cytoname}->{chr_end} = $chr_end;
      $cytobands->{$cytoname}->{giemsa_stain} = $giemsa_stain;
      $cytobands->{$cytoname}->{name} = $name;
    }else{
      my %tmp;
      $tmp{$cytoname}{chr_start} = $chr_start;
      $tmp{$cytoname}{chr_end} = $chr_end;
      $tmp{$cytoname}{giemsa_stain} = $giemsa_stain;
      $tmp{$cytoname}{name} = $name;
      $ideo_data{$chr}{cytobands} = \%tmp;
    }
  }
  close(IDEO);
  return(\%ideo_data);
}


#############################################################################################################################
#Given some chromosome coordinates and an object of ideogram data, generate a cytoband string                               #
#############################################################################################################################
sub getCytoband{
  my %args = @_;
  my $ideo_data = $args{'-ideo_data'};
  my $chr = $args{'-chr'};
  my $chr_start = $args{'-chr_start'};
  my $chr_end = $args{'-chr_end'};
  my $cytoband_string = '';

  unless($cytoband_string){
    $cytoband_string = "NA";
  }

  if ($ideo_data->{$chr}){
    my $cytobands = $ideo_data->{$chr}->{cytobands};
    my %matches;
    my $m = 0;
    foreach my $cyto (sort {$cytobands->{$a}->{chr_start} <=> $cytobands->{$b}->{chr_start}} keys %{$cytobands}){
      my $cyto_start = $cytobands->{$cyto}->{chr_start};
      my $cyto_end = $cytobands->{$cyto}->{chr_end};
      my $cyto_name = $cytobands->{$cyto}->{name};
      my $match_found = 0;
      #If either end of the input range is within the cytoband, or it flanks the cytoband completely, consider it a match
      if ($chr_start >= $cyto_start && $chr_start <= $cyto_end){$match_found = 1;}
      if ($chr_end >= $cyto_start && $chr_end <= $cyto_end){$match_found = 1;}
      if ($chr_start <= $cyto_start && $chr_end >= $cyto_end){$match_found = 1;}
      if ($match_found){
        $m++;
        $matches{$m}{cytoband} = $cyto;
      }
    }
    my $match_count = keys %matches;
    if ($match_count == 1){
      $cytoband_string = $matches{1}{cytoband};
    }elsif($match_count > 1){
      $cytoband_string = $matches{1}{cytoband}." - ".$matches{$match_count}{cytoband};
    }
  }else{
    $cytoband_string = "NA";
  }

  return($cytoband_string);
}


#############################################################################################################################
#Get column position                                                                                                        #
#############################################################################################################################
sub getColumnPosition{
  my %args = @_;
  my $path = $args{'-path'};
  my $colname = $args{'-column_name'};
  my $desired_column_position;

  #Get the header line from a file, determine the position (0 based) of the requested column name
  open (IN, "$path") || die "\n\nCould not open input file: $path\n\n";
  my $line = <IN>;
  close (IN);

  chomp($line);
  my @header = split("\t", $line);
  my %columns;
  my $p = 0;
  foreach my $col (@header){
    $columns{$col}{position} = $p;
    $p++;
  }

  if (defined($columns{$colname})){
    $desired_column_position = $columns{$colname}{position};
  }else{
    print RED, "\n\n&getColumnPosition - The requested column name ($colname) was not found in the specified file ($path)\n\n", RESET;
    exit();
  }

  return($desired_column_position);
}


#############################################################################################################################
#Given a file name or path, return the path with the extension removed as well as the extension as a hash                   #
#############################################################################################################################
sub getFilePathBase{
  my %args = @_;
  my $path = $args{'-path'};

  my %fb;

  my ($base, $extension, $base_dir, $file_name, $file_base);

  if ($path =~ /(.*)(\.\w+)$/){
    $base = $1;      #Full path without extension
    $extension = $2; #Extension only
  }else{
    print RED, "\n\n&getFileBasePath could not determine base and extension of a file path: $path\n\n", RESET;
    exit();
  }
  if ($path =~ /(.*)\/(.*)$/){
    $base_dir = "$1"."/"; #Full directory path
    $file_name = $2;      #Full file name
  }else{
    print RED, "\n\n&getFileBasePath could not determine base_dir and file_name of a file path: $path\n\n", RESET;
    exit();
  }
  if ($file_name =~ /(.*)(\.\w+)$/){
    $file_base = $1;      #File name only without extension
  }else{
    print RED, "\n\n&getFileBasePath could not determine file base from file_name: $file_name\n\n", RESET;
    exit();
  }

  $fb{$path}{base} = $base;            #Full path without extension
  $fb{$path}{extension} = $extension;  #Extension only
  $fb{$path}{base_dir} = $base_dir;    #Full directory path with out filename
  $fb{$path}{file_name} = $file_name;  #Full file name without path
  $fb{$path}{file_base} = $file_base;

  return(\%fb);
}


1;

