#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Basename qw(dirname basename);
use File::DirCompare;
use Sub::Install qw(reinstall_sub);
use Genome::Test::Factory::Model::ReferenceSequence;
use Genome::Test::Factory::Model::ImportedVariationList;
use Genome::Test::Factory::Build;
use Genome::Test::Factory::Sample;
use Genome::VariantReporting::Framework::Command::Wrappers::TestHelpers qw(get_build);

my $pkg = "Genome::VariantReporting::Framework::Command::Wrappers::ModelPair";

use_ok($pkg);

my $test_dir = __FILE__.".d";
my $expected_dir = File::Spec->join($test_dir, "expected");
my $output_dir = Genome::Sys->create_temp_directory;

my $roi_name = "test_roi";
my $tumor_sample = Genome::Test::Factory::Sample->setup_object();
my $normal_sample = Genome::Test::Factory::Sample->setup_object(source_id => $tumor_sample->source_id);
my $discovery_build = get_build($roi_name, $tumor_sample, $normal_sample);
is($discovery_build->class, "Genome::Model::Build::SomaticValidation");

my $dbsnp_model = Genome::Test::Factory::Model::ImportedVariationList->setup_object();
my $dbsnp_build = Genome::Test::Factory::Build->setup_object(model_id => $dbsnp_model->id);
$discovery_build->previously_discovered_variations_build($dbsnp_build);
reinstall_sub( {
    into => "Genome::Model::Build::ImportedVariationList",
    as => "snvs_vcf",
    code => sub {
        return "test.vcf";
    },
}
);

my $vcf_result = Genome::Model::Tools::DetectVariants2::Result::Vcf::Combine->__define__;
my $vcf = File::Spec->join($test_dir, "snvs.vcf.gz");
reinstall_sub({
    into => "Genome::Model::Build::SomaticValidation",
    as => "get_detailed_vcf_result",
    code => sub {
        return $vcf_result;
    },
});

reinstall_sub({
    into => "Genome::Model::Tools::DetectVariants2::Result::Vcf",
    as => "get_vcf",
    code => sub {
        return $vcf;
    },
});

my $alignment_result = Genome::InstrumentData::AlignmentResult::Merged->__define__(id => "-b52e1b52f81e4541af7f71ce14ca96f6");
reinstall_sub( {
    into => "Genome::Model::Build::SomaticValidation",
    as => "merged_alignment_result",
    code => sub {
        return $alignment_result;
    },
});

my $control_alignment_result = Genome::InstrumentData::AlignmentResult::Merged->__define__(id => "-533e0bb1a99f4fbe9e31cf6e19907133");

reinstall_sub( {
    into => "Genome::Model::Build::SomaticValidation",
    as => "control_merged_alignment_result",
    code => sub {
        return $control_alignment_result;
    },
});

my $reference_sequence_model = Genome::Test::Factory::Model::ReferenceSequence->setup_object();
my $reference_sequence_build = Genome::Test::Factory::Build->setup_object(model_id => $reference_sequence_model->id);
reinstall_sub( {
    into => "Genome::Model::Build::SomaticValidation",
    as => "reference_sequence_build",
    code => sub {
        return $reference_sequence_build;
    },
});
my $segdups = Genome::FeatureList->__define__(id => "-424d29730a204e20acb521eaa8c4a2b6");
reinstall_sub( {
    into => "Genome::Model::Build::ReferenceSequence",
    as => "get_feature_list",
    code => sub {
        return $segdups;
    },
});

my $model_pair = $pkg->create(discovery => $discovery_build,
    validation => $discovery_build,
    #base_output_dir => $expected_dir,
    base_output_dir => $output_dir,
);
is($model_pair->class, "Genome::VariantReporting::Framework::Command::Wrappers::ModelPair");

my $comparison = File::DirCompare->compare($expected_dir, $output_dir, sub {
        my ($a, $b) = @_;
        if (! $b) {
            printf "Only in %s: %s\n", dirname($a), basename($a);
        } elsif (! $a) {
            printf "Only in %s: %s\n", dirname($b), basename($b);
        } else {
            print "Files $a and $b differ\n";
        }
}, {cmp => sub {
    my ($a, $b) = @_;
    if (Genome::Sys->file_is_gzipped($a) and Genome::Sys->file_is_gzipped($b)) {
        my $unzipped_a = unzip($a);
        my $unzipped_b = unzip($b);
        return File::Compare::compare($unzipped_a, $unzipped_b);
    }
    else {
        return File::Compare::compare($a, $b);
    }
}
});
ok(!$comparison);

done_testing;

sub unzip {
    my $file = shift;
    my $unzipped = Genome::Sys->create_temp_file_path;
    Genome::Sys->shellcmd(
        cmd => "gunzip -c $file > $unzipped",
        input_files => [$file],
        output_files => [$unzipped],
    );
    return $unzipped;
}