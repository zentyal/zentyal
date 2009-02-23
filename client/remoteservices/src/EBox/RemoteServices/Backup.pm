# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::RemoteServices::Backup;
use base 'EBox::RemoteServices::Auth';
#

use strict;
use warnings;

use EBox::Backup;
use EBox::Config;
use EBox::Exceptions::DataNotFound;

use File::Glob ':globally';
use File::Slurp;
use File::Temp;
use Data::Dumper;
use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#     Construct a new <EBox::RemoteServices::Backup> object
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

sub prepareMakeRemoteBackup
{
    my ($self, $name, $description) = @_;
    $name or throw EBox::Exceptions::MissingArgument('name');
    defined $description or $description = '';


    my @backupOptions = (
        fullBackup => 0,
        description => $description,
        remoteBackup => $name,
       );

    return EBox::Backup->prepareMakeBackup(@backupOptions);
}

sub makeRemoteBackup
{
    my ($self, $name, $description) = @_;
    $name or throw EBox::Exceptions::MissingArgument('name');
    defined $description or $description = '';

    my @backupOptions = (
        fullBackup => 0,
        description => $description,
       );

    my $archive = EBox::Backup->makeBackup(@backupOptions);

    sendRemoteBackup($archive, $name, $description);
}


sub sendRemoteBackup
{
    my ($self, $archive, $name, $description) = @_;
    $archive or throw EBox::Exceptions::MissingArgument('archive');
    $name    or throw EBox::Exceptions::MissingArgument('name');
    defined $description or $description = '';

    try {
        my $archiveContents = File::Slurp::read_file($archive);
        $self->_pushConfBackup(file => $archiveContents,
                               fileName => $name,
                               comment => $description);
    }
    finally {
        unlink $archive;
    };
}

sub restoreRemoteBackup
{
    my ($self, $name) = @_;
    $name or throw EBox::Exceptions::MissingArgument('name');

    my $archiveFile = $self->downloadRemoteBackup($name);

    try {
        EBox::Backup->restoreBackup($archiveFile);
    }
      finally {
          if (-e $archiveFile) {
              unlink $archiveFile;
          }
      };
}


sub prepareRestoreRemoteBackup
{
    my ($self, $name) = @_;
    $name or throw EBox::Exceptions::MissingArgument('name');

    my $archiveFile = $self->downloadRemoteBackup($name);
    my $progress;

    try {
        $progress = EBox::Backup->prepareRestoreBackup(
            $archiveFile, 
            fullRestore => 0,
            deleteBackup => 1,
           );
    }
      otherwise {
          my $ex = shift;
          unlink $archiveFile;
          $ex->throw();
      };

    return $progress;
}

sub downloadRemoteBackup
{
    my ($self, $name) = @_;
    $name or throw EBox::Exceptions::MissingArgument('name');

    my $archiveContents = $self->_pullConfBackup(fileName => $name);

    my ($fh, $archiveFile) = File::Temp::tempfile(
        DIR => EBox::Config::tmp(),
        SUFFIX => '.backup',
       );

    try {
        print $fh $archiveContents;
        close $fh or
          throw EBox::Exceptions::Internal("Error closing $archiveFile: $!");
    }
      otherwise {
          my $ex = shift;

          if (-e $archiveFile) {
              unlink $archiveFile;
          }

          $ex->throw();
      };

    return $archiveFile;
}


sub removeRemoteBackup
{
    my ($self, $name) = @_;
    $name or throw EBox::Exceptions::MissingArgument('name');

    $self->_removeConfBackup(fileName => $name);
}

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
    } catch EBox::Exceptions::DataNotFound with {
        # If all.info does not exist, fill fields artifially
        $self->_setMetainfoFootprint('');
        $self->_setMetainfoCache({});
    };

    return $metainfo;
}

sub remoteBackupInfo
{
    my ($self, $name) = @_;

    my $allBackups = $self->listRemoteBackups();
    exists $allBackups->{$name} or
      throw EBox::Exceptions::External(
          __x('Inexistent backup: {n}', n => $name)
         );
    return  $allBackups->{$name};
}

# Group: Protected methods

# Method: _serviceUrnKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceUrnKey>
#
sub _serviceUrnKey
{
    return 'backupServiceUrn';
}

# Method: _serviceHostNameKey
#
# Overrides:
#
#     <EBox::RemoteServices::Auth::_serviceHostNameKey>
#
sub _serviceHostNameKey
{
    return 'backupServiceProxy';
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


        $metainfo->{$properties{Filename}} = \%properties;
    }

    return $metainfo;
}

sub _printableSize
{
    my ($self, $size) = @_;

    my @units = qw(KB MB GB);
    foreach my $unit (@units) {
        $size = sprintf ("%.2f", $size / 1024);
        if ($size < 1024) {
            return "$size $unit";
        }
    }
    
    return $size . ' ' . (pop @units);
}


sub _metainfoFile
{
    return EBox::Config::tmp() . '/backup-service-metainfo';
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
    return File::Slurp::write_file($file, $metainfoDump);
}

sub _metainfoFootprintFile
{
    return EBox::Config::tmp() . '/backup-service-metainfo.footprint';
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
    return File::Slurp::write_file($file, $footprint);

}

sub _pushConfBackup
{
    my ($self, @p) = @_;
    return $self->soapCall('pushConfBackup', @p);
}

sub _pullConfBackup
{
    my ($self, @p) = @_;
    return $self->soapCall('pullConfBackup', @p);
}


sub _pullAllMetaConfBackup
{
    my ($self, @p) = @_;
    return $self->soapCall('pullAllMetaConfBackup', @p);
}

sub _pullFootprintMetaConf
{
    my ($self, @p) = @_;
    return $self->soapCall('pullFootprintMetaConf', @p);
}

sub _removeConfBackup
{
    my ($self, @p) = @_;
    return $self->soapCall('removeConfBackup', @p);
}

1;
