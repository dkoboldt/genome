#!/usr/bin/env perl

use above 'Genome';
use Test::More;

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

my $pkg = "Genome::File::TypedReader";

use_ok($pkg);

my $text = <<EOF
Line 1
Line 2
Line 3
Line 4
EOF
;

subtest "putback" => sub {
    my $fh = new IO::String($text);
    my $obj = Genome::File::TypedReader::Test->fhopen($fh);

    my $line = $obj->_getline;
    is($line, "Line 1\n", "line 1");
    is(1, $obj->{line_number});


    for (1..5) {
        $line = $obj->_getline;
        is($line, "Line 2\n", "line 2 putback");
        is(2, $obj->{line_number});
        $obj->putback;
    }

    ok($obj->{_have_putback}, "have putback wtf");
    eval {
        $obj->putback;
    };
    ok($@, "calling putback twice in a row is an error");

    $line = $obj->_getline;
    is($line, "Line 2\n");
    is(2, $obj->{line_number});

    $line = $obj->_getline;
    is($line, "Line 3\n");
    is(3, $obj->{line_number});

    $line = $obj->_getline;
    is($line, "Line 4\n");
    is(4, $obj->{line_number});

    ok(!$obj->_getline, 'eof');
};

done_testing();

package Genome::File::TypedReader::Test;

use base qw(Genome::File::TypedReader);

sub _parse_header {
    my $self = shift;
    $self->{header} = 1;
}

sub _next_entry {
    my $self = shift;
    return $self->getline;
}

1;