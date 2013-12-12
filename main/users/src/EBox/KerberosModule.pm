# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::KerberosModule;

use strict;
use warnings;

use Error qw( :try );
use EBox::Util::Random;

sub new
{
	my $class = shift;
	my $self = {};
	bless ($self, $class);
	return $self;
}

sub kerberosServicePrincipals
{
    my ($self) = @_;

    return [];
}

sub _principalExists
{
    my ($self, $principal) = @_;

    my $usersModule = EBox::Global->modInstance('users');
    my $ldap = $usersModule->ldap();
    my $base = 'OU=Kerberos,' . $ldap->dn();
    my $realm = $usersModule->kerberosRealm();
    my $args = {
        base => $base,
        scope => 'sub',
        filter => "(krb5PrincipalName=$principal\@$realm)",
        attrs => [],
    };
    my $result = $ldap->search($args);
    my $count = $result->count();
    return $count;
}

sub kerberosCreatePrincipals
{
    my ($self) = @_;

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();
    my $hostdomain = $sysinfo->hostDomain();

    my $data = $self->kerberosServicePrincipals();
    EBox::Sudo::root("rm -f $data->{keytab}");

    my $pass = EBox::Util::Random::generate(20);
    foreach my $service (@{$data->{principals}}) {
        my $principal = "$service/$hostname.$hostdomain";

        # Create principal if not exists
        unless ($self->_principalExists($principal) > 0) {
            my $cmd = 'kadmin -l add ' .
                      "--password='$pass' " .
                      "--max-ticket-life='1 day' " .
                      "--max-renewable-life='1 week' " .
                      "--attributes='' " .
                      "--expiration-time=never " .
                      "--pw-expiration-time=never " .
                      "--policy=default '$principal'";
            EBox::info("Creating service principal $principal");
            EBox::Sudo::root($cmd);
        }

        # Extract keytab
        my @cmds;
        push (@cmds, "kadmin -l ext -k '$data->{keytab}' '$principal'");
        push (@cmds, "chown root:$data->{keytabUser} '$data->{keytab}'");
        push (@cmds, "chmod 440 '$data->{keytab}'");
        EBox::info("Extracting keytab for service $service, principal $principal");
        EBox::Sudo::root(@cmds);
    }

    # Import service principals from Zentyal to samba
    if (EBox::Global->modExists('samba')) {
        my $sambaModule = EBox::Global->modInstance('samba');
        if ($sambaModule->isEnabled() and $sambaModule->isProvisioned()) {
            $sambaModule->ldb->ldapServicePrincipalsToLdb();
        }
    }
}

1;
