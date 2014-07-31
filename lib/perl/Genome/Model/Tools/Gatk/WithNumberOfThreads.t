#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 1;

use_ok('Genome::Model::Tools::Gatk::WithNumberOfThreads');

done_testing();