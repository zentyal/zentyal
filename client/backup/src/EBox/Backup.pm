# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Backup;

use strict;
use warnings;

use base 'EBox::GConfModule';

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::Validate qw(isPrivateDir);
use EBox::FileSystem qw (makePrivateDir);
use EBox::Backup::BackupManager;
use Error qw(:try);
use File::Slurp  qw(write_file);
use EBox::Summary::Module;

use Readonly;
Readonly::Scalar my $GCONF_DUMP_COMMAND => '/usr/bin/gconftool-2 --dump /ebox';
Readonly::Scalar my $GCONF_LOAD_COMMAND => '/usr/bin/gconftool-2 --load ';
Readonly::Scalar my $GCONF_DUMP_FILE     => 'gconf.xml';


sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'backup');
	bless($self, $class);
	return $self;
}

sub _regenConfig
{
}



sub rootCommands
{
	my $self = shift;
	my @commands = ();
	return @commands;
}

sub dumpDir
{
  warn "Provisional";
  return EBox::Config::tmp() . '/dump';
}

sub restoreDir
{
  warn "Provisional";
  return EBox::Config::tmp() . '/restore';
}



sub dumpGConf
{
  my ($self) = @_;

  my $dir = dumpDir();
  my $oldUmask = umask();

  try {
    umask '0077';

    my @dumpOutput = `$GCONF_DUMP_COMMAND`;
    if ($? != 0) {
      throw EBox::Exceptions::External (__("Error backing up GConf: @dumpOutput"));
    }

    write_file("$dir/$GCONF_DUMP_FILE", \@dumpOutput);
  }
  finally {
    umask $oldUmask;
  };
}


sub restoreGConf
{
  my ($self) = @_;

  my $dir = $self->restoreDir();
  my $loadOutput =  `$GCONF_LOAD_COMMAND $dir/$GCONF_DUMP_FILE`;

  if ($? != 0) {
    throw EBox::Exceptions::External (__('Error restoring EBox GConf: ') . $loadOutput);
  }
}


sub dumpFiles
{
  my ($self) = @_;

  $self->dumpGConf();

  my $dumpDir = dumpDir();
  my $backupHelpersByName_r = $self->_backupHelpersByName();
  while (my ($modName, $bh) = each %{ $backupHelpersByName_r  }) {
    my $dir = "$dumpDir/$modName";
    makePrivateDir($dir);
    $bh->dumpConf( $dir);
  }
}




sub backup
{
  my ($self) = @_;
  try {
    EBox::info('Backup process started');
    my $dir = $self->dumpDir();
    isPrivateDir($dir) or throw EBox::Exceptions::Internal('The backup dir is not private');
    $self->dumpFiles();
    $self->backupFiles();
    $self->setLastBackupTime()
  }
  otherwise {
    my $e = shift;
    EBox::error('Backup attempt failed');
    $e->throw();
  };
}


sub backupFiles
{
  my ($self) = @_;


#   my @backupManagerParams = qw(dumpDir repositoryRoot, archiveTTL);
#   @backupManagerParams = map {
#                                   my $accessor = $self->can($_);
# 				  my $value    = $accessor->($self)
# 				  ($_ => $value)
#                               } @backupManagerParams;

#   EBox::Backup::BackupManager::backup(@backupManagerParams);

  warn 'incomplete. We copy all to /tmp/backup for now';
  my $dir = $self->dumpDir();
  system "rm -rf /tmp/backup/*";
  system "cp -r $dir/* /tmp/backup/";

}


sub setLastBackupTime
{
  my ($self) = @_;
  my $t = time();
}

sub restore
{
  my ($self) = @_;
  try {
    EBox::info('Restoring configuration from backup process started');

    my $dir = $self->restoreDir();
    isPrivateDir($dir) or throw EBox::Exceptions::Internal('The restore  dir is not private');

    $self->extractFiles();
    $self->restoreConf();
    $self->setAllModulesChanged();
    $self->setLastRestoreTime();
  }
  otherwise {
    my $e = shift;
    EBox::error('Restoring configuration from backup process failed');
    $e->throw();
  };
}

sub extractFiles
{
  my ($self) = @_;
  my $dir = $self->restoreDir();

  warn 'incomplete. We copy all from /tmp/backup for now';
  system "cp -r  /tmp/backup/* $dir";
}


sub restoreConf
{
  my ($self) = @_;

  $self->restoreGConf();

  my $restoreDir = restoreDir();
  my $backupHelpersByName_r = $self->_backupHelpersByName();
  while (my ($modName, $bh) = each %{ $backupHelpersByName_r }) {
    my $dir = "$restoreDir/$modName";
    makePrivateDir($dir);
    $bh->restoreConf($dir);
  }



}

# mark all modules as changed
sub setAllModulesChanged
{
  my ($self) = @_;

  my $global = EBox::Global->getInstance();
  foreach my $modName ($global->modNames) {
    $global->modChange($modName);
  }
}

sub setLastRestoreTime
{
  my ($self) = @_;
}


sub _backupHelpersByName
{
  my @helpers    =  map { $_->can('backupHelper') ?  ($_->name(), $_->backupHelper()) : ()  }   @{ EBox::Global->modInstances() };  
  return {@helpers};
}




sub summary
{
	my $self = shift;
	my $item = new EBox::Summary::Module(__("Configuration backup"));
	# TODO: put last backup and resote  time
	return $item;
}
1;
