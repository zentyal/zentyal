# Copyright (C) 2008-2013 Zentyal S.L.
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

#use Data::Dumper;
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
#use EBox::RemoteServices::Cred;
#use File::Glob ':globally';
use File::Slurp;
#use File::Temp;
#use LWP::UserAgent;
#use URI;
#use HTTP::Status;


use v5.10;

# Constants
#use constant CURL => 'curl';

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Backup> object
#
sub new
{
    my ($class, @params) = @_;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub prepareMakeRemoteBackup
{
    my ($self, $label) = @_;
    $label or throw EBox::Exceptions::MissingArgument('label');

    my @backupOptions = (
        description => $label,
        remoteBackup => $label,
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

    my $res = $self->sendRemoteBackup($archive, $label, $automatic);
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
#                  automatic or not
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
    my $confBackup     = $$self->_confBackupResource();

    my $data = File::Slurp::read_file($archive);
    my $res = $confBackup->add(label => $params{label}, data => $data);
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

sub latestRemoteConfBackup
{
    my ($self) = @_;
    my $confBackup = $self->_confBackupResource();
    my @list = sort {
        $b->{sortableDate} <=> $a->{sortableDate}
    } @{ $confBackup->list() };

    my $last = pop @list;
    return $last;
}

sub _confBackupResource
{
    my $remoteservices = EBox::Global->getInstance()->modInstance('remoteservices');
    my $confBackup     = $remoteservices->confBackupResource();
    return $confBackup;
}

1;

__DATA__

sub _handleResult   # ( HTTP::Response, named params)
{
    my ($res, %params) = @_;

    my $code = $res->code;
    if ($code == HTTP::Status::HTTP_OK) {
        # OK, no need to thow exception
        return;
    } elsif ($code == HTTP::Status::HTTP_NOT_FOUND) {
        throw EBox::Exceptions::Internal(__('Server not found'));
    } elsif ($code == HTTP::Status::HTTP_NO_CONTENT) {
        throw EBox::Exceptions::DataNotFound(
            data => __('Configuration backup'),
            value => $params{fileName}
           );
    } elsif ($code == HTTP::Status::HTTP_BAD_REQUEST) {
        throw EBox::Exceptions::Internal(__('Some argument is missing'));
    } elsif ($code == HTTP::Status::HTTP_INTERNAL_SERVER_ERROR) {
        throw EBox::Exceptions::Internal(__('Internal Server Error'));
    } elsif ($code == HTTP::Status::HTTP_FORBIDDEN) {
        throw EBox::Exceptions::Internal(__('Forbidden request'));
    } else {
        throw EBox::Exceptions::Internal(__('An error has occurred'));
    }
}

sub remoteBackupInfo
{
    my ($self, $uuid) = @_;

    my $allBackups = $self->listRemoteBackups();
    exists $allBackups->{$name} or
      throw EBox::Exceptions::External(
          __x('Inexistent backup: {n}', n => $name)
         );
    return  $allBackups->{$name};
}




# Method: listRemoteBackups
#
#       Get the list of the current remote configuration backups
#
# Returns:
#
#       hash ref - the list of backups indexed by name with the following values:
#
#           Automatic - 1/0 indicating whether the backup is automatic or not
#           Canonical Name - String with the server name
#           Comment - String the description for the backup
#           Date - String the date in printable format
#           sortableDate - Int the date in seconds from epoch
#           Filename - String the backup name
#           Size - Int the size in bytes
#           printableSize - String the size in a printable format
#
sub listRemoteBackups
{
    my ($self) = @_;

    my $metainfo;
    try {
        my $footprint = $self->_pullFootprintMetaConf();
        if ($footprint eq $self->_metainfoFootprint()) {
            $metainfo = $self->_metainfoFromCache();
        } else {
            $metainfo = $self->_metainfoFromServer();
            $self->_setMetainfoFootprint($footprint);
            $self->_setMetainfoCache($metainfo);
        }
    } catch (EBox::Exceptions::DataNotFound $e) {
        # If all.info does not exist, fill fields artificially
        $self->_setMetainfoFootprint('');
        $self->_setMetainfoCache({});
    };

    return $metainfo;
}



# Method: latestRemoteConfBackup
#
#      Get the latest remote configuration backup
#
# Parameters:
#
#      force - Boolean indicating to get the information from Zentyal Remote
#
# Returns:
#
#      String - the date in RFC 2822 format
#
#      'unknown' - if the data is not available
#
sub latestRemoteConfBackup
{
    my ($self, $force) = @_;

    $force = 0 unless (defined($force));

    my ($latest, $bakList) = ('unknown', {});
    if ($force or (not -r $self->_metainfoFile())) {
        $bakList = $self->listRemoteBackups();
    } else {
        $bakList = $self->_metainfoFromCache();
    }
    my @sortedBakList = sort { $b->{sortableDate} <=> $a->{sortableDate} } values %{$bakList};
    if ( @sortedBakList > 0 ) {
        $latest = $sortedBakList[0]->{Date};
    }
    return $latest;
}

# Group: Private methods

sub _metainfoFromServer
{
    my ($self) = @_;

    my $metainfo = {};
    my $metainfoStr = $self->_pullAllMetaConfBackup();

    my @elements = split '\n\s*\n', $metainfoStr;
    foreach my $element (@elements) {
        my %properties;

        my @lines = split '\n', $element;
        foreach my $line (@lines) {
            # The pattern specified is fieldName: fieldValue
            my ($name, $value) = split(':', $line, 2);
            $value or next;

            $value =~ s/^\s+//; # remove suprefluous spaces at the begin
            $properties{$name} = $value;
        }

        if (not exists $properties{Filename}) {
            throw EBox::Exceptions::Internal("Missing 'Filename' field");
        }

        if (exists $properties{Size}) {
            $properties{printableSize} =
              $self->_printableSize($properties{Size});
        }

        if (exists $properties{Date}) {
            $properties{sortableDate} = $self->_sortableDate($properties{Date});
        }

        $metainfo->{$properties{Filename}} = \%properties;
    }

    return $metainfo;
}

sub _metainfoDir
{
    return EBox::Config::conf() . '/remoteservices/conf-backup';
}

sub _createMetainfoDirIfNotExists
{
    my $dir = _metainfoDir();
    if (not -d $dir) {
        if (-e $dir) {
            throw EBox::Exceptions::Internal("PAth $dir exists but is not a directory");
        } else {
            system "mkdir -p $dir";
        }
    }
}

sub _metainfoFile
{
    return _metainfoDir() . '/backup-service-metainfo';
}

sub _metainfoFromCache
{
    my ($self) = @_;

    my $file = $self->_metainfoFile();
    my $metainfoDump = File::Slurp::read_file($file);

    my $VAR1;                   # variable used by  Data::Dumper
    eval $metainfoDump;

    return $VAR1;
}

sub _setMetainfoCache
{
    my ($self, $metainfo) = @_;

    my $file = $self->_metainfoFile();
    my $metainfoDump = Dumper($metainfo);
    $self->_createMetainfoDirIfNotExists();
    return File::Slurp::write_file($file, $metainfoDump);
}

sub _metainfoFootprintFile
{
    return _metainfoDir() . '/backup-service-metainfo.footprint';
}

sub _metainfoFootprint
{
    my ($self) = @_;

    my $file = $self->_metainfoFootprintFile();
    if (not -r $file) {
        return '';
    }

    return File::Slurp::read_file($file);
}

sub _setMetainfoFootprint
{
    my ($self, $footprint) = @_;

    my $file = $self->_metainfoFootprintFile();
    $self->_createMetainfoDirIfNotExists();
    return File::Slurp::write_file($file, $footprint);
}





sub _pullAllMetaConfBackup
{
    my ($self, %p) = @_;

    my $res = $self->{restClient}->GET('/conf-backup/meta/all/', query => \%p, retry => 0);

    _handleResult($res->{result}, %p);

    return $res->as_string();
}

sub _pullFootprintMetaConf
{
    my ($self, %p) = @_;

    my $res = $self->{restClient}->GET('/conf-backup/meta/footprint/', query => \%p, retry => 0);

    _handleResult($res->{result}, %p);

    return $res->as_string();
}

sub _removeConfBackup
{
    my ($self, %p) = @_;

    my $res = $self->{restClient}->DELETE('/conf-backup/meta/' . $p{fileName}, retry => 0);

    _handleResult($res->{result}, %p);
}

# Return the SHA-1 sum for a given file name
sub _digest
{
    my ($self, $file) = @_;

    open(my $fh, '<', $file);
    binmode($fh);

    my $digest = Digest::SHA->new(1)->addfile($fh)->hexdigest();
    close($fh);
    return $digest;
}

1;
