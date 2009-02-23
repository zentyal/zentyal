# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::RemoteServices::ProxyBackup;

# Class: EBox::RemoteServices::ProxyBackup
#
#       Class to manage the proxy backup web service available as web
#       service to those registered users which wants to restore a
#       backup from a non registered eBox
#

use base 'EBox::RemoteServices::Base';

use strict;
use warnings;

use EBox::Backup;
use EBox::Config;
use EBox::Gettext;

use File::Slurp;
use Error qw(:try);

use constant {
    SERV_CONF_FILE => '78remoteservices.conf'
};

# Group: Public methods

# Constructor: new
#
#
# Parameters:
#     user       - String the string to identify the user
#     password   - String used for authenticating the user
#
sub new
{
  my ($class, %params) = @_;
  exists $params{user} or
    throw EBox::Exceptions::MissingArgument('user');
  my $user = $params{user};

  exists $params{password} or
    throw EBox::Exceptions::MissingArgument('password');
  my $password = $params{password};

  my $self = $class->SUPER::new();

  $self->{user} = $user;
  $self->{password} = $password;

  bless $self, $class;
  return $self;
}


sub downloadRemoteBackup
{
  my ($self, $registeredEBox, $backupName) = @_;
  $registeredEBox or throw EBox::Exceptions::MissingArgument('registeredEBox');
  $backupName     or throw EBox::Exceptions::MissingArgument('backupName');


  my $backupData = $self->_pullConfBackup(
					  registeredEBox => $registeredEBox,
					  backupName     => $backupName,
					 );

  my $archive = EBox::Config::tmp() . '/fromProxy.backup';
  File::Slurp::write_file($archive, $backupData);

  return $archive;
}

# Method: restoreRemoteBackup
#
#    restore a remote backup
# 
# Parameters:
#     registeredEBox - name of the eBox which made the backup
#     backupName     - name of the backup itself
sub restoreRemoteBackup
{
  my ($self, $registeredEBox, $backupName) = @_;
  $registeredEBox or throw EBox::Exceptions::MissingArgument('registeredEBox');
  $backupName     or throw EBox::Exceptions::MissingArgument('backupName');

  my $archive = $self->downloadRemoteBackup($registeredEBox, $backupName);

  try {
    EBox::Backup->restoreBackup($archive);
  }
  finally {
    if (-e $archive) {
      unlink $archive;
    }
  };
}

sub prepareRestoreRemoteBackup
{
  my ($self, $registeredEBox, $backupName) = @_;
  $registeredEBox or throw EBox::Exceptions::MissingArgument('registeredEBox');
  $backupName     or throw EBox::Exceptions::MissingArgument('backupName');

  my $archiveFile = $self->downloadRemoteBackup($registeredEBox, $backupName);
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


#  Method: listRemoteBackups
#
#     list all backups available for the authenticted user
#
# XXX this shares a great del of code with
# EBox::RemoteServices::Backup::_metainfoFromServer
sub listRemoteBackups
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
    if (not exists $properties{'Canonical name'}) {
      throw EBox::Exceptions::Internal("Missing 'Canonical name' field");
    }

    my $cname =  $properties{'Canonical name'};
    my $fname =  $properties{'Filename'};

    if (not exists $metainfo->{$cname}) {
      $metainfo->{$cname} = {};
    }

    $metainfo->{$cname}->{$fname} = \%properties;
  }

  return $metainfo;
}


sub remoteBackupInfo
{
  my ($self, $registeredEBox, $backupName) = @_;
  $registeredEBox or throw EBox::Exceptions::MissingArgument('registeredEBox');
  $backupName     or throw EBox::Exceptions::MissingArgument('backupName');

  my $allBackups = $self->listRemoteBackups();

  exists $allBackups->{$registeredEBox} or
    throw EBox::Exceptions::External(
		      __x('No backups in server for host: {h}', h => $registeredEBox)
				      );

  exists $allBackups->{$registeredEBox}->{$backupName} or
    throw EBox::Exceptions::External(
		      __x('Inexistent backup: {n}', n => $backupName)
				      );




  return  $allBackups->{$registeredEBox}->{$backupName};
}


# Method: serviceUrn
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceUrn>
#
sub serviceUrn
{
  my ($self) = @_;

  return 'EBox/Services/RemoteBackupProxy';
}

# Method: serviceHostName
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceHostName>
#
sub serviceHostName
{
  my $host = EBox::Config::configkeyFromFile('ebox_services_www',
                                             EBox::Config::etc() . SERV_CONF_FILE);
  $host or 
    throw EBox::Exceptions::External(
            __('Key for proxy backup service not found')
				    );

  return $host;
}

# Method: soapCall
#
# Overrides:
#
#    <EBox::RemoteServices::Base::soapCall>
#
sub soapCall
{
  my ($self, $method, @params) = @_;

  my $conn = $self->connection();

  return $conn->$method(
			user      => $self->{user},
			password  => $self->{password},
			@params
		       );
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


1;
