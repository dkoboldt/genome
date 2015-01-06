#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above 'Genome';

require Genome::Utility::Test;
use Test::More;

my $class = 'Genome::InstrumentData::Command::RefineReads::GatkBestPractices';
use_ok($class) or die;

# Inputs
use_ok('Genome::InstrumentData::Gatk::Test') or die;
my $gatk_test = Genome::InstrumentData::Gatk::Test->get;
my $bam_source = $gatk_test->bam_source;
my $reference_build = $gatk_test->reference_build;
my %params = (
    version => 2.4,
    bam_source => $bam_source,
    known_sites => [$gatk_test->known_site],
);

# Shortcut [fails as expected]
my $gatk_best_practices = Genome::InstrumentData::Command::RefineReads::GatkBestPractices->create(%params);
ok($gatk_best_practices, 'create');
ok(!$gatk_best_practices->shortcut, 'shortcut failed as expected');

# Execute
ok($gatk_best_practices->execute, 'execute');
my @results = $gatk_best_practices->results;
my $indel_realigner_result = $results[0];
isa_ok($indel_realigner_result, 'Genome::InstrumentData::Gatk::IndelRealignerResult');
my $base_recalibrator_bam_result = $results[1];
isa_ok($base_recalibrator_bam_result, 'Genome::InstrumentData::Gatk::BaseRecalibratorBamResult');
my $base_recalibrator_result = $base_recalibrator_bam_result->base_recalibrator_result;
ok($base_recalibrator_result, 'get base_recalibrator_result');

# Users
my @sr_users = $bam_source->users;
is(@sr_users, 1, 'add user to bam source');
is_deeply([map { $_->label } @sr_users], ['bam source'], 'bam source users haver correct label');
is_deeply([map { $_->user } @sr_users], [$indel_realigner_result], 'bam source is used by indel realigner result');

@sr_users = $indel_realigner_result->users;
is(@sr_users, 2, 'add users to indel realigner');
is_deeply([map { $_->label } @sr_users], ['bam source', 'bam source'], 'indel realigner users haver correct label');
my @users = sort { $a->id cmp $b->id } map { $_->user } @sr_users;
my @expected_users = sort { $a->id cmp $b->id } ($base_recalibrator_result, $base_recalibrator_bam_result);
is_deeply(\@users, \@expected_users, 'indel realigner is used by base recal and base recal bam results');

@sr_users = $base_recalibrator_result->users;
is(@sr_users, 1, 'add user to base recal result');
is_deeply([map { $_->label } @sr_users], ['recalibration table'], 'base recal result users haver correct label');
is_deeply([map { $_->user } @sr_users], [$base_recalibrator_bam_result], 'base recal is used by base recal bam result');

@sr_users = $base_recalibrator_bam_result->users;
ok(!@sr_users, 'no users for base recal bam result');

# Shortcut, again
my $gatk_best_practices_shortcut = Genome::InstrumentData::Command::RefineReads::GatkBestPractices->create(%params);
ok($gatk_best_practices_shortcut, 'create');
ok($gatk_best_practices_shortcut->shortcut, 'shortcut');
my @shortcut_results = $gatk_best_practices_shortcut->results;
is_deeply(\@shortcut_results, \@results, 'shortcut and execute results match');

#print $indel_realigner_result->output_dir."\n"; <STDIN>;
#print $base_recalibrator->output_dir."\n"; <STDIN>;
done_testing();
