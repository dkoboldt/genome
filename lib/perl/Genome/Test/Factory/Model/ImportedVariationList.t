#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok("Genome::Test::Factory::Model::ImportedVariationList");

my $m = Genome::Test::Factory::Model::ImportedVariationList->setup_object();
ok($m->isa("Genome::Model::ImportedVariationList"), "Generated an imported variation list model");

done_testing;

