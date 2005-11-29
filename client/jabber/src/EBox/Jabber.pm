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

package EBox::Jabber;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::LdapModule EBox::FirewallObserver);

use EBox::Exceptions::DataExists;
use EBox::Gettext;
use EBox::JabberFirewall;
use EBox::JabberLdapUser;
use EBox::Ldap;
use EBox::Menu::Item;
use EBox::Network;
use EBox::Service;
use EBox::Sudo qw ( :all );
use EBox::Summary::Module;
use EBox::Summary::Status;
use EBox::Validate qw ( :all );

use constant JABBERC2SCONFFILE => '/etc/jabberd2/c2s.xml';
use constant JABBERSMCONFFILE => '/etc/jabberd2/sm.xml';
use constant JABBERPORT => '5222';
use constant JABBERPORTSSL => '5223';

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'jabber',
					  domain => 'ebox-jabber',
					  @_);
	bless($self, $class);
	return $self;
}

sub _daemons # (action)
{
	my ($self, $action) = @_;
	
	if ($action eq 'start') {
	      EBox::Service::manage('jabber-router', $action);
	      EBox::Service::manage('jabber-resolver', $action) if ($self->externalConnection);
	      EBox::Service::manage('jabber-sm', $action);
	      EBox::Service::manage('jabber-c2s', $action);
	      EBox::Service::manage('jabber-s2s', $action) if ($self->externalConnection);
	} elsif ($action eq 'stop'){
	      EBox::Service::manage('jabber-s2s', $action);
	      EBox::Service::manage('jabber-c2s', $action);
	      EBox::Service::manage('jabber-sm', $action);
  	      EBox::Service::manage('jabber-resolver', $action);
	      EBox::Service::manage('jabber-router', $action);
	} else {
  	      $self->daemons('stop');
	      $self->daemons('start');
	}

}

sub _doDaemon
{
	my $self = shift;

	if ($self->service and EBox::Service::running('jabber-c2s')) {
		$self->_daemons('restart');
	} elsif ($self->service) {
		$self->_daemons('start');
	} elsif (EBox::Service::running('jabber-c2s')){
		$self->_daemons('stop');
	}
}

sub usesPort # (protocol, port, iface)
{
	my ($self, $protocol, $port, $iface) = @_;

	return undef unless($self->service());

	return 1 if (($port eq JABBERPORT) and !($self->ssl eq 'required'));
	return 1 if (($port eq JABBERPORTSSL) and !($self->ssl eq 'no'));

	return undef;
}

sub firewallHelper
{
	my $self = shift;
	if ($self->service){
		return new EBox::JabberFirewall();
	}
	return undef;
}

# Method: setExternalConnection
#
#       Sets if jabber service has to connect with jabber global network
#
# Parameters:
#
#       enabled - boolean. True, connect with global network. undef, not connect.
#
sub setExternalConnection
{
    my ($self, $external) = @_;
    ($external == $self->externalConnection) and return;
    $self->set_bool('external_connection', $external);
}

# Method: externalConnection
#
#       Returns if jabber service has to connect with 
#         jabber global network
#
# Returns:
#
#       boolean. True, connects. undef, not connects.
sub externalConnection
{
    my $self = shift;
    return $self->get_bool('external_connection');
}

# Method: setSsl
#
#       Sets if jabbers service needs SSL authentication
#
# Parameters:
#
#       ssl - string. 'no' if not needed.
#                     'optional' if ssl auth is optional
#                     'required' if it's mandatory ssl authentication
#
sub setSsl
{
    my ($self, $ssl) = @_;
    ($ssl eq $self->ssl) and return;
    $self->set_string('ssl', $ssl);
}

# Method: ssl
#
#       Returns if jabber service needs SSL authentication
#
# Returns:
#
#       string - 'no' if not needed.
#                'optional' if ssl auth is optional
#                'required' if it's mandatory ssl authentication
sub ssl
{
    my $self = shift;
    return $self->get_string('ssl');
}

# Method: setService
#
#       Sets the jabber service as enabled or disabled
#
# Parameters:
#
#       enabled - boolean. True, enable. undef, disable.
#
sub setService
{
	my ($self, $active) = @_;
	($active and $self->service) and return;
	(!$active and !$self->service) and return;

	if ($active) {
		if (not $self->service){
			my $fw = EBox::Global->modInstance('firewall');
			my $port = JABBERPORT;
			unless ($fw->availablePort('tcp', $port) and
				$fw->availablePort('udp', $port)){
					throw EBox::Exceptions::DataExists(
						'data' => __('listening port'),
						'value' => $port);
				}
		}
	}
	$self->set_bool('active', $active);
}

# Method: service
#
#       Returns if the jabber service is enabled
#
# Returns:
#
#       boolean. True enabled, undef disabled
sub service
{
	my $self = shift;
	return $self->get_bool('active');
}

# Method: setDomain
#
#       Sets the domain for jabber service. Accounts would have
#          user@domain format
#
# Parameters:
#
#       domain - string with the domain name
#
sub setDomain
{
	my ($self, $domain) = @_;
	unless (checkDomainName($domain)){
		throw EBox::Exceptions::InvalidData
			('data' => __('domain'), 'value' => $domain);
	}
	($domain eq $self->domain) and return;
	$self->set_string('domain', $domain);
}

# Method: domain
#
#       Returns current jabber service domain
#
# Returns:
#
#       string. Current jabber service domain 
sub domain
{
	my $self = shift;
	return $self->get_string('domain');
}

# Method: _regenConfig
#
#       Overrides base method. It regenerates the jabber service configuration
#
sub _regenConfig
{
	my $self = shift;

	$self->_setJabberConf;
	$self->_doDaemon();
}

sub _setJabberConf
{
	my $self = shift;
	my @array = ();

	my $net = EBox::Global->modInstance('network');
	my $ldap = new EBox::Ldap;
	my $ldapconf = $ldap->ldapConf;
	my $jabberldap = new EBox::JabberLdapUser;

	push (@array, 'domain' => $self->domain);
	push (@array, 'binddn' => $ldapconf->{'rootdn'});
	push (@array, 'bindpw' => $ldap->rootPw);
	push (@array, 'basedc' => $ldapconf->{'dn'});
	push (@array, 'ssl' => $self->ssl);

	$self->writeConfFile(JABBERC2SCONFFILE,
			     "jabber/c2s.xml.mas",
			     \@array);

	@array = ();

	my @admins = ();
	@admins = $jabberldap->getJabberAdmins();
	push (@array, 'domain' => $self->domain);
	push (@array, 'admins' => \@admins);
	$self->writeConfFile(JABBERSMCONFFILE,
			     "jabber/sm.xml.mas",
			     \@array);
}

sub statusSummary
{
	my $self = shift;
	return new EBox::Summary::Status('jabber', __('Jabber'),
		EBox::Service::running('jabber-c2s'), $self->service);
}

# Method: rootCommands
#
#       Overrides EBox::Module method.
sub rootCommands
{
	my $self = shift;
	my @array = ();
	push(@array, $self->rootCommandsForWriteConfFile(JABBERC2SCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(JABBERSMCONFFILE));
	return @array;
}

# Method: menu
#
#       Overrides EBox::Module method.
sub menu
{
	my ($self, $root) = @_;
	$root->add(new EBox::Menu::Item('url' => 'Jabber/Index',
					'text' => __('Jabber Service')));
}

sub _ldapModImplementation
{
    my $self;

    return new EBox::JabberLdapUser();
}
1;
