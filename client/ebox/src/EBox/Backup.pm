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

use File::Temp qw(tempdir);
use File::Copy qw(copy move);
use File::Slurp qw(read_file write_file);
use EBox::Config;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::FileSystem;
use Error qw(:try);
use Digest::MD5;
use EBox::Sudo qw(:all);
use POSIX qw(strftime);
use DirHandle;
use EBox::Backup::FileBurner;
use EBox::Backup::OpticalDiscDrives;


use Readonly;
Readonly::Scalar my $FULL_BACKUP_ID  => 'full backup';
Readonly::Scalar my $CONF_BACKUP_ID  =>'configuration backup';
Readonly::Scalar my $DISC_BACKUP_FILE  => 'eboxbackup.tar';

sub new 
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# returns:
# 	string: path to the backup file.
sub _makeBackup # (description, bug?) 
{
	my ($self, %options) = @_;

	my $bug         = delete $options{bug};
	my $description = delete $options{description};

	my $time = strftime("%F %T", localtime);
	my $what =  $bug ? 'bugreport' : 'backup';

	my $confdir = EBox::Config::conf;
	my $tempdir = tempdir("$confdir/backup.XXXXXX") or
		throw EBox::Exceptions::Internal("Could not create tempdir.");
	my $auxDir = "$tempdir/aux";
	my $archiveContentsDirRelative = "ebox$what";
	my $archiveContentsDir = "$tempdir/$archiveContentsDirRelative";
	my $backupArchive = "$confdir/ebox$what.tar";
	
	try {
	  mkdir($auxDir) or
	    throw EBox::Exceptions::Internal("Could not create auxiliar tempdir.");
	  mkdir($archiveContentsDir) or
	    throw EBox::Exceptions::Internal("Could not create archive tempdir.");

	  $self->_dumpModulesBackupData($auxDir, %options);

	  if ($bug) {
	    $self->_bug($auxDir);
	  }


	  my $filesArchive  = "$archiveContentsDir/files.tgz";
	  $self->_createFilesArchive($auxDir, $filesArchive);
	  $self->_createMd5DigestForArchive($filesArchive, $archiveContentsDir);
	  $self->_createDescriptionFile($archiveContentsDir, $description);
	  $self->_createDateFile($archiveContentsDir, $time);
	  $self->_createTypeFile($archiveContentsDir, $options{fullBackup});
	  $self->_createModulesListFile($archiveContentsDir);

	  $self->_createBackupArchive($backupArchive, $tempdir, $archiveContentsDirRelative);
	}
	finally {
	  system "rm -rf $tempdir";
	  if ($? != 0) {
	    EBox::error("$auxDir can not be deleted: $!. Please do it manually");
	  }
	};

	return $backupArchive;
}


sub _dumpModulesBackupData
{
  my ($self, $auxDir, @options) = @_;

  my $global = EBox::Global->getInstance();
  my @names = @{$global->modNames};
  foreach (@names) {
    my $mod = $global->modInstance($_);
    try {
      EBox::debug("Dumping $_ backup data");
      $mod->makeBackup($auxDir, @options);
    } 
    catch EBox::Exceptions::Base with {
      my $ex = shift;
      throw EBox::Exceptions::Internal($ex->text);
    };
  }

}

sub  _createFilesArchive
{
  my ($self, $auxDir, $filesArchive) = @_;

  if (`tar czf $filesArchive -C $auxDir .`) {
    throw EBox::Exceptions::Internal("Could not create archive.");
  }
  `rm -rf $auxDir`;

} 

sub  _createDateFile
{
  my ($self, $archiveContentsDir, $time) = @_;

  my $DATE;
  unless (open($DATE, "> $archiveContentsDir/date")) {
    throw EBox::Exceptions::Internal ("Could not create date file.");
  }
  print $DATE  $time ;
  close($DATE);
} 

sub  _createDescriptionFile
{
  my ($self, $archiveContentsDir, $description) = @_;

  my $DESC;
  unless (open($DESC, "> $archiveContentsDir/description")) {
    throw EBox::Exceptions::Internal ("Could not create description file.");
  }
  print $DESC $description;
  close($DESC);
} 

sub  _createTypeFile
{
  my ($self, $archiveContentsDir, $fullBackup) = @_;

  my $type = $fullBackup ?  $FULL_BACKUP_ID : $CONF_BACKUP_ID;

  my $TYPE_F;
  unless (open($TYPE_F, "> $archiveContentsDir/type")) {
    throw EBox::Exceptions::Internal ("Could not create type file.");
  }
  print $TYPE_F $type;
  close($TYPE_F);
} 

sub _createMd5DigestForArchive
{
  my ($self, $filesArchive, $archiveContentsDir) = @_;
  
  my $ARCHIVE;
  unless (open($ARCHIVE, $filesArchive)) {
    throw EBox::Exceptions::Internal("Could not open files archive.");
  }
  my $md5 = Digest::MD5->new;
  $md5->addfile($ARCHIVE);
  my $digest = $md5->hexdigest;
  close($ARCHIVE);

  my $MD5;
  unless (open($MD5, "> $archiveContentsDir/md5sum")) {
    throw EBox::Exceptions::Internal("Could not open md5 file.");
  }
  print $MD5 $digest;
  close($MD5);
}


sub  _createModulesListFile
{
  my ($self, $archiveContentsDir) = @_;

  my $global = EBox::Global->getInstance();
  my @modNames = @{ $global->modNames() };

  my $file = "$archiveContentsDir/modules";
  write_file($file, "@modNames");
} 

sub  _createBackupArchive
{
  my ($self, $backupArchive, $tempdir, $archiveContentsDirRelative) = @_;

  if ( -f $backupArchive) {
    if (`rm -f $backupArchive`) {
      throw EBox::Exceptions::Internal	("Could not delete old file.");
    }
  }

  `tar cf $backupArchive -C $tempdir $archiveContentsDirRelative`;
  ($? == 0) or throw EBox::Exceptions::Internal("Could not create archive.");
} 




sub _bug # (dir) 
{
	my ($self, $dir) = @_;
	`/bin/ps aux > $dir/processes`;
	`/bin/df -k > $dir/disks`;
	`/bin/netstat -n -a --inet > $dir/sockets`;
	`/sbin/ifconfig -a > $dir/interfaces`;

	try {
		root("/sbin/iptables -nvL > $dir/iptables-filter");
	} catch EBox::Exceptions::Base with {};

	try {
		root("/sbin/iptables -t nat -nvL > $dir/iptables-nat");
	} catch EBox::Exceptions::Base with {};

	copy(EBox::Config::logfile, "$dir/ebox.log");
	copy(EBox::Config::log . "/error.log", "$dir/error.log");
	copy("/var/log/syslog", "$dir/syslog");
	copy("/var/log/messages", "$dir/messages");
	copy("/var/log/daemon.log", "$dir/daemon.log");
	copy("/var/log/auth.log", "$dir/auth.log");
}

#
# Method: backupDetails 
#
#   	Gathers the information for a given backup
#
# Parameters:
#
#       id - backup's identifier
#
# Returns:
#
#       A hash reference with the details. This hash consists of:
#	
#	id - backup's identifier
#	date - when it was backed up
#	description - backup's description
#
sub backupDetails # (id) 
{
  my ($self, $id) = @_;
  $self->_checkId($id);

  my $file = $self->_backupFileById($id);

  my $details = $self->backupDetailsFromFile($file);
  $details->{id} = $id;
  
  return $details;
}

sub backupDiscDetails
{
  my ($self) = @_;

  my $discFileInfo = EBox::Backup::OpticalDiscDrives::searchFileInDiscs($DISC_BACKUP_FILE);
  if (!defined $discFileInfo) {
    throw EBox::Exceptions::External(__('Insert a backup disc and try again, please'));
  }

  my $details = $self->backupDetailsFromFile($discFileInfo->{file});
  $details->{disc} = 1;
  
  return $details;
}


sub backupDetailsFromFile
{
  my ($self, $file) = @_;

  my $t = $self->_unpackAndVerify($file);

  my $entry = {};

  my @details = qw(date description type);
  foreach my $detail (@details) {
    my $FH;
    unless (open($FH, "$t/eboxbackup/$detail")) {
      $entry->{$detail} = __('Unknown');
      next;
    }

    my $value = <$FH>;
    $entry->{$detail} = $value;

    close $FH;
  }

  $entry->{file} = $file; 

  `rm -rf $t`;
  return $entry;
}



#
# Method: deleteBackup 
#
#   	Romoves a stored backup	
#
# Parameters:
#
#       id - backup's identifier
#
# Exceptions:
#
#     	External -  If it can't be found or deleted.
sub deleteBackup # (id) 
{
	my ($self, $id) = @_;
	$self->_checkId($id);
	
	my $file = $self->_backupFileById($id);

	unless (unlink($file)) {
		throw EBox::Exceptions::External("Could not delete the backup");
	}
}

#
# Method: listBackups 
#
#   	Returns a list with the availible backups stored in the system.	
#
# Parameters:
#
#       id - backup's identifier
#
# Returns:
#
#       A a ref to an array of hashes. Each  hash reference consists of:
#	
#	id - backup's identifier
#	date - when it was backed up
#	description - backup's description
#       type        - type of backup (full or configuration only)
#
sub listBackups
{
	my $self = shift;
	my $backupdir = EBox::Config::conf . '/backups';
	my $bh = new DirHandle($backupdir);
	my @backups = ();
	my $backup;
	($bh) or return \@backups;
	while (defined($backup = $bh->read)) {
		(-f "$backupdir/$backup") or next;
		$backup =~ s/\.tar$//;
		my $entry = undef;
		try {
			$entry = $self->backupDetails($backup);
		} catch EBox::Exceptions::Base with {};
		unless ($entry) {
			unlink("$backupdir/$backup.tar");
			next;
		}
		push(@backups, $entry);
	}
	undef $bh;
	my @ret = sort {$a->{date} lt $b->{date}} @backups;
	return \@ret;
}

#
# Method: makeBackup 
#
#   	Backups the current configuration	
#
# Parameters:
#
#       description - backup's description (backwards compability mode)
#       --OR--
#       options     - options lists
#                   description - backup's description (backwards compability mode)
#                   fullBackup  - wether do a full backup or  backup only configuration (default: false)
#                   directlyToDisc      - burn directly to Cd the backup and do not store it in the filesystem (default: false)
#
# Exceptions:
#	
#	Internal - If backup fails
#
sub makeBackup # (options) 
{
  my ($self, %options) = @_;
  # default values 
  exists $options{description}  or $options{description} = __('Backup');
  exists $options{fullBackup}   or $options{fullBackup} = 0;
  exists $options{directlyToDisc} or $options{directlyToDisc} = 0;

  my $time = strftime("%F", localtime);
  my $backupdir = EBox::Config::conf . '/backups';
  unless (-d $backupdir) {
    mkdir($backupdir) or throw EBox::Exceptions::Internal
      ("Could not create backupdir.");
  }

  my $filename = $self->_makeBackup(%options);

  if ($options{directlyToDisc}) {
    return $self->_moveToDisc($filename);
  }
  
  return $self->_moveToArchives($filename, $backupdir);
}

sub  _moveToArchives
{
  my ($self, $filename, $backupdir) = @_;

  my $id = int(rand(999999)) . ".tar";
  while (-f "$backupdir/$id") {
    $id = int(rand(999999)) . ".tar";
  }

  move($filename, "$backupdir/$id") or
    throw EBox::Exceptions::Internal("Could not save the backup.");

  return "$backupdir/$id";
} 

sub _moveToDisc
{
  my ($self, $filename) = @_;

  EBox::Backup::FileBurner::burn(file => $filename);
  unlink $filename;
  return undef;
} 

#
# Method: makeBugReport
#
#   	Makes a bug report	
#
sub makeBugReport
{
	my $self = shift;
	return $self->_makeBackup(description => 'Bug report', 'bug' => 1);
}

# unpacks a backup file into a temporary directory and verifies the md5sum
# arguments:
# 	string: backup file
# returns:
# 	string: path to the temporary directory
sub _unpackAndVerify # (file, fullRestore) 
{
	my ($self, $file, $fullRestore) = @_;
	($file) or throw EBox::Exceptions::External('No backup file provided.');
	my $tempdir = tempdir(EBox::Config::tmp . "/backup.XXXXXX") or
		throw EBox::Exceptions::Internal("Could not create tempdir.");
	try {
	  unless (copy($file, "$tempdir/eboxbackup.tar")) {
	    throw EBox::Exceptions::Internal("Could not copy backup into ".
					     "the tempdir.");
	  }

	  if (`tar xf $tempdir/eboxbackup.tar -C $tempdir`) {
	    throw EBox::Exceptions::External( __("Could not unpack the backup"));
	  }

	  unless ( -f "$tempdir/eboxbackup/files.tgz" && 
		   -f "$tempdir/eboxbackup/md5sum") {
	    throw EBox::Exceptions::External( __('Incorrect or corrupt backup file'));
	  }

	  $self->_checkArchiveMd5Sum($tempdir);
	  $self->_checkArchiveType($tempdir, $fullRestore);
	  $self->_checkModuleList($tempdir);
	}
	otherwise {
	  my $ex = shift;

	  system("rm -rf $tempdir");
	  ($? == 0) or EBox::warning("Unable to remove $tempdir. Please do it manually");

	  $ex->throw();
	};

	return $tempdir;
}

sub  _checkArchiveMd5Sum
{
  my ($self, $tempdir) = @_;

  my $ARCHIVE;
  unless (open($ARCHIVE, "$tempdir/eboxbackup/files.tgz")) {
    throw EBox::Exceptions::Internal("Could not open archive.");
  }
  my $md5 = Digest::MD5->new;
  $md5->addfile($ARCHIVE);
  my $digest = $md5->hexdigest;
  close($ARCHIVE);

  my $MD5;
  unless (open($MD5, "$tempdir/eboxbackup/md5sum")) {
    throw EBox::Exceptions::Internal("Could not open the md5sum.");
  }
  my $olddigest = <$MD5>;
  close($MD5);

  if ($digest ne $olddigest) {
    throw EBox::Exceptions::External(
				     __('The backup file is corrupt.'));
  }
}

sub _checkArchiveType
{
  my ($self, $tempdir, $fullRestore) = @_;

  if ($fullRestore) {
    my $TYPE_F;
    unless (open($TYPE_F, "$tempdir/eboxbackup/type")) {
      throw EBox::Exceptions::Internal("Could not open the type file.");
    }
    my $type = <$TYPE_F>;
    close($TYPE_F);

    if ($type ne $FULL_BACKUP_ID) {
      throw EBox::Exceptions::External(__('The archive does not contain a full backup, that made a full restore impossibe. A configuration recovery  may be possible'));
    }
  } 

}

sub   _checkModuleList
{
  my ($self, $tempdir) = @_;

  my $file = "$tempdir/eboxbackup/modules";
  if (! -e $file) { 
    throw EBox::Exceptions::External (__('Module list not found, the backup is corrupt or was done with a incompatible previous format'));
  }

  my @backupModNames;
  my $fileContents = read_file($file);

  @backupModNames = split '\s+', $fileContents;
  my %backup    =  map { $_ => 0  }   @backupModNames;

  my $global = EBox::Global->getInstance();
  my %actual =  map { $_ => 0  }   @{ $global->modNames() };

  foreach my $name (keys %actual) {
    if (exists $backup{$name}) {
      delete $actual{$name};
      delete $backup{$name};
    }
  }

  my @backupMissing = keys %backup;
  my @actualMissing = keys %actual;


  if ((@backupMissing > 0) or (@actualMissing > 0)) {
    my $backupError = @backupMissing ? __x("The following modules are not present in the global module list stored in the backup but they are present in EBox's global list: {modules}\n", modules => "@backupMissing") : '';
  my $actualError = @actualMissing ? __x("The following modules are  present in the global list stored in the backup but not in EBox's global list: {modules}\n", modules => "@actualMissing") : '';


    throw EBox::Exceptions::External (__x("The restore process failed because there is a mismatch between EBox's installed modules and the modules in the backup.\n{backupError}{actualError} If you want to use this backup you will need to install/remove the adequate modules", backupError => $backupError, actualError => $actualError ));
  }


} 



sub writeBackupToDisc
{
  my ($self, $id) = @_;
  
  $self->_checkId($id);

  my $file = $self->_backupFileById($id);

  my $backupdir = EBox::Config::conf . '/backups';
  my $destFile = "$backupdir/$DISC_BACKUP_FILE";
  
  move($file, $destFile) or throw EBox::Exceptions::Internal("Can not rename backup file: @!");
  
  try {
      EBox::Backup::FileBurner::burn(file => $destFile);
  }
  finally {
      move($destFile, $file) or throw EBox::Exceptions::External(__x('Can not rename backup file from {newName} to  hisr original name {name}. Error message: {error}', newName => $destFile, name => $file, error => $!));
  };
}
 
#
# Method: restoreBackup 
#
#   	Restores a backup from file	
#
# Parameters:
#
#       file - backup's file
#       options 
#                   fullRestore  - wether do a full restore or  restore only configuration (default: false)
#
# Exceptions:
#	
#	External - If it can't unpack de backup
#
sub restoreBackup # (file) 
{
  my ($self, $file, %options) = @_;
  exists $options{fullRestore}  or $options{fullRestore} = 0;

  my $tempdir = $self->_unpackAndVerify($file, $options{fullRestore});

  try {
    if (`tar xzf $tempdir/eboxbackup/files.tgz -C $tempdir/eboxbackup`) {
      `rm -rf $tempdir`;
      throw EBox::Exceptions::External(
				       __('Could not unpack the backup'));
    }

    my $global = EBox::Global->getInstance();
    my @names = grep { $_ ne 'global' }  @{$global->modNames};
    push @names, 'global'; # remember that global can change as result of restore!. So we will put it in last place
    my @modules =  grep { $_ ne 'global' } @{$global->modInstances};   
    my @restored = ();
    try {
      foreach my $modname (@names) {
	my $mod = $global->modInstance($modname);
	
	if (-e "$tempdir/eboxbackup/$modname.bak") {
	  push @restored, $modname;
	  EBox::debug("Restoring $modname form backup data");
	  $mod->restoreBackup("$tempdir/eboxbackup", %options);
	}
      }


    } 
    otherwise {
      my $ex = shift;
      EBox::debug('Error caught: revoking restore');
      foreach my $restname (@restored) {
	my $restmod = $global->modInstance($restname);
	$restmod->revokeConfig();
	EBox::debug("Revoked changes in $restname module");
      }

      throw $ex;
    };

    EBox::debug('Restore successful');
  }
  finally {
      `rm -rf $tempdir`;
  };
}



sub searchBackupFileInDiscs
{
  return EBox::Backup::OpticalDiscDrives::searchFileInDiscs($DISC_BACKUP_FILE);
}

sub restoreBackupFromDisc
{
  my ($self,  %options) = @_;

  my $discFileInfo = searchBackupFileInDiscs();
  if (!defined $discFileInfo) {
    throw EBox::Exceptions::External(__('Insert a backup disc and try again, please'));
  }

  try {
    $self->restoreBackup($discFileInfo->{file}, %options);
  }
  finally {
      EBox::Backup::OpticalDiscDrives::ejectDisc($discFileInfo->{device});
  };
}


sub _checkId
{
  my ($self, $id) = @_;  
  if ($id =~ m{[./]}) {
		throw EBox::Exceptions::External(
			__("The input contains invalid characters"));
	}
}

sub _backupFileById
{
    my ($self, $id) = @_;

    my $backupdir = EBox::Config::conf . '/backups';
    my $file = "$backupdir/$id.tar";
    unless (-f $file) {
	throw EBox::Exceptions::External("Could not find the backup.");
    }

    return $file;
}


1;
