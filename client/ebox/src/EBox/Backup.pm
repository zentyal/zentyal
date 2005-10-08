# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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
use File::Copy qw(copy);
use EBox::Config;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use Error qw(:try);
use Digest::MD5;
use EBox::Sudo qw(:all);
use POSIX qw(strftime);
use DirHandle;


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
	my ($self, $description, $bug) = @_;
	my $global = EBox::Global->getInstance();
	my $time = strftime("%F %T", localtime);

	my $what = 'backup';
	if ($bug) {
		$what = 'bugreport';
	}


	my $confdir = EBox::Config::conf;
	my $tempdir = tempdir("$confdir/backup.XXXXXX") or
		throw EBox::Exceptions::Internal("Could not create tempdir.");

	mkdir("$tempdir/aux") or
		throw EBox::Exceptions::Internal("Could not create tempdir.");
	mkdir("$tempdir/ebox$what") or
		throw EBox::Exceptions::Internal("Could not create tempdir.");

	my @names = @{$global->modNames};
	foreach (@names) {
		my $mod = $global->modInstance($_);
		try {
			$mod->makeBackup("$tempdir/aux");
		} catch EBox::Exceptions::Base with {
			my $ex = shift;
			`rm -rf $tempdir`;
			throw EBox::Exceptions::Internal($ex->text);
		};
	}

	if ($bug) {
		$self->_bug("$tempdir/aux");
	}

	if (`tar czf $tempdir/ebox$what/files.tgz -C $tempdir/aux .`) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::Internal("Could not create archive.");
	}
	`rm -rf $tempdir/aux`;

	unless (open(ARCHIVE, "$tempdir/ebox$what/files.tgz")) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::Internal("Could not open archive.");
	}
	my $md5 = Digest::MD5->new;
	$md5->addfile(*ARCHIVE);
	my $digest = $md5->hexdigest;
	close(ARCHIVE);

	unless (open(MD5, "> $tempdir/ebox$what/md5sum")) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::Internal("Could not open md5 file.");
	}
	print MD5 $digest;
	close(MD5);

	unless (open(DESC, "> $tempdir/ebox$what/description")) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::Internal
			("Could not create description file.");
	}
	print DESC $description;
	close(DESC);
	unless (open(DATE, "> $tempdir/ebox$what/date")) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::Internal
			("Could not create date file.");
	}
	print DATE  $time ;
	close(DATE);

	if ( -f "$confdir/ebox$what.tar") {
		if (`rm -f $confdir/ebox$what.tar`) {
			`rm -rf $tempdir`;
			throw EBox::Exceptions::Internal
				("Could not delete old file.");
		}
	}

	`tar cf $confdir/ebox$what.tar -C $tempdir ebox$what` and
		throw EBox::Exceptions::Internal("Could not create archive.");

	`rm -rf $tempdir`;

	return "$confdir/ebox$what.tar";
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
	if ($id =~ m{[./]}) {
		throw EBox::Exceptions::External(
			__("The input contains invalid characters"));
	}
	my $file = EBox::Config::conf . "/backups/$id.tar";

	my $t = $self->_unpackAndVerify($file);

	my $entry = {};
	$entry->{id} = $id;

	unless (open(DATE, "$t/eboxbackup/date")) {
		`rm -rf $t`;
		next;
	}
	$entry->{date} = <DATE>;
	close(DATE);
	unless (open(DESC, "$t/eboxbackup/description")) {
		`rm -rf $t`;
		next;
	}
	$entry->{description} = <DESC>;
	close(DESC);
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
	if ($id =~ m{[./]}) {
		throw EBox::Exceptions::External(
			__("The input contains invalid characters"));
	}
	my $backupdir = EBox::Config::conf . '/backups';
	unless (-f "$backupdir/$id.tar") {
		throw EBox::Exceptions::External("Could not find the backup.");
	}
	unless (unlink("$backupdir/$id.tar")) {
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
#       description - backup's description
#
# Exceptions:
#	
#	Internal - If backup fails
#
sub makeBackup # (description?) 
{
	my ($self, $description) = @_;
	my $time = strftime("%F", localtime);
	my $backupdir = EBox::Config::conf . '/backups';
	unless (-d $backupdir) {
		mkdir($backupdir) or throw EBox::Exceptions::Internal
			("Could not create backupdir.");
	}
	unless ($description) {
		my $time = strftime("%F", localtime);
		$description = __('Backup');
	}
	my $filename = $self->_makeBackup($description);
	my $id = int(rand(999999)) . ".tar";
	while (-f "$backupdir/$id") {
		$id = int(rand(999999)) . ".tar";
	}
	copy($filename, "$backupdir/$id") or
		throw EBox::Exceptions::Internal("Could not save the backup.");
	return $filename;
}

#
# Method: makeBugReport
#
#   	Makes a bug report	
#
sub makeBugReport
{
	my $self = shift;
	return $self->_makeBackup('Bug report', 1);
}

# unpacks a backup file into a temporary directory and verifies the md5sum
# arguments:
# 	string: backup file
# returns:
# 	string: path to the temporary directory
sub _unpackAndVerify # (file) 
{
	my ($self, $file) = @_;
	($file) or throw EBox::Exceptions::Internal('No backup file provided.');
	my $tempdir = tempdir(EBox::Config::tmp . "/backup.XXXXXX") or
		throw EBox::Exceptions::Internal("Could not create tempdir.");

	unless (copy($file, "$tempdir/eboxbackup.tar")) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::Internal("Could not copy backup into ".
						 "the tempdir.");
	}

	if (`tar xf $tempdir/eboxbackup.tar -C $tempdir`) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::External(
			__("Could not unpack the backup"));
	}

	unless ( -f "$tempdir/eboxbackup/files.tgz" && 
		 -f "$tempdir/eboxbackup/md5sum") {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::External(
			__('Incorrect or corrupt backup file'));
	}

	unless (open(ARCHIVE, "$tempdir/eboxbackup/files.tgz")) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::Internal("Could not open archive.");
	}
	my $md5 = Digest::MD5->new;
	$md5->addfile(*ARCHIVE);
	my $digest = $md5->hexdigest;
	close(ARCHIVE);

	unless (open(MD5, "$tempdir/eboxbackup/md5sum")) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::Internal("Could not open the md5sum.");
	}
	my $olddigest = <MD5>;
	close(MD5);

	if ($digest ne $olddigest) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::External(
			__('The backup file is corrupt.'));
	}

	return $tempdir;
}

#
# Method: restoreBackup 
#
#   	Restores a backup from file	
#
# Parameters:
#
#       file - backup's file
#
# Exceptions:
#	
#	External - If it can't unpack de backup
#
sub restoreBackup # (file) 
{
	my ($self, $file) = @_;
	my $global = EBox::Global->getInstance();

	my $tempdir = $self->_unpackAndVerify($file);

	if (`tar xzf $tempdir/eboxbackup/files.tgz -C $tempdir/eboxbackup`) {
		`rm -rf $tempdir`;
		throw EBox::Exceptions::External(
			__('Could not unpack the backup'));
	}

	my @names = @{$global->modNames};
	my @restored = ();
	foreach my $modname (@names) {
		try {
			my $mod = $global->modInstance($modname);
			push(@restored,$modname);
			$mod->restoreBackup("$tempdir/eboxbackup");
		} catch EBox::Exceptions::Base with {
			my $ex = shift;
			`rm -rf $tempdir`;
			foreach my $restname (@restored) {
				my $restmod = $global->modInstance($restname);
				$restmod->revokeConfig();
			}
			throw $ex;
		};
	}

	`rm -rf $tempdir`;
}

1;
