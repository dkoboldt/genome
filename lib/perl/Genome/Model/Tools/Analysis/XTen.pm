package Genome::Model::Tools::Analysis::XTen;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Analysis::XTen {
    is => ['Genome::Model::Tools::Analysis'],
};

sub help_brief {
    "Tools for QC-checks of Illumina HiSeq X Ten.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt analysis x-ten --help ...
EOS
}

1;

