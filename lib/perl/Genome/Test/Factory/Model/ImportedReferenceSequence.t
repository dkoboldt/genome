#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::Test::Factory::Model::ImportedReferenceSequence");

my $m = Genome::Test::Factory::Model::ImportedReferenceSequence->setup_object();
ok($m->isa("Genome::Model::ImportedReferenceSequence"), "Generated an imported reference sequence model");

done_testing;

