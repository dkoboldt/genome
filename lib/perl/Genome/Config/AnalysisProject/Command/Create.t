#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_NO_REQUIRE_USER_VERIFY} = 1;
};

use Test::More;

use above 'Genome';

use_ok('Genome::Config::AnalysisProject::Command::Create');

my $cmd = Genome::Config::AnalysisProject::Command::Create->create(
    name => 'test proj',
    environment => 'production',
);
ok($cmd, 'constructed create command');
isa_ok($cmd, 'Genome::Config::AnalysisProject::Command::Create');
my $res = $cmd->execute;
ok($res, 'command executed successfully');
isa_ok($res, 'Genome::Config::AnalysisProject', 'command returned a Genome::Config::AnalysisProject');

ok(UR::Context->commit, 'created objects can be committed');

done_testing();
