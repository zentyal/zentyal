# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::RemoteServices::DisasterRecoveryProxy;

# Class: EBox::RemoteServices::DisasterRecoveryProxy
#
#       Class to manage the proxy disaster recovery web service
#       available as web service to those registered users which wants
#       to restore a backup from a non registered Zentyal server
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


# Method: serviceUrn
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceUrn>
#
sub serviceUrn
{
  my ($self) = @_;

  return 'Zentyal/Cloud/DisasterRecoveryProxy';
}

# Method: credentials
#
#    Get the credentials for restoring your backed up data
#
# Parameters:
#
#    commonName - String the Zentyal server name
#
#    - Named parameters
#
# Returns:
#
#    See <EBox::RemoteServices::DisasterRecovery::credentials>
#
sub credentials
{
    my ($self, @p) = @_;

    return $self->soapCall('credentials', @p);

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
            __('Key for disaster recovery service not found')
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

1;
