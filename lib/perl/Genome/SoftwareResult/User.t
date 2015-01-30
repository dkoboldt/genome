#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';
use Test::More;
use Test::Exception;
use Genome::Test::Factory::Build;
use Genome::Test::Factory::Model::ReferenceAlignment;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

class SR_Test {
    is => 'Genome::SoftwareResult',
    has_param => {
        p1 => { is => 'Text' },
    },
};

sub _newly_created_callback {
    return (SR_Test->__define__(p1 => 'turkey'), 1);
}

sub _shortcut_callback {
    return SR_Test->__define__(p1 => 'turkey');
}

my $class = 'Genome::SoftwareResult::User';
use_ok($class);

my $run_as = 'apipe-builder';
my $requestor_model = Genome::Test::Factory::Model::ReferenceAlignment->setup_object(run_as => $run_as);
my $requestor_build = Genome::Test::Factory::Build->setup_object(model_id => $requestor_model->id);
my $sponsor_user = Genome::Sys->current_user();

my %users_hash = (
    users => {
        sponsor => $sponsor_user,
        requestor => $requestor_build,
    }
);

throws_ok { $class->with_registered_users(callback => \&_newly_created_callback) }
    qr/Mandatory parameter 'users' missing/,
    'validates that user hashref is present';

throws_ok { $class->with_registered_users(%users_hash) }
    qr/Mandatory parameter 'callback' missing/,
    'vaidates that callback is present';

throws_ok { $class->with_registered_users(users => {}) }
    qr/must contain sponsor and requestor/,
    'validates that user hashref contains both a sponsor and a requestor';

throws_ok { $class->with_registered_users(users => {sponsor => 1, requestor => 2}) }
    qr/must contain sponsor and requestor/,
    'validates that sponsor and requestor are of valid types';

throws_ok { $class->with_registered_users(callback => 1) }
    qr/allowed types: coderef/,
    'validates that callback is a coderef';

my $new_sr = $class->with_registered_users(
            callback => \&_newly_created_callback,
            %users_hash
        );

is(
    $new_sr->users(label => 'created')->user,
    $requestor_build,
    'new software result gets created label'
);

my %extra_users = %{$users_hash{users}};
$extra_users{arbitrary_label} = $new_sr;
my $shortcut_sr = $class->with_registered_users(
            callback => \&_shortcut_callback,
            users => \%extra_users,
        );

is(
    $shortcut_sr->users(label => 'shortcut')->user,
    $requestor_build,
    'existing software result gets shortcut label'
);

is(
    $shortcut_sr->users(label => 'arbitrary_label')->user,
    $new_sr,
    'stapling in extra arbitrary users works'
);

for my $sr ($new_sr, $shortcut_sr) {
    is(
        $sr->users(label => 'sponsor')->user,
        $sponsor_user,
        'correctly registers sponsor'
    );
}

my @users_before_additional_call = $new_sr->users;
$class->with_registered_users(
    callback => sub { return ($new_sr, 1); },
    %users_hash,
);
my @users_after_additional_call = $new_sr->users;

is(
    scalar(@users_before_additional_call),
    scalar(@users_after_additional_call),
    'it will not staple on duplicate users',
);

subtest 'user_hash_for_build produces expected results' => sub {
    plan tests => 4;

    my $user_hash1 = Genome::SoftwareResult::User->user_hash_for_build($requestor_build);
    is($user_hash1->{requestor}, $requestor_build, 'set requestor for build without an analysis project');
    is($user_hash1->{sponsor}->username, $run_as, 'set sponsor for build without an analysis project');

    my $test_anp = Genome::Config::AnalysisProject->__define__(name => 'test project for G:SR:User test');
    Genome::Config::AnalysisProject::ModelBridge->create(analysis_project => $test_anp, model => $requestor_model);
    my $user_hash2 = Genome::SoftwareResult::User->user_hash_for_build($requestor_build);
    is($user_hash2->{requestor}, $requestor_build, 'set requestor for build with an analysis project');
    is($user_hash2->{sponsor}, $test_anp, 'set sponsor for build with an analysis project');
};

done_testing();
