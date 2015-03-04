package Genome::Model::Tools::Analysis::XTen::ApSummary;

#####################################################################################################################################
# SearchRuns - Search the database for runs
#
#    AUTHOR:        Dan Koboldt (dkoboldt@watson.wustl.edu)
#
#    CREATED:    04/01/2009 by D.K.
#    MODIFIED:    04/01/2009 by D.K.
#
#    NOTES:
#
#####################################################################################################################################

use strict;
use warnings;

use FileHandle;

use Genome;

class Genome::Model::Tools::Analysis::XTen::ApSummary{
    is => 'Command',

    #TODO: Use class pre-processor to sync the result class and the command class
    has_param => [
        verbose       => { is => 'Text', doc => "Turns on verbose output [0]", is_optional => 1},
    ],

    has_input => [
        analysis_project   => { is => 'Text', doc => "Analysis project ID", is_optional => 0 },
        output_file     => { is => 'Text', doc => "Output file for report", is_optional => 0 },
    ],

};

sub output_columns {
    return qw/
    Model
    Build
    /;
}

sub execute {
    my $self = shift;
    my $analysis_project = $self->analysis_project;
    my $output_file = $self->output_file;

    print "Processing analysis project $analysis_project...\n";

    return 1;
}



1;
