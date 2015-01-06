#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Model::Build::SomaticVariationTestGenerator;
use Genome::Test::Factory::Model::SomaticValidation;
use Genome::Test::Factory::Model::ImportedReferenceSequence;
use Genome::Test::Factory::Build;
use Test::MockObject::Extends;

use_ok("Genome::Model::Build::SomaticVariation");

my ($b, $m) = Genome::Model::Build::SomaticVariationTestGenerator::setup_test_build();
ok($m, "Created SomaticVariation model");
ok($b, "Created SomaticVariation build");

test_build_inputs_dont_reference_model();
test_annotation_build_accessor();
test_get_feature_list_from_reference();
done_testing();

# these tests may seem obvious, but the build USED to reference model inputs directly.
sub test_build_inputs_dont_reference_model {
    is($b->previously_discovered_variations_build->id,
            $m->previously_discovered_variations_build->id,
            'Build has previously_discovered_variations_build from model');

    my $pdv_build = $m->previously_discovered_variations;
    my $pdv_build_2 = Genome::Test::Factory::Build->setup_object(model_id => $m->id);

    # change a model input
    $m->previously_discovered_variations($pdv_build_2);
    is($m->previously_discovered_variations_build->id,
            $pdv_build_2->id, "Updated model input");

    # check to make sure the old build's input is the same
    is($b->previously_discovered_variations_build->id,
            $pdv_build->id, "Build input did not change when model input was updated");
}

sub test_annotation_build_accessor {
    is($b->annotation_build, $m->annotation_build, "Annotation build is the same as the model build")
}

sub test_get_feature_list_from_reference {
    my $tumor_build = $b->tumor_build;

    my $mock_ref_build = Test::MockObject::Extends->new($tumor_build->reference_sequence_build);

    my $test_feature = Genome::FeatureList->__define__;
    $mock_ref_build->mock('get_feature_list', sub {return $test_feature;});

    is($b->get_feature_list_from_reference('test'), $test_feature, "got a feature list from the reference");

}
