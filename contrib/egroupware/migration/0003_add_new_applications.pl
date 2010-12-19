#!/usr/bin/perl

# Copyright (C) 2008-2010 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

#	Migration between gconf data version 2 to 3
#
#	In version 1, we have added new apps to the supported egroupware apps.
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

use base 'EBox::Migration::Base';

use constant NEW_APPS => ('groupdav',
                          'egw-pear',
                          'phpsysinfo',
                          'developer_tools',
                          'phpgwapi',
                          'syncml',
                          'tracker',
                          'notifications');

sub _addNewApps
{
    my ($self) = @_;

    my $model = $self->{gconfmodule}->model('PermissionTemplates');

    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        my $apps = $row->subModel('applications');
        foreach my $app (NEW_APPS) {
            try {
                $apps->add(app => $app, enabled => 0);
            } catch Error with {};
        }
    }

    my $default = $self->{gconfmodule}->model('DefaultApplications');
    # Only add to the DefaultApplications model if the rows for the
    # rest of the applications are already added
    if (@{$default->ids()}) {
        foreach my $app (NEW_APPS) {
            try {
                $default->add(app => $app, enabled => 0);
            } catch Error with {};
        }
    }
}

sub runGConf
{
    my ($self) = @_;

    $self->_addNewApps();
    my $egwMod = EBox::Global->modInstance('egroupware');
    $egwMod->saveConfig();
}

EBox::init();

my $egw = EBox::Global->modInstance('egroupware');
my $migration = new EBox::Migration(
    'gconfmodule' => $egw,
    'version' => 3
);
$migration->execute();
