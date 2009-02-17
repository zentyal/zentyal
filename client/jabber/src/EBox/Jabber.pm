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

use base qw(EBox::Module::Service 
			EBox::LdapModule 
			EBox::FirewallObserver
			);

use EBox::Exceptions::DataExists;
use EBox::Gettext;
use EBox::JabberFirewall;
use EBox::JabberLdapUser;
use EBox::Ldap;
use EBox::Menu::Item;
use EBox::Network;
use EBox::Service;
use EBox::Sudo qw ( :all );
use EBox::Validate qw ( :all );

use constant JABBERC2SCONFFILE => '/etc/jabberd2/c2s.xml';
use constant JABBERSMCONFFILE => '/etc/jabberd2/sm.xml';
use constant JABBERPORT => '5222';
use constant JABBERPORTSSL => '5223';
use constant JABBEREXTERNALPORT => '5269';

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'jabber',
					  domain => 'ebox-jabber',
					  printableName => 'jabber',
					  @_);
	bless($self, $class);
	return $self;
}

sub domain
{
	return "ebox-jabber";
}


# Method: actions
#
# 	Override EBox::Module::Service::actions
#
sub actions
{
	return [ 
	{
		'action' => __('Copy jabber ldap schema to /etc/ldap/schemas'),
		'reason' => __('eBox will need this schema to store jabber users'),
		'module' => 'jabber'
	},

    ];
}

# Method: usedFiles
#
#	Override EBox::Module::Service::usedFiles
#
sub usedFiles
{
	return [
		{
		 'file' => JABBERC2SCONFFILE,
		 'module' => 'jabber',
 	 	 'reason' => __('To properly configure jabberd2')
		},
		{
		 'file' => JABBERSMCONFFILE,
		 'module' => 'jabber',
 	 	 'reason' => __('To properly configure jabberd2')
		},
		{
		 'file' => '/etc/ldap/slapd.conf',
		 'reason' => __('To add the LDAP schemas used by eBox jabber'),
		 'module' => 'users'
		} 
       ];
}
# Method: enableActions 
#
# 	Override EBox::Module::Service::enableActions
#
sub enableActions
{
    root(EBox::Config::share() . '/ebox-jabber/ebox-enable-jabber');
}

#  Method: _daemons
#
#   Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'ebox.jabber.jabber-router'
        },
        {
            'name' => 'ebox.jabber.jabber-resolver',
            'precondition' => \&externalConnection
        },
        {
            'name' => 'ebox.jabber.jabber-sm'
        },
        {
            'name' => 'ebox.jabber.jabber-c2s'
        },
        {
            'name' => 'ebox.jabber.jabber-s2s',
            'precondition' => \&externalConnection
        }
    ];
}

sub usesPort # (protocol, port, iface)
{
	my ($self, $protocol, $port, $iface) = @_;

	return undef unless($self->isEnabled());

	return 1 if (($port eq JABBERPORT) and !($self->ssl eq 'required'));
	return 1 if (($port eq JABBERPORTSSL) and !($self->ssl eq 'no'));
	return 1 if (($port eq JABBEREXTERNALPORT) and ($self->externalConnection));

	return undef;
}

sub firewallHelper
{
	my $self = shift;
	if ($self->isEnabled){
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

# Method: setJabberDomain
#
#       Sets the domain for jabber service. Accounts would have
#          user@domain format
#
# Parameters:
#
#       domain - string with the domain name
#
sub setJabberDomain
{
	my ($self, $domain) = @_;
	unless (checkDomainName($domain)){
		throw EBox::Exceptions::InvalidData
			('data' => __('domain'), 'value' => $domain);
	}
	($domain eq $self->jabberDomain) and return;
	$self->set_string('domain', $domain);
}

# Method: jabberDomain
#
#       Returns current jabber service domain
#
# Returns:
#
#       string. Current jabber service domain 
sub jabberDomain
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
	$self->_enforceServiceState();
}

sub _setJabberConf
{
	my $self = shift;
	my @array = ();

	my $net = EBox::Global->modInstance('network');
	my $ldap = EBox::Ldap->instance();
	my $ldapconf = $ldap->ldapConf;
	my $jabberldap = new EBox::JabberLdapUser;

	push (@array, 'domain' => $self->jabberDomain);
	push (@array, 'binddn' => $ldapconf->{'rootdn'});
	push (@array, 'bindpw' => $ldap->rootPw);
	push (@array, 'basedc' => $ldapconf->{'dn'});
	push (@array, 'ssl' => $self->ssl);

	$self->writeConfFile(JABBERC2SCONFFILE,
			     "jabber/c2s.xml.mas",
			     \@array, { 'uid' => 0, 'gid' => 0, mode => '600' });

	@array = ();

	my @admins = ();
	@admins = $jabberldap->getJabberAdmins();
	push (@array, 'domain' => $self->jabberDomain);
	push (@array, 'admins' => \@admins);
	$self->writeConfFile(JABBERSMCONFFILE,
			     "jabber/sm.xml.mas",
			     \@array);
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
