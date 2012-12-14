#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above "Genome";
use Test::More;

UR::DataSource->next_dummy_autogenerated_id;
do {
    $UR::DataSource::last_dummy_autogenerated_id = int($UR::DataSource::last_dummy_autogenerated_id / 10);
} until length($UR::DataSource::last_dummy_autogenerated_id) < 9;
diag('Dummy ID: '.$UR::DataSource::last_dummy_autogenerated_id);
cmp_ok(length($UR::DataSource::last_dummy_autogenerated_id), '<',  9, 'dummy id is shorter than 9 chars');

use_ok('Genome::Sample::Command::Import::Atcc') or die;

my $common_name = 'COLO-000';
my $individual_name = 'ATCC-'.$common_name;

my $name = 'ATCC-COLO-000-BL';
my $import_normal = Genome::Sample::Command::Import::Atcc->create(
    name => $name,
    gender => 'male',
    ethnicity => 'caucasian',
    age => 45,
    organ_name => 'blood',
);
ok($import_normal, 'create');
$import_normal->dump_status_messages(1);
ok($import_normal->execute, 'execute');
is($import_normal->_individual->name, $individual_name, 'individual name');
is($import_normal->_individual->common_name, $common_name, 'individual common name');
is($import_normal->_individual->nomenclature, 'ATCC', 'individual nomenclature');
is($import_normal->_individual->gender, 'male', 'individual gender');
is($import_normal->_sample->name, $name, 'sample name');
is($import_normal->_sample->common_name, 'normal', 'sample common name');
is($import_normal->_sample->nomenclature, 'ATCC', 'sample nomenclature');
is($import_normal->_sample->extraction_label, $name, 'sample extraction label');
is($import_normal->_sample->extraction_type, 'genomic dna', 'sample extraction type');
is($import_normal->_sample->age, 45, 'sample age');
is($import_normal->_sample->organ_name, 'blood', 'sample organ name');
is_deeply($import_normal->_sample->source, $import_normal->_individual, 'sample source');
is($import_normal->_library->name, $name.'-extlibs', 'library name');
is_deeply($import_normal->_library->sample, $import_normal->_sample, 'library sample');
is(@{$import_normal->_created_objects}, 3, 'created 3 objects');

$name = 'ATCC-COLO-000';
my $import_tumor = Genome::Sample::Command::Import::Atcc->create(
    name => $name,
    gender => 'male',
    ethnicity => 'caucasian',
    age => 45,
    organ_name => 'skin',
    disease => 'malignant melanoma',
);
ok($import_tumor, 'create');
$import_tumor->dump_status_messages(1);
ok($import_tumor->execute, 'execute');
is_deeply($import_tumor->_individual->name, $individual_name, 'individual name');
is($import_tumor->_individual->name, $individual_name, 'individual name');
is($import_tumor->_individual->common_name, $common_name, 'individual common name');
is($import_tumor->_individual->nomenclature, 'ATCC', 'individual nomenclature');
is($import_tumor->_individual->gender, 'male', 'individual gender');
is($import_tumor->_sample->name, $name, 'sample name');
is($import_tumor->_sample->common_name, 'tumor', 'sample common name');
is($import_tumor->_sample->nomenclature, 'ATCC', 'sample nomenclature');
is($import_tumor->_sample->extraction_label, $name, 'sample extraction label');
is($import_tumor->_sample->extraction_type, 'genomic dna', 'sample extraction type');
is($import_tumor->_sample->age, 45, 'sample age');
is($import_tumor->_sample->organ_name, 'skin', 'sample organ name');
is($import_tumor->_sample->disease, 'malignant melanoma', 'sample disease');
is_deeply($import_tumor->_sample->source, $import_tumor->_individual, 'sample source');
is_deeply($import_tumor->_individual, $import_normal->_individual, 'individuals match for tumor/normal');
is($import_tumor->_library->name, $name.'-extlibs', 'library name');
is_deeply($import_tumor->_library->sample, $import_tumor->_sample, 'library sample');
is(@{$import_tumor->_created_objects}, 2, 'created 2 objects');

# fail
my $import_fail = Genome::Sample::Command::Import::Atcc->create(
    name => 'TCGA-COLO-000',
    gender => 'male',
    ethnicity => 'caucasian',
    age => 45,
    organ_name => 'skin',
    disease => 'malignant melanoma',
);
ok($import_fail, 'create');
$import_fail->dump_status_messages(1);
ok(!$import_fail->execute, 'execute failed b/c name does not have ATCC');

$import_fail = Genome::Sample::Command::Import::Atcc->create(
    name => 'ATCC-COLO-000-00-00',
    gender => 'male',
    ethnicity => 'caucasian',
    age => 45,
    organ_name => 'skin',
    disease => 'malignant melanoma',
);
ok($import_fail, 'create');
$import_fail->dump_status_messages(1);
ok(!$import_fail->execute, 'execute failed b/c name has too many parts');

done_testing();
