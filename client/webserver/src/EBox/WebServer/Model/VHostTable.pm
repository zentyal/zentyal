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

# Class:
#
#   EBox::WebServer::Model::VHostTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   virtual host table which basically contains virtual hosts information.
#
package EBox::WebServer::Model::VHostTable;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Global;
use EBox::Types::Boolean;
use EBox::Types::Text;
use EBox::Types::Select;
use EBox::Validate;

####################
# Dependencies
####################
use Perl6::Junction qw(none);
use Error qw(:try);

# Group: Public methods

# Constructor: new
#
#       Create the new VHostTable model.
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::WebServer::Model::VHostTable> - the recently
#       created model.
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
#      domain.
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the name is not
#      valid.
#
sub validateTypedRow
{
    my ($self, $action, $changedFields) = @_;

    if (exists $changedFields->{name}) {
        my $vhost =  $changedFields->{name}->value();
        EBox::Validate::checkDomainName(
                                       $vhost,
                                        __(q{Virtual host name})
                                       );
        if ($vhost eq 'default' or $vhost eq 'default-ssl') {
            throw EBox::Exceptions::InvalidData
                ('data' => __('Virtual host'), 'value' => $vhost);
        }
    }

    if (exists $changedFields->{ssl}) {
        # SSL checking
        my $settings = $self->parentModule()->model('GeneralSettings');
        if (($changedFields->{ssl}->value() ne 'disabled') and
            ($settings->row()->elementByName('ssl')->selectedType() eq 'ssl_disabled')) {
            throw EBox::Exceptions::External(
                __('SSL support is disabled. Enable it before adding a SSL virtual host.'));
        }
    }
}

# Method: addedRowNotify
#
#      Call whenever a new row is added. It adds a new domain to the
#      DNS subsystem when a new virtual host is added.
#
# Overrides:
#
#      <EBox::Model::DataTable::addedRowNotify>
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

    my $hostName;
    my $domain;
    my $vHostName = $row->valueByName('name');
    my @parts = split(/\./, $vHostName);
    if (@parts == 1) { # if no dots, only a domain = hostname
        $hostName = $vHostName;
        $domain = $vHostName;
    } else { # If we have dots, last two parts for the domain, rest hostname
        my $tld = pop(@parts);
        my $topdomain = pop(@parts);
        $domain = "$topdomain.$tld";
        $hostName = join('.', @parts);
        $hostName = $domain unless $hostName; # If hostName is empty, then = domain
    }

    return unless ($hostName or $domain);

    # We try to guess the IP address
    my $ip = $self->_guessWebIPAddr();
    if ( $ip ) {
        if ( none(map { $_->{name} } @{$dns->domains()}) eq $domain ) {
            # The domain does not exist, add domain with hostname-ip mapping
            my $domainData;
            if ($hostName eq $domain) {
                $domainData = {
                               domain_name => $domain,
                               ipaddr => $ip,
                              };
            } else {
                $domainData = {
                               domain_name => $domain,
                               hostnames => [ { hostname => $hostName, ip => $ip,}, ],
                              };
            }
            $dns->addDomain($domainData);

            my $noDnsWarning = $self->_dnsNoActiveWarning();

            $self->setMessage(__x('Virtual host {vhost} added. A domain {domain} ' .
                                  'has been created with the mapping ' .
                                  'name {name} - IP address {ip}. {noDnsWarning} ',
                                  vhost => $vHostName,
                                  domain => $domain,
                                  name   => $hostName,
                                  ip     => $ip,
                                  noDnsWarning => $noDnsWarning,
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
                                          'to {domain} domain.',
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
                                              . ' to hostname {hostname}.',
                                              vhost    => $vHostName,
                                              alias    => $hostName,
                                              hostname => $oldHostName));
                    } catch EBox::Exceptions::DataExists with {
                        $self->setMessage(__x('Virtual host {vhost} added.',
                                              vhost => $vHostName));
                    }
                }
            } else {
                $self->setMessage(__x('Virtual host {vhost} added.',
                                      vhost => $vHostName));
            }
        }
    } else { # No valid internal IP address
        $self->setMessage(__('There is no static internal interface to ' .
                             'set the Web server IP address.'));
    }
}

# Method: getWebServerSAN
#
#      Get a list of virtual host that have SSL enabled.
#
# Returns:
#
#      array ref - containing the list of SSL enabled virtual hosts.
#
sub getWebServerSAN
{
    my ($self) = @_;

    my @vhosts;
    foreach my $vhost (@{$self->ids()}) {
        my $row = $self->row($vhost);
        if ($row->valueByName('ssl') ne 'disabled') {
            my $vhostname = $row->valueByName('name');
            push(@vhosts, $vhostname);
        }
    }

    return \@vhosts;
}

# Group: Protected methods

sub _populateSSLsupport
{
    my @options = (
                       { value => 'disabled' , printableValue => __('Disabled')},
                       { value => 'allowssl', printableValue => __('Allow SSL')},
                       { value => 'forcessl', printableValue => __('Force SSL')},
                  );
    return \@options;
}


# Method: _table
#
#       The table description which consists of a couple of fields:
#
#       enabled     - <EBox::Types::Boolean>
#       name        - <EBox::Types::Text>
#       ssl         - <EBox::Types::Select>
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
         new EBox::Types::Select(
                                fieldName     => 'ssl',
                                printableName => __('SSL support'),
                                editable      => 1,
                                populate => \&_populateSSLsupport,
                                defaultValue => 'disabled'
                             ),
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
                                  . 'many instances of the same web server are hosted on a '
                                  . 'single physical server. Different host names point '
                                  . 'to the same web server. If feasible, the DNS entry is automatically created. '
                                  . 'The content must be placed under the '
                                  . '{docRoot} directory. Any particular configuration '
                                  . 'you want to add must be placed in the {userConf} directory.',
                                 docRoot => EBox::WebServer::PlatformPath::VDocumentRoot() . '/vHostName',
                                 userConf => EBox::WebServer::PlatformPath::ConfDirPath()
                                   . '/sites-available/user-ebox-vHostName'),
       printableRowName    => __('Virtual host'),
       modelDomain         => 'WebServer',
       sortedBy            => 'name',
       enableProperty      => 1,
       defaultEnabledValue => 1,
      };

    return $dataTable;
}

# Group: Private methods

sub _dnsNoActiveWarning
{
    my ($self) = @_;
    my $dns = EBox::Global->modInstance('dns');
    if ($dns->isEnabled()) {
        return '';
    }

    return __x(
'{open}The DNS module is disabled. The added mapping or domains will not have any effect until you enable it',
       open => q{<br/></div><div class='warning'>}, # attentions to the close
                                                    # div trick!
        );
}

# Method: _table
#
#    Guess the IP address to assign in the mapping name - IP. It gets the
#    first static internal interface address if any, then check if there
#    is any static external interface to get the address. If there is no
#    static interfaces, empty string is returned.
#
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
