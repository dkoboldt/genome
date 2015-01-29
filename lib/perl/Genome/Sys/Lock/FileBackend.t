#!/usr/bin/env genome-perl

# Testing a theory about LSF state latency.
sleep 5;

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
};

use above 'Genome';
use Carp qw(croak);
use Data::Dumper;
use File::Path;
use File::Slurp;
use File::Spec;
use File::Temp;
use IO::Handle qw();
use MIME::Base64;
use POSIX ":sys_wait_h";
use Socket qw(AF_UNIX SOCK_STREAM PF_UNSPEC);
use Test::More;
use Time::HiRes qw(gettimeofday);

require_ok('Genome::Sys::Lock::FileBackend');

my $tmp_dir = File::Temp::tempdir('Genome-Utility-FileSystem-writetest-XXXXX', CLEANUP => 1, TMPDIR => 1);
my $TEST_LOCK_DIR = $tmp_dir;

my $bogus_id = 'bogus-lock-55555';
$tmp_dir = File::Temp::tempdir(CLEANUP => 1);
my $sub_dir = $tmp_dir .'/sub/dir/test';
ok(! -e $sub_dir,$sub_dir .' does not exist');
ok(Genome::Sys->create_directory($sub_dir),'create directory');
ok(-d $sub_dir,$sub_dir .' is a directory');

my $BACKEND = Genome::Sys::Lock::FileBackend->new(
        is_mandatory => 1, parent_dir => $TEST_LOCK_DIR);


# Test basic contention
test_locking($BACKEND,
    successful => 1,
    message => 'lock resource_lock '. $bogus_id,
    resource_lock => $bogus_id,
    wait_announce_interval => 10,
    max_try => 1,
    block_sleep => 3,);

ok(-l $TEST_LOCK_DIR . '/' . $bogus_id, 'Symlink created');

test_locking_forked(Genome::Sys::Lock::FileBackend->new(
        is_mandatory => 1, parent_dir => $TEST_LOCK_DIR),
    successful => 0,
    message => 'failed lock resource_lock '. $bogus_id,
    resource_lock => $bogus_id,
    wait_announce_interval => 10,
    max_try => 1,
    block_sleep => 3,);

ok($BACKEND->unlock(
        resource_lock => $bogus_id,
    ), 'unlock resource_lock '. $bogus_id);

ok(!-l $TEST_LOCK_DIR . '/' . $bogus_id, 'Symlink removed');



# Test release_all
test_locking($BACKEND,
    successful => 1,
    message => 'lock resource_lock '. $bogus_id,
    resource_lock => $bogus_id,
    wait_announce_interval => 10,
    max_try => 1,
    block_sleep => 3,);

ok(-l $TEST_LOCK_DIR . '/' . $bogus_id, 'Symlink created');

$BACKEND->release_all();

ok(!-l $TEST_LOCK_DIR . '/' . $bogus_id, 'Symlink removed by release_all');

my $init_lsf_job_id = $ENV{'LSB_JOBID'};

{
    local $ENV{'LSB_JOBID'};
    $ENV{'LSB_JOBID'} = 1;
    my $lock = $BACKEND->lock(
        resource_lock => $bogus_id,
        wait_announce_interval => 10,
        max_try => 1,
        block_sleep => 3,
    );
    ok($lock, 'lock resource with bogus lsf_job_id');

    $lock = fork_to_lock(
        resource_lock => $bogus_id,
        wait_announce_interval => 10,
        max_try => 1,
        block_sleep => 3,
    );
    ok($lock, 'lock resource with removing invalid lock with bogus lsf_job_id first');

# TODO: add skip test but if we are on a blade, lets see that the locking works correctly
# Above the test is that old bogus locks can get removed when the lsf_job_id no longer exists
# We should test that while an lsf_job_id does exist (ie. our current job) we still hold the lock
    SKIP: {
        skip 'only test the state of the lsf job if we are running on a blade with a job id',
        3 unless ($init_lsf_job_id);
        $ENV{'LSB_JOBID'} = $init_lsf_job_id;
        ok($BACKEND->lock(
                resource_lock => $bogus_id,
                wait_announce_interval => 10,
                max_try => 1,
                block_sleep => 3,
            ),'lock resource with real lsf_job_id');

        ok(!fork_to_lock(
                resource_lock => $bogus_id,
                wait_announce_interval => 10,
                max_try => 1,
                block_sleep => 3,
            ),'failed lock resource with real lsf_job_id blocking');

        ok($BACKEND->unlock(
                resource_lock => $bogus_id,
            ), 'unlock resource_lock '. $bogus_id);
    };
}

# RACE CONDITION
my $base_dir = File::Temp::tempdir("Genome-Utility-FileSystem-RaceCondition-XXXX", CLEANUP=>1, TMPDIR => 1);

my $resource = "/tmp/Genome-Utility-Filesystem.test.resource.$$";

if (defined $ENV{'LSB_JOBID'} && $ENV{'LSB_JOBID'} eq "1") {
    delete $ENV{'LSB_JOBID'}; 
}

my @pids;

my $children = 20;

for my $child (1...$children) {
    my $pid;
    if ($pid = UR::Context::Process->fork()) {
        push @pids, $pid;
    } else {
        my $output_offset = $child;
        my $tempdir = $base_dir;
        my $output_file = $tempdir . "/" . $output_offset;

        my $fh = new IO::File(">>$output_file");

        my $lock_hold_time = 2;
        my $block_sleep = 1;
        my $max_try = 2 * int($lock_hold_time / $block_sleep + 1) * $children;
        my $wait_announce_interval = 2* $children * $lock_hold_time;
        my $lock = $BACKEND->lock(
            resource_lock => $resource,
            block_sleep   => $block_sleep,
            max_try       => $max_try,
            wait_announce_interval => $wait_announce_interval,
        );
        unless ($lock) {
            print_event($fh, "LOCK_FAIL", "Failed to get a lock" );
            $fh->close;
            exit(1);
        }

        #sleep for half a second before printing this, to let a prior process catch up with
        #printing its "unlocked" message.  sometimes we get a lock (properly) in between the time
        #someone else has given up the lock, but before it had a chance to report that it did.
        select(undef, undef, undef, 0.50);
        print_event($fh, "LOCK_SUCCESS", "Successfully got a lock" );
        sleep $lock_hold_time;

        unless ($BACKEND->unlock(resource_lock => $resource)) {
            print_event($fh, "UNLOCK_FAIL", "Failed to release a lock" );
            $fh->close;
            exit(1);
        }
        print_event($fh, "UNLOCK_SUCCESS", "Successfully released my lock" );

        $fh->close;
        exit(0);
    }
}

for my $pid (@pids) {
    my $status = waitpid $pid, 0;
}

my @event_log;

for my $child (1...$children) {
    my $report_log = "$base_dir/$child";
    ok (-e $report_log, "Expected to see a report for $report_log");
    if (!-e $report_log) {
        die "Expected output file did not exist";
    } else {
        my @lines = read_file($report_log);
        for (@lines) {
            my ($time, $event, $pid, $msg) = split /\t/;
            my $report = {etime => $time, event=>$event, pid=>$pid, msg=>$msg};
            push @event_log, $report;
        } 
    }
}

ok(scalar @event_log  == 2*$children, "read in got 2 lock/unlock events for each child.");

@event_log = sort {$a->{etime} <=> $b->{etime}} @event_log;
my $last_event;
for (@event_log) {
    if (defined $last_event) {
        my $valid_next_event = ($last_event eq "UNLOCK_SUCCESS" ? "LOCK_SUCCESS" : "UNLOCK_SUCCESS");
        ok($_->{event} eq $valid_next_event, sprintf("Last lock event was a %s so we expected a to see %s, got a %s", $last_event, $valid_next_event, $_->{event}));
    }
    $last_event = $_->{event};
    printf("%s\t%s\t%s\n", $_->{etime}, $_->{pid}, $_->{event});
}

done_testing();

###

sub test_locking {
    my $backend = shift;
    my %params = @_;

    my $successful = delete $params{successful};
    die unless defined($successful);
    my $message = delete $params{message};
    die unless defined($message);


    my $lock = $backend->lock(%params);
    if ($successful) {
        ok($lock,$message);
    } else {
        ok(!$lock,$message);
    }

    return;
}

sub print_event {
    my $fh = shift;
    my $info = shift;
    my $msg  = shift;

    my ( $seconds, $ms ) = gettimeofday();
    $ms = sprintf("%06d",$ms);
    my $time = "$seconds.$ms";

    my $tp = sprintf( "%s\t%s\t%s\t%s", $time, $info, $$, $msg );

    print $fh $tp, "\n";
    print $tp, "\n";
}

sub test_locking_forked {
    my $backend = shift;
    my %params = @_;

    my $successful = delete $params{successful};
    die unless defined($successful);
    my $message = delete $params{message};
    die unless defined($message);

    my $lock = fork_to_lock(%params);
    if ($successful) {
        ok($lock,$message);
        if ($lock) { return $lock; }
    } else {
        ok(!$lock,$message);
    }
    return;
}

sub fork_to_lock {
    my %args = @_;

    socketpair(my $CHILD, my $PARENT, AF_UNIX, SOCK_STREAM, PF_UNSPEC)
        or die "socketpair: $!";

    $CHILD->autoflush(1);
    $PARENT->autoflush(1);

    my $pid = UR::Context::Process->fork();
    if ($pid) {
        close $PARENT;
        waitfor($CHILD, 'READY');
        $CHILD->say('LOCK');
        my $lock = getline($CHILD);
        $CHILD->say('ACK');

        close $CHILD;
        waitpid($pid, 0);

        return $lock;
    } else {
        close $CHILD;
        my $backend = Genome::Sys::Lock::FileBackend->new(
            is_mandatory => 1, parent_dir => $TEST_LOCK_DIR);
        $PARENT->say('READY');

        waitfor($PARENT, 'LOCK');
        my $lock = $backend->lock(%args);
        $PARENT->say($lock);

        waitfor($PARENT, 'ACK');
        if ($lock) {
            $backend->unlock(resource_lock => $lock);
        }
        close $PARENT;
        exit(0);
    }
}

sub getline {
    my $handle = shift;
    unless ($handle) {
        croak('handle required');
    }
    my $line = <$handle>;
    if ($line) {
        chomp $line;
    }
    return $line;
}

sub waitfor {
    my ($handle, $message) = @_;
    unless ($handle) {
        croak('handle required');
    }
    unless (defined $message) {
        croak('message required');
    }
    my $line = getline($handle);
    unless ($line) {
        croak("empty message");
    }
    unless ($line eq $message) {
        croak("unexpected message: $line");
    }
    return 1;
}

