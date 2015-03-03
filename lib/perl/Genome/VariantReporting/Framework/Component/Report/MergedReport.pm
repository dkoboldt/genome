package Genome::VariantReporting::Framework::Component::Report::MergedReport;

use strict;
use warnings;
use Genome;
use List::Util qw(first);
use List::MoreUtils qw(firstidx);
use Set::Scalar;
use Memoize;
use Params::Validate qw(validate_pos :types);
use JSON qw(from_json);

our $REPORT_PKG = 'Genome::VariantReporting::Framework::Component::Report::SingleFile';

class Genome::VariantReporting::Framework::Component::Report::MergedReport {
    is => [
        'Genome::VariantReporting::Framework::Component::Report::MergeCompatible',
    ],
    has_input => [
        base_report => {
            is => 'Genome::VariantReporting::Framework::Component::Report::MergeCompatible',
            doc => 'The main report to be merged.'
        },
        supplemental_report => {
            is => 'Genome::VariantReporting::Framework::Component::Report::MergeCompatible',
            doc => 'The report that is to be added to the main report.'
        },
    ],
    has_param => [
        sort_columns => {
            is_optional => 1,
            is => 'Text',
            is_many => 1,
        },
        contains_header => {
            is => 'Boolean',
        },
        separator => {
            is => 'Text',
        },
        base_report_source => {
            is => 'Text',
            is_optional => 1,
        },
        supplemental_report_source => {
            is => 'Text',
            is_optional => 1,
        },
    ],
};

sub _run {
    my $self = shift;

    if (!$self->base_report->has_size && !$self->supplemental_report->has_size) {
        #Create an empty output file
        Genome::Sys->touch($self->_temp_output_file);
        return 1;
    }

    $self->validate;

    $self->merge_legend_files();

    my $merged_file = $self->merge_files;

    my $sorted_file = $self->sort_file($merged_file);

    $self->move_file_to_output($sorted_file);
    return 1;
}

sub report_results {
    my $self = shift;
    return ($self->base_report, $self->supplemental_report);
}

sub move_file_to_output {
    my $self = shift;
    my $file = shift;
    Genome::Sys->move_file(
        $file, $self->_temp_output_file
    );
}

sub merge_legend_files {
    my $self = shift;

    my @legend_paths = $self->_get_input_report_legend_paths();
    return unless(@legend_paths);

    my $headers;
    my $all_filters = Set::Scalar->new();
    for my $legend_path (@legend_paths) {
        ($headers, my $filters) = _get_headers_and_filters($legend_path);
        $all_filters = $all_filters + $filters;
    }

    my @lines = (
        'Headers',
        @$headers,
        'Filters',
        sort $all_filters->members(),
    );

    my $output_path = File::Spec->join($self->temp_staging_directory,
            $self->legend_file_name);
    my $fh = Genome::Sys->open_file_for_writing($output_path);
    $fh->write(join("\n", @lines));
    $fh->close();
    return $output_path;
}

sub _get_input_report_legend_paths {
    my $self = shift;

    my @legends;
    for my $result ($self->report_results) {
        if ($result->can('legend_path') &&
            defined($result->legend_path) &&
            -f $result->legend_path) {
            push @legends, $result->legend_path;
        }
    }
    return @legends;
}

sub _get_headers_and_filters {
    my $legend_path = shift;

    my $fh = Genome::Sys->open_file_for_reading($legend_path);
    my $first_line = $fh->getline();
    unless ($first_line =~ /^Headers/) {
        die sprintf("Legend file (%s) appears to be malformed", $legend_path);
    }

    my @headers;
    my $filters = Set::Scalar->new();
    my $mode = 'headers';
    while (my $line = $fh->getline()) {
        chomp($line);
        if ($line =~ /^Filters/) {
            $mode = 'filters';
            next;
        }

        if ($mode eq 'headers') {
            push @headers, $line;
        } elsif ($mode eq 'filters') {
            $filters->insert($line);
        }
    }
    return \@headers, $filters;
}

sub legend_file_name {
    my $self = shift;
    my $base_report = $self->base_report;
    if ($base_report->can('legend_file_name')) {
        return $base_report->legend_file_name;
    } else {
        return;
    }
}

sub legend_path {
    my $self = shift;

    if (defined($self->legend_file_name)) {
        return File::Spec->join($self->output_dir, $self->legend_file_name);
    } else {
        return;
    }
}

sub merge_files {
    my $self = shift;

    my $merged_file = Genome::Sys->create_temp_file_path;

    for my $report_name ('base_report', 'supplemental_report') {
        my $report = $self->$report_name;
        next unless $report->has_size;
        my $file_to_merge;
        if ($self->contains_header) {
            $file_to_merge = Genome::Sys->create_temp_file_path;
            my $reader = Genome::Utility::IO::SeparatedValueReader->create(
                input => $report->report_path,
                separator => $self->separator,
            );
            my $writer = Genome::Utility::IO::SeparatedValueWriter->create(
                headers => [$self->get_master_header],
                print_headers => 0,
                separator => $self->separator,
                output => $file_to_merge,
            );
            while (my $entry = $reader->next) {
                $writer->write_one($entry);
            }
        } else {
            $file_to_merge = $report->report_path;
        }
        my $report_source_accessor = $report_name . '_source';
        my $report_source = $self->$report_source_accessor;
        my $with_source;
        if ($report_source) {
            $with_source = $self->add_source($report->report_path, $file_to_merge, $report_source);
        }
        else {
            $with_source = $file_to_merge;
        }
        my $merge_command = 'cat %s >> %s';
        Genome::Sys->shellcmd(cmd => sprintf($merge_command, $with_source, $merged_file));
    }
    return $merged_file;
}

sub add_source {
    my ($self, $report, $file, $tag) = @_;
    my $out_file = Genome::Sys->create_temp_file_path;
    my $out = Genome::Sys->open_file_for_writing($out_file);
    my $in = Genome::Sys->open_file_for_reading($file);

    while (my $line = <$in>) {
        chomp $line;
        print $out join($self->separator, $line, $tag)."\n";
    }
    $in->close;
    $out->close;
    return $out_file;
}

# Sort the file if required. Regardless, put the header in place.
sub sort_file {
    my ($self, $merged_file) = @_;

    my $sorted_file = Genome::Sys->create_temp_file_path;
    if ($self->has_sort_columns) {
        my $fh = Genome::Sys->open_file_for_writing($sorted_file);
        $self->print_header_to_fh($fh);
        Genome::Sys->shellcmd(cmd => sprintf('sort %s %s >> %s', $self->get_sort_params, $merged_file, $sorted_file));
    } else {
        my ($fh, $header_file) = Genome::Sys->create_temp_file;
        $self->print_header_to_fh($fh);
        Genome::Sys->concatenate_files( [$header_file, $merged_file], $sorted_file );
    }
    return $sorted_file;
}

sub print_header_to_fh {
    my ($self, $fh) = @_;
    if ($self->contains_header) {
        $fh->print( join($self->separator, $self->get_master_header_with_source) . "\n");
    }
    $fh->close;
}

sub _temp_output_file {
    my $self = shift;
    return File::Spec->join($self->temp_staging_directory, $self->file_name);
}

sub report_path {
    my $self = shift;
    return unless $self->output_dir;
    return File::Spec->join($self->output_dir, $self->file_name);
}

sub can_be_merged {
    return 1;
}

sub merge_parameters {
    my $self = shift;
    return $self->base_report->merge_parameters;
}


sub file_name {
    my $self = shift;
    return $self->base_report->file_name;
}


# Make sure all inputs and outputs are readable. Make sure all headers are the same. Make sure sort_columns are contained in the header (this also ensures they are numeric if they must be).
sub validate {
    my $self = shift;

    Genome::Sys->validate_file_for_reading($self->base_report->report_path);
    Genome::Sys->validate_file_for_reading($self->supplemental_report->report_path);

    my $master_header = Set::Scalar->new($self->get_master_header);
    if ($self->supplemental_report->has_size) {
        my $supplemental_report_header = Set::Scalar->new($self->get_header($self->supplemental_report->report_path));
        unless ($supplemental_report_header->is_equal($master_header)) {
            die $self->error_message("Headers for the reports are not the same. Base report header:\n%s\nSupplemental report header:\n%s", $master_header, $supplemental_report_header);
        }
    }

    my $sort_columns = Set::Scalar->new($self->sort_columns);
    unless($master_header->contains($sort_columns->members)) {
        die $self->error_message('The sort columns (%s) are not contained within the first header (%s)', $sort_columns, $master_header);
    }

    if (defined($self->base_report_source) || defined($self->supplemental_report_source)) {
        unless (defined($self->base_report_source)) {
            die $self->error_message("No entry source for base report: base_report_source needs to be set.");
        }
        unless (defined($self->supplemental_report_source)) {
            die $self->error_message("No entry source for supplemental report: supplemental_report_source needs to be set.");
        }
    }

    return 1;
}

sub get_sort_params {
    my $self = shift;
    return '-V ' . join " ", map { "-k$_" } $self->get_sort_column_numbers;
}

# Return the one-based indices of the columns by which we are sorting.
sub get_sort_column_numbers {
    my $self = shift;
    return unless ($self->has_sort_columns);

    # If the header is provided by name, we have to find the indices
    my @indices;
    if ($self->contains_header) {
        my @header = $self->get_master_header;
        for my $column ($self->sort_columns) {
            my $index = firstidx { $_ eq $column } @header;
            if ($index == -1) {
                die $self->error_message('Failed to find column (%s) in header (%s)', $column, join(",", @header));
            } else {
                push @indices, ($index+1); # We want 1-based numbers for sorting.
            }
        }
    } else {
        @indices = $self->sort_columns;
    }

    if (@indices) {
        return @indices;
    } else {
        die $self->error_message('Failed to get the indices for the sort columns (%s) in the master header (%s)', $self->sort_columns, join(",", $self->get_master_header) );
    }
}

sub get_master_header {
    my $self = shift;

    return $self->get_header($self->base_report->report_path);
}

sub get_master_header_with_source {
    my $self = shift;
    if ($self->has_entry_sources) {
        return ($self->get_master_header, "Source");
    }
    else {
        return $self->get_master_header;
    }
}

# Given a file, return the header. If reports have no header, 
# return an 'anonymous' one with just numbers.
sub get_header {
    my ($self, $file) = @_;

    my $reader = Genome::Utility::IO::SeparatedValueReader->create(
        input => $file,
        separator => $self->separator,
    );

    if ($self->contains_header) {
        return @{$reader->headers};
    } else {
        return ( 1..scalar(@{$reader->headers}) );
    }
}

sub has_entry_sources {
    my $self = shift;
    return (defined($self->base_report_source) && defined($self->supplemental_report_source));
}

sub has_sort_columns {
    my $self = shift;
    my @sort_columns = $self->sort_columns;
    return scalar(@sort_columns);
}

sub category {
    my $self = shift;

    my @report_users = map { $_->users('label like' => 'report:%') } $self->report_results;
    my $category;
    for my $user (@report_users) {
        if ($user->label =~ /report:(.*)/) {
            my $metadata_json = $1;
            my $m = from_json($metadata_json);
            if (!defined($category)) {
                $category = $m->{category};
            }
            elsif ($category ne $m->{category}) {
                die $self->error_message("Categories of unmerged reports (%s) are not the same: (%s), (%s)", join(', ', map { $_->id } @report_users), $category, $m->{category});
            }
        }
    }

    return $category;
}

1;
