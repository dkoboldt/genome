package Genome::Model::GenotypeMicroarray::GenotypeFile::ReaderForInstDataWithAnnotation;

use strict;
use warnings;

use parent 'Genome::Model::GenotypeMicroarray::GenotypeFile::ReaderForInstData';

use Genome::File::Vcf::Reader;
require List::MoreUtils;
use Regexp::Common;

sub header {
    my ($self, $header) = @_;

    if ( $header ) {
        $self->{_vcf_reader}->header($header);
    }

    return $self->{_vcf_reader}->header;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my $open_vcf_reader = $self->_open_vcf_reader;
    return if not $open_vcf_reader;

    my $load_genotypes = $self->_load_genotypes;
    return if not $load_genotypes;

    my $annotate_genotypes = $self->_annotate_genotypes;
    return if not $annotate_genotypes;

    return $self;
}

sub read {
    my $self = shift;

    while ( my $variant_id = shift @{$self->{_order}} ) {
        my $entry = $self->_create_vcf_entry( $self->{_genotypes}->{$variant_id} );
        return $entry if $entry;
    }

    return;
}

sub _create_vcf_entry {
    my ($self, $genotype) = @_;

    my $entry = Genome::File::Vcf::Entry->new($self->header, $genotype->{line});

    # Skip INDELs
    return if $entry->has_indel;

    # Add alleles
    $self->_add_alleles_to_entry($genotype, $entry);

    # Add GT to genotype
    $genotype->{genotype} = $self->_gt_for_alleles($entry, map { $genotype->{$_} } (qw/ allele1 allele2 /) );

    # Add genotype data to entry
    for my $field ( Genome::Model::GenotypeMicroarray->format_types ) {
        $entry->add_format_field($field->{id});
        my $value = $genotype->{ $field->{name} };
        $value = '.' if not defined $value or $value eq '';
        $entry->set_sample_field(0, $field->{id}, $value);
    }

    return $entry;
}

sub _open_vcf_reader {
    my $self = shift;

    my $variation_list_build = $self->variation_list_build;
    my $snvs_vcf = $variation_list_build->snvs_vcf;
    if ( not $snvs_vcf or not -s $snvs_vcf ) {
        $self->error_message('No SNVs VCF for variation list  build! '.$variation_list_build->__display_name__);
        return;
    }

    my $vcf_reader = eval{ Genome::File::Vcf::Reader->new($snvs_vcf); };
    if ( not $vcf_reader ) {
        $self->error_message("Failed to open SNVs VCF file! $snvs_vcf");
        return;
    }
    $self->{_vcf_reader} = $vcf_reader;

    return 1;
}

sub _load_genotype {
    my $self = shift;

    my $genotype = $self->SUPER::read;
    return if not $genotype;

    # Rm chr
    delete $genotype->{'chr'};
    # Set alleles
    $genotype->{alleles} = $genotype->{allele1}.$genotype->{allele2};
    # Clean up values that should only be numbers
    for my $attr (qw/ gc_score log_r_ratio cnv_value cnv_confidence /) {
        next if not defined $genotype->{$attr} or $genotype->{$attr} eq '';
        next if $genotype->{$attr} !~ /($RE{num}{real})/;
        $genotype->{$attr} = $1;
    }

    $self->{_genotypes}->{ $genotype->{id} } = $genotype;

    return $genotype;
}

sub _load_genotypes {
    my $self = shift;

    my $genotypes = $self->{_genotypes};
    my $genotype;
    do {
        $genotype = $self->_load_genotype;
    } while $genotype;

    if ( not %{$self->{_genotypes}} ) {
        $self->error_message("No genotypes found in genotype file! ".$self->get_original_input);
        return;
    }

    return 1;
}

sub _annotate_genotypes {
    my $self = shift;

    my $genotypes = $self->{_genotypes};
    Carp::confess('No genotypes!') if not $genotypes or not %$genotypes;

    my $vcf_reader = $self->{_vcf_reader};
    my $cnt = 0;
    while ( my $line = $vcf_reader->_getline ) {
        my ($variant_id) = split(',', (split(/\t/, $line))[2]);

        # Skip if not in variation list
        next if not $genotypes->{$variant_id};

        if ( exists $genotypes->{$variant_id}->{order} ) {
            # remove if seen
            delete $genotypes->{$variant_id};
            next;
        }

        # set order
        $genotypes->{$variant_id}->{order} = ++$cnt;

        # Save line to create vcf entry
        chomp $line;
        $genotypes->{$variant_id}->{line} = $line;
    }

    my @order = map { $_->{id} } sort { $a->{order} <=> $b->{order} } grep { exists $_->{order} } values %$genotypes;
    $self->{_order} = \@order;
    if ( not @order ) {
        $self->error_message("All genotypes are duplicates in variant list! ".$vcf_reader->{name});
        return;
    }

    return 1;
}

sub _add_alleles_to_entry {
    my ($self, $genotype, $entry) = @_;
    
    for my $allele ( map { $genotype->{$_} } (qw/ allele1 allele2 /) ) { 
        next unless List::MoreUtils::any { $allele eq $_ } (qw/ A C G T /);
        $entry->add_allele($allele);
    }

    return 1;
}

sub _gt_for_alleles {
    my ($self, $entry, @alleles) = @_;

    my %alleles_idx = (
        '-' => '.',
    );
    my @entry_alleles = $entry->alleles;
    @alleles_idx{ @entry_alleles } = ( 0..@entry_alleles );

    my @gt_idx;
    for my $allele ( @alleles ) {
        push @gt_idx, $alleles_idx{$allele};
    }

    return join('/', @gt_idx);
}

1;

