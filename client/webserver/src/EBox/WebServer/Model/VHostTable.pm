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

# Class:
#
#   EBox::WebServer::Model::VHostTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   virtual host table which basically contains virtual host's name
#
package EBox::WebServer::Model::VHostTable;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::InvalidData;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Boolean;
use EBox::Types::Text;
use EBox::Validate;

####################
# Dependencies
####################
use Perl6::Junction qw(none);
use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#       Create the new VHostTable model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::WebServer::Model::VHostTable> - the recently
#       created model
#
sub new
  {
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: validateTypedRow
#
#      Check the row to add or update if the name contain a valid
#      domain
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the name is not
#      valid
#

sub validateTypedRow
{
  my ($self, $action, $changedFields) = @_;

  if ( exists $changedFields->{name} ) {
      EBox::Validate::checkDomainName(
                                      $changedFields->{name}->value(),
                                      __(q{Virtual host's name})
                                     );
  }

}

# Method: addedRowNotify
#
#      Call whenever a new row is added. It adds a new domain to the
#      DNS subsystem when a new virtual host is added
#
# Overrides:
#
#      <EBox::Model::DataTable::addedRowNotify>
#
#
sub addedRowNotify
{
    my ($self, $row) = @_;

    # Get the DNS module
    my $gl = EBox::Global->getInstance();
    if (not  $gl->modExists('dns') ) {
        # no DNS module present, nothing to add then
        return;
    }

    my $dns = $gl->modInstance('dns');

    my $vHostName = $row->{plainValueHash}->{name};
    my ($hostName, $domain) = ( $vHostName =~ m/^(.*?)\.(.*)/g );

    # We try to guess the IP address
    my $ip = $self->_guessWebIPAddr();
    if ( $ip ) {
        if ( none(map { $_->{name} } @{$dns->domains()}) eq $domain ) {
            # The domain does not exist, add domain with hostname-ip mapping
            my $domainData = {
                              domain_name => $domain,
                              hostnames => [
                                            {
                                             hostname => $hostName,
                                             ip       => $ip,
                                            },
                                           ],
                             };
            $dns->addDomain($domainData);

            $self->setMessage(__x('Virtual host {vhost} added. A domain {domain} ' .
                                  'has been created with the mapping ' .
                                  'name {name} - IP address {ip} ',
                                  vhost => $vHostName,
                                  domain => $domain,
                                  name   => $hostName,
                                  ip     => $ip
                                 ));
        } else {
            my @hostNames = @{$dns->getHostnames($domain)};
            if ( none(map { $_->{name} } @hostNames ) eq $hostName ) {
                # Check the IP address
                my ($commonHostName) = grep { $_->{ip} eq $ip } @hostNames;
                unless ( $commonHostName ) {
                    # Add a host name
                    $dns->addHostName( $domain,
                                       hostname => $hostName,
                                       ipaddr => $ip);
                    $self->setMessage(__x('Virtual host {vhost} added. A mapping ' .
                                          'name {name} - IP address {ip} has been added ' .
                                          'to {domain} domain',
                                          vhost  => $vHostName,
                                          name   => $hostName,
                                          ip     => $ip,
                                          domain => $domain,
                                         ));
                } else {
                    # Add an alias
                    my $oldHostName = $commonHostName->{name};
                    try {
                        $dns->addAlias( "/$domain/$oldHostName",
                                        alias => $hostName);
                        $self->setMessage(__x('Virtual host {vhost} added as an alias {alias}'
                                              . ' to hostname {hostname}',
                                              vhost    => $vHostName,
                                              alias    => $hostName,
                                              hostname => $oldHostName));
                    } catch EBox::Exceptions::DataExists with {
                        $self->setMessage(__x('Virtual host {vhost} added',
                                              vhost => $vHostName));
                    }
                }
            } else {
                $self->setMessage(__x('Virtual host {vhost} added',
                                      vhost => $vHostName));
            }
        }
    } else {
        $self->setMessage(__('There is no static internal interface to ' .
                             'set the Web server IP address'));
    }

}

# Group: Protected methods

# Method: _table
#
#       The table description which consists of a couple of fields:
#
#       name        - <EBox::Types::Text>
#       enabled     - <EBox::Types::Boolean>
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
#
sub _table
{
    my @tableHead =
        (
         new EBox::Types::Text(
                                fieldName     => 'name',
                                printableName => __('Name'),
                                size          => 12,
                                unique        => 1,
                                editable      => 1,
                             ),
        );

    my $dataTable =
      {
       tableName           => 'VHostTable',
       printableTableName  => __('Virtual hosts'),
       defaultActions      => ['add', 'del', 'editField',  'changeView' ],
       tableDescription    => \@tableHead,
       class               => 'dataTable',
       help                => __x('Virtual hosts are a form of web hosting service where '
                                  . 'many instances of the same web server is hosted on a '
                                  . 'single physical server. Different host names will point '
                                  . 'to the same web server. The DNS entry is automatically created'
                                  . ' if this is possible. The content must be placed under '
                                  . '{docRoot}/vHostName directory',
                                 docRoot => EBox::WebServer::PlatformPath::DocumentRoot()),
       printableRowName    => __('virtual host'),
       modelDomain         => 'WebServer',
       sortedBy            => 'name',
       enableProperty      => 1,
       defaultEnabledValue => 1,
      };

    return $dataTable;
}

# Group: Private methods

# Guess the IP address to assign in the mapping name - IP. It gets the
# first static internal interface address if any, then check if there
# is any static external interface to get the address. If there is no
# static interfaces, empty string is returned
sub _guessWebIPAddr
{
    my ($self) = @_;

    my $netMod = EBox::Global->modInstance('network');

    my @ifaces = @{$netMod->ifaces()};

    @ifaces = grep { $netMod->ifaceMethod($_) eq 'static' } @ifaces;

    return '' unless (@ifaces > 0);

    my @intIfaces = grep { not $netMod->ifaceIsExternal($_) } @ifaces;

    if ( @intIfaces > 0 ) {
        return $netMod->ifaceAddress($intIfaces[0]);
    }

    my @extIfaces = grep { $netMod->ifaceIsExternal($_) } @ifaces;

    return $netMod->ifaceAddress($extIfaces[0]);


}

1;

