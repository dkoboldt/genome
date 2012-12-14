#!/usr/bin/env genome-perl
use strict;
use warnings;

# the "above" should only go in tests, and ensures you don't need to use -I
use above "Genome";

# init the test harness, and declare the number of tests we will run
use Test::More;

# this ensures we don't talk to the database just to get new ID values for objects
# it will just use negative numbers instead of real IDs
$ENV{USE_DUMMY_AUTOGENERATED_IDS} = 1;
$ENV{UR_DBI_NO_COMMIT} = 1;

# ensure the module we will test compileis correctly before we start
use_ok("Genome::Model::Build::Command::AbandonAndQueue") or die;

#
# make the test data 
#

my $s = Genome::Sample->create(name => 'TEST-' . __FILE__ . "-$$");
ok($s, "made a test sample");

my $p = Genome::ProcessingProfile::TestPipeline->create(
    name => "test " . __FILE__ . " on host " . Sys::Hostname::hostname . " process $$",
    some_command_name => 'ls',
);
ok($p, "made a test processing profile");

my $m = Genome::Model::TestPipeline->create(
    processing_profile_id => $p->id,
    subject_class_name => ref($s),
    subject_id => $s->id,
    build_requested => 0,
);
ok($m, "made a test model");
ok(!$m->build_requested, 'build is not requested');

my $b1 = $m->add_build();
ok($b1, "made test build 1");

# run the command, and capture the exit code
# this way invokes the command right in this process, with an array of command-line arguments
# to test that we parse correctly
$ENV{GENOME_NO_REQUIRE_USER_VERIFY} = 1;
my $exit_code1 = eval { 
    Genome::Model::Build::Command::AbandonAndQueue->_execute_with_shell_params_and_return_exit_code('--', $b1->id);
};
$ENV{GENOME_NO_REQUIRE_USER_VERIFY} = 0;

# ensure it ran without errors
ok(!$@, "the command did not crash");
is($exit_code1, 0, "command believes it succeeded");

# make sure a build is requested
ok($m->build_requested, 'build is requested');

done_testing();
