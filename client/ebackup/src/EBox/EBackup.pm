# Copyright (C) 2008 eBox Technologies S.L.
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


package EBox::EBackup;

# Class: EBox::EBackup
#
#

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider);

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;

use constant DFLTPATH         => '/mnt/backup';
use constant SLBACKUPCONFFILE => '/etc/slbackup/slbackup.conf';

# Constructor: _create
#
#      Create a new EBox::EBackup module object
#
# Returns:
#
#      <EBox::EBackup> - the recently created model
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'ebackup',
            printableName => __('Backup'),
            domain => 'ebox-ebackup',
            @_);

    bless($self, $class);
    return $self;
}


# Method: modelClasses
#
# Overrides:
#
#      <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::EBackup::Model::Settings',
        'EBox::EBackup::Model::Hosts',
    ];
}


# Method: compositeClasses
#
# Overrides:
#
#      <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::EBackup::Composite::General',
    ];
}


# Method: usedFiles
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => SLBACKUPCONFFILE,
                        'module' => 'ebackup',
                        'reason' => __('To configure backups.')
                      });

    return \@usedFiles;
}


# Method: enableActions
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::enableActions>
#
sub enableActions
{
    my ($self) = @_;

    EBox::Sudo::root(EBox::Config::share() .
                     '/ebox-ebackup/ebox-ebackup-enable');
}


# Method: enableService
#
# Overrides:
#
#      <EBox::Module::Service::enableService>
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
}


# Method: _setConf
#
# Overrides:
#
#      <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $self->_setSLBackup();
}


# Method: _setSLBackup
#FIXME doc
sub _setSLBackup
{
    my ($self) = @_;

    my $model = $self->model('Hosts');

    my @hosts = ();
    foreach my $host (@{$model->ids()}) {
        my $row = $model->row($host);
        my $hostname = $row->valueByName('hostname');
        my $keep = $row->valueByName('keep');
        push (@hosts, { hostname => $hostname,
                        keep => $keep,
                      });
    }

    $model = $self->model('Settings');

    my $backuppath = $model->backupPathValue();

    my @params = ();

    push (@params, hosts => \@hosts );
    push (@params, backuppath => $backuppath);

    $self->writeConfFile(SLBACKUPCONFFILE, "ebackup/slbackup.conf.mas", \@params,
                            { 'uid' => 0, 'gid' => 0, mode => '640' });
}


# Method: fqdn
#FIXME doc
sub fqdn
{
    my $fqdn = `hostname --fqdn`;
    if ($? != 0) {
        $fqdn = 'ebox.localdomain';
    }
    chomp $fqdn;
    return $fqdn;
}


# Method: menu
#
# Overrides:
#
#      <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Backup',
                                        'text' => __('Backup'),
                                        'order' => 20);

    $folder->add(new EBox::Menu::Item(
            'url' => 'EBackup/Composite/General',
            'text' => __('General')));

    $root->add($folder);
}

1;
