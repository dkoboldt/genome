package Genome::Config::AnalysisMenu::Item;

use strict;
use warnings;

use Genome;

class Genome::Config::AnalysisMenu::Item {
    is => ['Genome::Utility::ObjectWithTimestamps','Genome::Utility::ObjectWithCreatedBy'],
    data_source => 'Genome::DataSource::GMSchema',
    table_name => 'config.analysismenu_item',
    id_generator => '-uuid',
    has => [
        id => {
            is => 'Text',
            len => 64,
        },
        name => {
            is => 'Text',
        },
        file_path => {
            is => 'Text'
        },
        description => {
            is => 'Text',
        },
    ],
    has_many => [
        config_items => {
            is => 'Genome::Config::Profile::Item',
            reverse_as => 'analysis_menu_item',
            doc => 'Config Items based on this menu item',
        },
        analysis_projects => {
            is => 'Genome::Config::AnalysisProject',
            via => 'config_items',
            to => 'analysis_project',
            doc => 'Analysis Projects using this menu item',
        },
    ],
};

sub __display_name__ {
    my $self = shift;
    return sprintf('%s (%s)', $self->name, $self->id);
}

1;
