#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::Notable::Command::ViewNotes') or die "Class not found!";

# Set up test objects, classes, and all that jazz.
class Genome::NotableTest {
    is => 'Genome::Notable',
};

class Genome::Notable::Test::Command::ViewNotes {
    is => 'Genome::Notable::Command::ViewNotes',
    has => [
        notables => {
            is => 'Genome::NotableTest',
            is_many => 1,
        }
    ],
};

my $meta = Genome::NotableTest->__meta__;
ok($meta, 'Got meta object for test class Genome::NotableTest') or die;

my $test_object = Genome::NotableTest->create();
ok($test_object, 'Created object of type Genome::NotableTest') or die;

my $add_rv = $test_object->add_note(
    header_text => 'Test note'
);
ok($add_rv, 'Successfully added a note to object') or die;

my @notes = $test_object->notes;
ok(@notes == 1, 'Successfully retrieved note from object') or die;

# Create first command and test output (no filtering)
my $cmd1 = Genome::Notable::Test::Command::ViewNotes->create(
    notables => [$test_object]
);
ok($cmd1, 'Successfully created view notes command object') or die;

my $cmd1_rv = $cmd1->execute;
ok($cmd1_rv, 'Successfully executed command');

my @cmd1_notes = $cmd1->_notes;
ok(@cmd1_notes == @notes, 'Command found expected number of notes on test object');

@notes = sort { $a->id <=> $b->id } @notes;
@cmd1_notes = sort { $a->id <=> $b->id } @cmd1_notes;

for (my $i = 0; $i < @cmd1_notes; $i++) {
    my $cmd_note = $cmd1_notes[$i];
    my $note = $notes[$i];
    ok($note->id eq $cmd_note->id, 'Note found by command has same id as expected note');
}

# Create second command and test output (with filtering)
my $cmd2 = Genome::Notable::Test::Command::ViewNotes->create(
    notables => [$test_object],
    note_type => 'does not match',
);
ok($cmd2, 'Successfully created view notes command object') or die;

my $cmd2_rv = $cmd2->execute;
ok($cmd2_rv, 'Successfully executed command');

my @cmd2_notes = $cmd2->_notes;
ok(@cmd2_notes == 0, 'Command found no notes with given header text, as expected');

done_testing();
