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

package EBox::LDAP::ExternalAD;
use base 'EBox::Ldap';

use EBox::Global;
use EBox::Sudo;
use EBox::Gettext;
use EBox::Validate;
use TryCatch::Lite;
use Net::DNS::Resolver;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::UnwillingToPerform;

use Net::LDAP;
use Net::Ping;
use Net::DNS;
use Net::NTP qw(get_ntp_response);
use Authen::Krb5::Easy qw{kinit_pwd kdestroy kerror kinit kcheck};
use File::Basename;
use Authen::SASL;

# Singleton variable
my $_instance = undef;

sub _new_instance
{
    my $class = shift;

    my $self = {};
    bless($self, $class);
    $self->clearConn();

    return $self;
}

# Method: instance
#
#   Return a singleton instance of class <EBox::LDAP::ExternalAD>
#
# Returns:
#
#   object of class <EBox::LDAP::ExternalAD>
sub instance
{
    my ($self, %opts) = @_;
    $opts{dcHostname} or throw EBox::Exceptions::MissingArgument('dcHostname');
    $opts{user}       or throw EBox::Exceptions::MissingArgument('user');
    $opts{password}   or throw EBox::Exceptions::MissingArgument('password');

    unless(defined($_instance)) {
        $_instance = __PACKAGE__->_new_instance();
    };

    $_instance->{dcHostname} = $opts{dcHostname};
    $_instance->{user}       = $opts{user};
    $_instance->{password}   = $opts{password};

    return $_instance;
}

# Method: dcHostname
#
# Returns:
#
#   Domain controller hostname
#
sub dcHostname
{
    my ($self) = @_;

    return $self->{dcHostname};
}

# Method: getPassword
#
# Returns:
#
#   Password of the configured AD administrative user
#
sub getPassword
{
    my ($self) = @_;

    return $self->{password};
}

# Method: _adUser
#
# Returns:
#
#   User for bind to LDAP
#
sub _adUser
{
    my ($self) = @_;

    my $user = $self->{user};
    $user or throw EBox::Exceptions::Internal('user attribute not defined');

    return $user;
}

# Method: userBindDN
#
#  Overrides:
#
#   <EBox::Ldap::userBindDN>
#
sub userBindDN
{
    my ($self, $user) = @_;

    my $adRealm = $self->_adRealm();

    return $user . '@' . $adRealm;
}

sub _dcLDAPConnection
{
    my ($self) = @_;

    my $dc = $self->dcHostname();
    my $ldap = new Net::LDAP($dc);
    unless ($ldap) {
        throw EBox::Exceptions::External(
            __x("Unable to setup LDAP object: {x}",
                x => $@));
    }
    return $ldap;
}

# Method: url
#
# Overrides:
#
#   <EBox::Ldap::url>
#
sub url
{
    my ($self) = @_;

    return $self->dcHostname();
}


# Method: hostSamAccountName
#
# Returns:
#   sAMAccountName value for this server
sub hostSamAccountName
{
    my $sysinfo = EBox::Global->modInstance('sysinfo'); # XXX RO or RW?
    return uc($sysinfo->hostName()) . '$';
}

# Method: connectWithKerberos
#
#   authorizes a principal to AD's kerberos
#
#   Parameters:
#      keytab - key tab used for authentication
#
#  Returns:
#     Net::LDAP connection object
sub connectWithKerberos
{
    my ($self, $keytab) = @_;
    my $hostSamAccountName = $self->hostSamAccountName();

    my $dc = $self->dcHostname();

    my $ccache = EBox::Config::tmp() . basename($keytab) . '.ccache';
    $ENV{KRB5CCNAME} = $ccache;

    # Get credentials for computer account
    my $ok = kinit($keytab, $hostSamAccountName);
    unless (defined $ok and $ok == 1) {
        throw EBox::Exceptions::External(
            __x("Unable to get kerberos ticket to bind to LDAP: {x}",
                x => kerror()));
    }

    # Set up a SASL object
    my $sasl = new Authen::SASL(mechanism => 'GSSAPI');
    unless ($sasl) {
        throw EBox::Exceptions::External(
            __x("Unable to setup SASL object: {x}",
                x => $@));
    }

    my $ldap = $self->_dcLDAPConnection();

    # Check GSSAPI support
    my $dse = $ldap->root_dse(attrs => ['defaultNamingContext', '*']);
    unless ($dse->supported_sasl_mechanism('GSSAPI')) {
        throw EBox::Exceptions::External(
            __("AD LDAP server does not support GSSAPI"));
    }

    # Finally bind to LDAP using our SASL object
    my $bindResult = $ldap->bind(sasl => $sasl);
    if ($bindResult->is_error()) {
        throw EBox::Exceptions::External(
            __x("Could not bind to AD LDAP server '{server}'. Error was '{error}'",
                server => $dc, error => $bindResult->error_desc()));
    }
    return $ldap;
}


# Method: connection
#
#   sets a LDAP conenction to the external AD. The connection will be used from
#   now by this object
#
# Returns:
#   - Net::LDAP connection object
sub connection
{
    my ($self) = @_;
    if ($self->connected()) {
        return $self->{ldap};
    }

    EBox::info("Setting AD connection");

    my $dc  = $self->dcHostname();

    # Validate specified DC. It must be defined as FQDN because the 'msktutil' tool need
    # to retrieve credentials for LDAP service principal (LDAP/dc_fqdn@AD_REALM)
    if (EBox::Validate::checkIP($dc)) {
        throw EBox::Exceptions::External(
            __x('The domain controller must be specified as full qualified domain name'));
    }
    unless (EBox::Validate::checkDomainName($dc) and scalar (split (/\./, $dc)) > 1) {
        throw EBox::Exceptions::External(
            __x('The FQDN {x} does not seem to be valid', x => $dc));
    }

    # Check DC can be resolved to IP
    my $resolver = new Net::DNS::Resolver();
    $resolver->tcp_timeout(5);
    $resolver->udp_timeout(5);
    my $dcIpAddress = undef;
    my $query = $resolver->query($dc, 'A');
    if ($query) {
        foreach my $rr ($query->answer()) {
            next unless $rr->type() eq 'A';
            $dcIpAddress = $rr->address();
            last;
        }
    }
    unless (defined $dcIpAddress and length $dcIpAddress) {
        my $url = '/Network/Composite/DNS';
        throw EBox::Exceptions::External(
            __x('The domain controller {x} could not be resolved to its IP address. ' .
                'Please, make sure you are using one of the AD DNS servers as the ' .
                'primary resolver in the {oh}resolvers list{ch}.',
                x => $dc, oh => "<a href=\"$url\">", ch => '</a>'));
    }

    # Check DC can be reverse resolved
    my $dcReverseName = undef;
    my $targetIP = join ('.', reverse split (/\./, $dcIpAddress)) . ".in-addr.arpa";
    $query = $resolver->query($targetIP, 'PTR');
    if ($query) {
        foreach my $rr ($query->answer()) {
            next unless $rr->type() eq "PTR";
            $dcReverseName = $rr->ptrdname();
        }
    }
    unless (defined $dcReverseName and length $dcReverseName) {
        my $url = '/Network/Composite/DNS';
        throw EBox::Exceptions::External(
            __x("The IP address '{x}' belonging to the domain controller '{y}' could not be " .
                'reverse resolved. Please, make sure you are using one of the AD DNS servers as the ' .
                'primary resolver in the {oh}resolvers list{ch}, and it contains the required reverse zones.',
                x => $dcIpAddress, y => $dc, oh => "<a href=\"$url\">", ch => '</a>'));
    }

    # Check the reverse resolved name match the DC name supplied by user
    unless (lc $dcReverseName eq lc $dc) {
        throw EBox::Exceptions::External(
            __x("The AD DNS server has resolved the supplied DC name '{x}' to the IP '{y}', " .
                "but the reverse resolution of that IP has returned name '{z}'. Please fix your " .
                "AD DNS records.", x => $dc, y => $dcIpAddress, z => $dcReverseName));

    }

    # Check DC is reachable
    my $pinger = new Net::Ping('tcp');
    $pinger->port_number(88);
    $pinger->service_check(1);
    unless ($pinger->ping($dc)) {
        throw EBox::Exceptions::External(
            __x('The domain controller {x} is unreachable.',
                x => $dc));
    }
    $pinger->close();

    # Check clock skew between DC and Zentyal
    $self->_adCheckClockSkew($dc);

    # Check the AD DNS server has an A record for Zentyal
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostFQDN = $sysinfo->fqdn();
    my $hostIpAddress = undef;
    $query = $resolver->query($hostFQDN, 'A');
    if ($query) {
        foreach my $rr ($query->answer()) {
            next unless $rr->type() eq 'A';
            $hostIpAddress = $rr->address();
            last;
        }
    }
    unless (defined $hostIpAddress and length $hostIpAddress) {
        throw EBox::Exceptions::External(
            __x("The Zentyal server FQDN '{x}' could not be resolved by the AD DNS server. " .
                "Please, ensure the A and PTR records for the Zentyal server exists in your AD DNS server.",
                x => $hostFQDN));
    }

    # Check the AD DNS server has a PTR record for Zentyal
    my $hostReverseName = undef;
    my $hostTargetIP = join ('.', reverse split (/\./, $hostIpAddress)) . ".in-addr.arpa";
    $query = $resolver->query($hostTargetIP, 'PTR');
    if ($query) {
        foreach my $rr ($query->answer()) {
            next unless $rr->type() eq "PTR";
            $hostReverseName = $rr->ptrdname();
        }
    }
    unless (defined $hostReverseName and length $hostReverseName) {
        throw EBox::Exceptions::External(
            __x("The IP address '{x}' belonging to Zentyal server '{y}' could not be " .
                "reverse resolved. Please, make sure your AD DNS server has the " .
                "required PTR records defined.", x => $hostIpAddress, y => $hostFQDN));
    }

    # Check the reverse resolved name match the DC name supplied by user
    unless (lc $hostReverseName eq lc $hostFQDN) {
        throw EBox::Exceptions::External(
            __x("The AD DNS server has resolved the Zentyal server name '{x}' to the IP '{y}', " .
                "but the reverse resolution of that IP has returned name '{z}'. Please fix your " .
                "AD DNS records.", x => $hostFQDN, y => $hostIpAddress, z => $hostReverseName));

    }

    # Bind to the AD LDAP
    my $ad = $self->_dcLDAPConnection();
    my $adUser = $self->userBindDN($self->_adUser());
    my $bindPwd = $self->getPassword();
    my $bindResult = $ad->bind($adUser, password => $bindPwd);
    if ($bindResult->is_error()) {
        throw EBox::Exceptions::External(
            __x("Could not bind to AD LDAP server '{x}' (Error was '{y}'). " .
                "Please check the supplied credentials.",
                x => $dc, y => $bindResult->error_desc()));
    }

    $self->{ldap} = $ad;
    return $ad;
}


sub _rootDse
{
    my ($self) = @_;

    unless (defined $self->{rootDse}) {
        my $ad = $self->_dcLDAPConnection();
        $self->{rootDse} = $ad->root_dse(attrs => ['dnsHostName', 'defaultNamingContext']);
    }
    return $self->{rootDse};
}

sub _adRealm
{
    my ($self) = @_;

    my $dse = $self->_rootDse();
    my $defaultNC = $dse->get_value('defaultNamingContext');
    my @dcDnsHostname = split (/\./, $dse->get_value('dnsHostName'), 2);
    my $dcDomain = $dcDnsHostname[1];
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostDomain = $sysinfo->hostDomain();
    unless (lc $hostDomain eq lc $dcDomain) {
        throw EBox::Exceptions::External(
            __x("The server domain '{x}' does not match DC domain '{y}'.",
                x => $hostDomain, y => $dcDomain));
    }
    my $adRealm = uc ($defaultNC);
    $adRealm =~ s/DC=//g;
    $adRealm =~ s/,/\./g;

    # Check whether the host domain match the AD dns domain. Requiered by
    # kerberos.
    my $usersModule = EBox::Global->modInstance('users');
    my $hostRealm = $usersModule->kerberosRealm();
    unless ($adRealm eq $hostRealm) {
        throw EBox::Exceptions::External(
            __x("The server kerberos realm '{x}' does not match AD realm '{y}'.",
                x => $hostRealm, y => $adRealm));
    }

    return $adRealm;
}

# Method: _adDefaultNamingContext
#
#   Retrieve the AD default naming context from DC ldap root dse
#
sub _adDefaultNC
{
    my ($self) = @_;

    my $dse = $self->_rootDse();

    return $dse->get_value('defaultNamingContext');
}

# Method: initKeyTabs
#
#   Initializes keytabs for AD/Kerberos services
#
sub initKeyTabs
{
    my ($self) = @_;
    my $ad = $self->connection();

    my $adUser = $self->userBindDN($self->_adUser());
    my $dc      = $self->dcHostname();
    my $defaultNC = $self->_adDefaultNC();
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $bindPwd = $self->getPassword();
    # Check the Zentyal computer account
    my $hostSamAccountName = $self->hostSamAccountName();
    my $hostFQDN = $sysinfo->fqdn();
    my $hostFound = _hostInAD($ad, $defaultNC, $hostSamAccountName);

    # Extract keytab for services
    try {
        # Remove old credentials cache
        my $ccache = EBox::Config::tmp() . 'kerberos-ad-setup.ccache';
        $ENV{KRB5CCNAME} = $ccache;
        unlink $ccache if (-f $ccache);

        # Get kerberos ticket for the admin user
        my $ok = kdestroy();
        unless (defined $ok and $ok == 1) {
            EBox::error("kdestroy: " . kerror());
        }
        $ok = kinit_pwd($adUser, $bindPwd);
        unless (defined $ok and $ok == 1) {
            EBox::error("kinit: " . kerror());
        }

        my $computerName = uc ($sysinfo->hostName());

        my @servicesPrincipals = @{ $self->externalServicesPrincipals() };
        foreach my $servPrincipal (@servicesPrincipals) {
            my $keytab      = $servPrincipal->{keytab};
            my $keytabFound = EBox::Sudo::fileTest('-r', $keytab);
            my $keytabUser  = $servPrincipal->{keytabUser};
            my $service     = $servPrincipal->{service};
            my $keytabTempPath = EBox::Config::tmp() . "$service.keytab";
            if ($hostFound and $keytabFound) {
                EBox::Sudo::root("cp '$keytab' '$keytabTempPath'") ;
                EBox::Sudo::root("chown ebox '$keytabTempPath'");
                EBox::Sudo::root("chmod 660 '$keytabTempPath'" );

                # Update keytab
                my $cmd = "msktutil -N --auto-update --computer-name '$computerName' --keytab '$keytabTempPath' --server '$dc' --user-creds-only --verbose";
                EBox::Sudo::command($cmd);
            } else {
                my $upn = "zentyalServices/$hostFQDN";
                my @principals = @{ $servPrincipal->{principals} };
                # Create the account and extract keytab to temporary directory
                EBox::Sudo::command("rm -f '$keytabTempPath'");

                foreach my $principal (@principals) {
                    my $cmd = "msktutil -N -c -b 'CN=COMPUTERS' -s '$principal/$hostFQDN' " .
                        "-k '$keytabTempPath' --computer-name '$computerName' " .
                            "--upn '$upn' --server '$dc' --user-creds-only " .
                            "--verbose";
                    EBox::Sudo::command($cmd);
                }

                # reflect that the host account was created
                $hostFound = 1;
            }

            # Move keytab to the correct place
            EBox::Sudo::root("mv '$keytabTempPath' '$keytab'");
            EBox::Sudo::root("chown root:$keytabUser '$keytab'");
            EBox::Sudo::root("chmod 440 '$keytab'");
        }
    } catch ($e) {
        my $ok = kdestroy();
        unless (defined $ok and $ok == 1) {
            EBox::error("kdestroy: " . kerror());
        }
        throw EBox::Exceptions::External(__("Error creating computer account for Zentyal server:") .  " $e");
    }
    # Destroy acquired credentials
    my $ok = kdestroy();
    unless (defined $ok and $ok == 1) {
        EBox::error("kdestroy: " . kerror());
    }
}


sub _hostInAD
{
    my ($ad, $defaultNC, $hostSamAccountName) = @_;
    my $result = $ad->search(base => "CN=Computers,$defaultNC",
                          scope => 'sub',
                          filter => '(objectClass=computer)',
                          attrs => ['samAccountName']);
    foreach my $entry ($result->entries()) {
        my $entrySamAccountName = $entry->get_value('samAccountName');
        if (uc $entrySamAccountName eq uc $hostSamAccountName) {
            return 1;
        }
    }
    return 0;
}

# Method: _adCheckClockSkew
#
#   Checks the clock skew with the remote AD server and throw exception
#   if the offset is above two minutes.
#
#   FIXME This method is duplicated from samba module, file Provision.pm
#
#   Maths:
#       Originate Timestamp     T1 - time request sent by client
#       Receive Timestamp       T2 - time request received by server
#       Transmit Timestamp      T3 - time reply sent by server
#       Destination Timestamp   T4 - time reply received by client
#
#       The roundtrip delay d and local clock offset t are defined as:
#       d = (T4 - T1) - (T2 - T3)
#       t = ((T2 - T1) + (T3 - T4)) / 2
#
sub _adCheckClockSkew
{
    my ($self, $adServerIp) = @_;

    throw EBox::Exceptions::MissingArgument('adServerIp')
        unless (defined $adServerIp and length $adServerIp);

    my %h;
    try {
        %h = get_ntp_response($adServerIp);
    } catch {
        throw EBox::Exceptions::External(
            __x('Could not retrive time from AD server {x} via NTP.',
                x => $adServerIp));
    }

    my $t0 = time;
    my $T1 = $t0; # $h{'Originate Timestamp'};
    my $T2 = $h{'Receive Timestamp'};
    my $T3 = $h{'Transmit Timestamp'};
    my $T4 = time; # From Time::HiRes
    my $d = ($T4 - $T1) - ($T2 - $T3);
    my $t = (($T2 - $T1) + ($T3 - $T4)) / 2;
    unless (abs($t) < 120) {
        throw EBox::Exceptions::External(
            __('The clock skew with the AD server is higher than two minutes. ' .
               'This can cause problems with kerberos authentication, please ' .
               'sync both clocks with an external NTP source and try again.'));
    }
}

# Method: externalServicesPrincipals
#
# Returns:
#
#  Reference to a list of service principals which can connect to AD/Kerberos
#
sub externalServicesPrincipals
{
    my ($self) = @_;

    my $SPNs = [];
    if (EBox::Global->modExists('squid')) {
        my $squid = EBox::Global->modInstance('squid');
        if ($squid->isEnabled()) {
            push (@{$SPNs}, $squid->kerberosServicePrincipals());
        }
    }
    return $SPNs;
}

sub anonymousLdapCon
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'This action is not available in external AD mode');
}

sub getRoPassword
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'This action is not available in external AD mode');
}

# Method: dn
#
# Returns:
#
#   The base DN of the external AD
#
sub dn
{
    my ($self) = @_;

    unless (defined $self->{dn}) {
        $self->{dn} = $self->_adDefaultNC();
    }

    return defined ($self->{dn}) ? $self->{dn} : '';
}

# Method: clearConn
#
#   Closes LDAP connection and clears DN cached value
#
sub clearConn
{
    my ($self) = @_;

    delete $self->{ldap};
    delete $self->{rootDse};
    delete $self->{dn};
    delete $self->{user};
    delete $self->{dcHostname};
    $self->SUPER::clearConn();
}

sub roRootDn {
    throw EBox::Exceptions::UnwillingToPerform(reason => 'This action is not available in external AD mode');
}

# Method: ldapConf
#
#  Returns:
#    has wiht infromation about the LDAP conf for human consumption
sub ldapConf
{
    my ($self) = @_;
    return {
        dn => $self->dn()
    };
}

sub _dumpLdap
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'This action is not available in external AD mode');
}

sub changeUserPassword
{
    throw EBox::Exceptions::UnwillingToPerform(reason => 'This action is not available in external AD mode');
}

1;
