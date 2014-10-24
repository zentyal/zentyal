# Copyright (C) 2008-2014 Zentyal S.L.
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
use strict;
use warnings;

package EBox::RemoteServices::Backup;


use Digest::SHA;
use TryCatch::Lite;
use EBox::Backup;
use EBox::Config;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use File::Slurp;


use v5.10;

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Backup> object
#
sub new
{
    my ($class, %params) = @_;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub prepareMakeRemoteBackup
{
    my ($self, $label) = @_;
    $label or throw EBox::Exceptions::MissingArgument('label');

    my @backupOptions = (
        description  => $label,
        remoteBackup => 1,
    );

    return EBox::Backup->prepareMakeBackup(@backupOptions);
}

# Method: makeRemoteBackup
#
#      Make a configuration backup and send it to Zentyal Cloud
#
# Parameters:
#
#      name - String the backup's name
#
#      description - String the backup's description
#
#      automatic - Boolean indicating whether the backup must be set as
#                  automatic or not
#
# Exceptions:
#
#      <EBox::Exceptions::Internal> - the backup process fails
#
#      <EBox::Exceptions::InvalidData> - the backup file is corrupted
#
sub makeRemoteBackup
{
    my ($self, $label, $automatic) = @_;

    $label or throw EBox::Exceptions::MissingArgument('label');

    my @backupOptions = (
        description  => $label,
        fallbackToRO => $automatic,
       );

    my $archive = EBox::Backup->makeBackup(@backupOptions);
    $self->sendRemoteBackup($archive, $label, $automatic);
}

# Method: sendRemoteBackup
#
#      Send a configuration backup to Zentyal Remote
#
# Parameters:
#
#      archive - String the path to the configuration backup archive
#
#      name - String the backup's name
#
#      description - String the backup's description
#
#      automatic - Boolean indicating whether the backup must be set as
#                  automatic or not. Optional. Default value: false
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown when the upload is corrupted
#                                        (Checksums mismatch)
#
sub sendRemoteBackup
{
    my ($self, $archive, $label, $automatic) = @_;
    $label    or throw EBox::Exceptions::MissingArgument('label');
    defined $automatic or $automatic = 0;

#    my $digest = $self->_digest($archive);

   my $res;
    try {
        $res = $self->_pushConfBackup($archive,
                               label     => $label,
                               automatic => $automatic,
                              );
#                               digest    => $digest);
        $self->setLatestRemoteConfBackup($res->{backup_date});
    } catch ($e) {
        unlink $archive;
        $e->throw();
    }
    unlink $archive;

    return $res;
}

sub _pushConfBackup
{
    my ($self, $archive, %params) = @_;

#    my $checksum = delete $p{digest};
    my $confBackup     = $self->_confBackupResource();

    my $data = File::Slurp::read_file($archive);
    my $res = $confBackup->add(label => $params{label},
                               data => $data,
                               automatic => $params{automatic});
    return $res;
}

# Restore remote configuration backup
sub restoreRemoteBackup
{
    my ($self, $uuid) = @_;
    $uuid or throw EBox::Exceptions::MissingArgument('uuid');

    my $archiveFile = $self->downloadRemoteBackup($uuid);

    try {
        EBox::Backup->restoreBackup($archiveFile);
    } catch ($e) {
        unlink ($archiveFile) if (-e $archiveFile);
        $e->throw();
    }
    unlink ($archiveFile) if (-e $archiveFile);
}


sub prepareRestoreRemoteBackup
{
    my ($self, $uuid) = @_;
    $uuid or throw EBox::Exceptions::MissingArgument('uuid');

    my $archiveFile = $self->downloadRemoteBackup($uuid);
    my $progress;

    try {
        $progress = EBox::Backup->prepareRestoreBackup(
            $archiveFile,
            deleteBackup => 1,
        );
    } catch ($e) {
        unlink($archiveFile);
        $e->throw();
    }

    return $progress;
}

# Return the configuration backup file path
sub downloadRemoteBackup
{
    my ($self, $uuid, $fh) = @_;
    $uuid or throw EBox::Exceptions::MissingArgument('uuid');

    my $archive = $self->_pullConfBackup(uuid => $uuid,
                                         fh => $fh);
    return $archive;
}

# Method: _pullConfBackup
#
#     Pull the configuration backup from Zentyal Cloud
#
# Named parameters:
#
#    fileName - String the file name to retrieve
#    fh       - Filehandle if given, then the conf backup is written there
#
# Returns:
#
#    String - the path to the configuration backup if fh is not given
#
#    undef  - otherwise
#
sub _pullConfBackup
{
    my ($self, %params) = @_;

    my $confBackup  = $self->_confBackupResource();

    my $contents = $confBackup->get($params{uuid});
    if ( exists $params{fh} and defined $params{fh} ) {
        my $fh = $params{fh};
        File::Slurp::write_file($fh, $contents);
    } else {
        my $outFile = EBox::Config::tmp() . 'pull-conf.backup';
        File::Slurp::write_file($outFile, $contents);
        return $outFile;
    }
}

sub remoteBackupInfo
{
    my ($self, $uuid) = @_;

    my $confBackup = $self->_confBackupResource();
    my @list = @{$confBackup->list()};
    foreach my $entry (@list) {
        if ($entry->{uuid} eq $uuid) {
            return $entry;
        }
    }
    return undef;
}

sub removeRemoteBackup
{
    my ($self, $uuid) = @_;
    $uuid or throw EBox::Exceptions::MissingArgument('uuid');

    my $confBackup = $self->_confBackupResource();
    $confBackup->delete($uuid);
}


sub setLatestRemoteConfBackup
{
    my ($self, $date) = @_;
    my $remoteservices = EBox::Global->getInstance(1)->modInstance('remoteservices');
    my $state = $remoteservices->get_state();
    if ($date) {
        $state->{latest_backup_date} = $date;
    } else {
        delete $state->{latest_backup_date};
    }

    $remoteservices->set_state($state);
}

sub latestRemoteConfBackup
{
    my ($self) = @_;
    my $remoteservices = EBox::Global->getInstance(1)->modInstance('remoteservices');
    return $remoteservices->get_state()->{latest_backup_date};
}

sub _confBackupResource
{
    my ($self) = @_;
    my $remoteservices = EBox::Global->getInstance(1)->modInstance('remoteservices');
    my $confBackup     = $remoteservices->confBackupResource();
    return $confBackup;
}

1;
