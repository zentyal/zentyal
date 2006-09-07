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
use EBox::Backup::TarArchive;

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
	push @commands, EBox::Backup::BackupManager::rootCommands();
	return @commands;
}




sub dumpDir
{
  return EBox::Config::tmp() . '/dump';
}



sub archiveDir
{
  return EBox::Config::tmp() . '/archive';
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

  my $dir = $self->dumpDir();
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
  my ($self, %params) = @_;
  
  my @backupFilesParams;
  push @backupFilesParams, (media => $params{media}) if exists $params{media};
  push @backupFilesParams, (burn => $params{burn}) if exists $params{burn};

  try {
    EBox::info('Backup process started');
    my $dir = $self->dumpDir();
    EBox::FileSystem::makePrivateDir($dir);
    EBox::FileSystem::cleanDir($dir);

    $self->dumpFiles();
    $self->backupFiles(@backupFilesParams);
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
  my ($self, @params) = @_;
  
  my $archiveDir = archiveDir();
  EBox::FileSystem::makePrivateDir($archiveDir);
  EBox::FileSystem::cleanDir($archiveDir);


   my @backupManagerParams = (
			      bin      => $self->backupManagerBin(),
			      dumpDir  => dumpDir(),
			      archiveDir => $archiveDir,
			      @params
			     );


   EBox::Backup::BackupManager::backup(@backupManagerParams);
}


sub backupManagerBin
{
  return '/usr/sbin/backup-manager';
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

    my $dir = $self->dumpDir();
    EBox::FileSystem::makePrivateDir($dir);
    EBox::FileSystem::cleanDir($dir);
    
    isPrivateDir($dir) or throw EBox::Exceptions::Internal('The restore  dir is not private');

    $self->restoreFiles();
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

sub restoreFiles
{
  my ($self) = @_;

  my $dir = $self->archiveDir();
  my $archiveFile = `/bin/ls $dir/*.tar.gz`;
  chomp $archiveFile;

  EBox::Backup::TarArchive::restore(archiveFile => $archiveFile);
}


sub restoreConf
{
  my ($self) = @_;

  $self->restoreGConf();

  my $dumpDir = dumpDir();
  my $backupHelpersByName_r = $self->_backupHelpersByName();
  while (my ($modName, $bh) = each %{ $backupHelpersByName_r }) {
    my $dir = "$dumpDir/$modName";
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
