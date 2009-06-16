#!/usr/bin/perl

#	Migration between gconf data version 0 to 1
#
#	In version 1, we have added bookmarks to the supported egroupware apps.
#
#	This migration script tries to add it to all the previously defined
#   permission templates.
#
package EBox::Migration;
use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Model::ModelManager;
use Socket;
use Error qw(:try);

use base 'EBox::MigrationBase';

sub _addBookmarks
{
    my ($self) = @_;

    my $model = $self->{gconfmodule}->model('PermissionTemplates');

    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $apps = $row->subModel('applications');
        $apps->add(app => 'bookmarks', enabled => 0);
    }

    my $default = $self->{gconfmodule}->model('DefaultApplications');
    # Only add to the DefaultApplications model if the rows for the
    # rest of the applications are already added
    if (@{$default->ids()}) {
        $default->add(app => 'bookmarks', enabled => 0);
    }
}

sub runGConf
{
    my ($self) = @_;

    $self->_addBookmarks();

    my $egwMod = EBox::Global->modInstance('egroupware');
    $egwMod->saveConfig();
}

EBox::init();

my $egw = EBox::Global->modInstance('egroupware');
my $migration = new EBox::Migration(
    'gconfmodule' => $egw,
    'version' => 1
);
$migration->execute();
