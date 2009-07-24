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
use constant DFLTDIR          => 'ebox-backup';
use constant DFLTKEEP         => '90';
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
        'EBox::EBackup::Model::Local',
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


# Method: actions
#
# Overrides:
#
#      <EBox::Module::Service::actions>
#
sub actions
{
    return [
    {
        'action' => __('Install /etc/cron.daily/ebox-ebackup-cron.'),
        'reason' => __('eBox will run a nightly script to backup your system.'),
        'module' => 'ebackup'
    },
    ];
}


# Method: usedFiles
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::usedFiles>
#
#sub usedFiles
#{
#    my @usedFiles;
#
#    push (@usedFiles, { 'file' => SLBACKUPCONFFILE,
#                        'module' => 'ebackup',
#                        'reason' => __('To configure backups.')
#                      });
#
#    return \@usedFiles;
#}

# Method: _setConf
#
# Overrides:
#
#      <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;
    # install cronjob
    my $cronFile = EBox::Config::share() . '/ebox-ebackup/ebox-ebackup-cron';
    EBox::Sudo::root("install -m 0755 -o root -g root $cronFile /etc/cron.daily/");
}


# Method: _setSLBackup
#FIXME doc
#sub _setSLBackup
#{
#    my ($self) = @_;
#
#    my $model = $self->model('Hosts');
#
#    my @hosts = ();
#    foreach my $host (@{$model->ids()}) {
#        my $row = $model->row($host);
#        my $hostname = $row->valueByName('hostname');
#        my $keep = $row->valueByName('keep');
#        push (@hosts, { hostname => $hostname,
#                        keep => $keep,
#                      });
#    }
#
#    $model = $self->model('Settings');
#
#    my $backuppath = $model->backupPathValue();
#
#    my @params = ();
#
#    #push (@params, hosts => \@hosts );
#    push (@params, backuppath => $backuppath);
#
#    $self->writeConfFile(SLBACKUPCONFFILE, "ebackup/slbackup.conf.mas", \@params,
#                            { 'uid' => 0, 'gid' => 0, mode => '640' });
#}


# Method: menu
#
# Overrides:
#
#      <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item(
            'url' => 'EBackup/Composite/General',
            'separator' => __('Core'),
            'order' => 95,
            'text' => $self->printableName()));
}

1;
