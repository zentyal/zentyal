# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::KerberosModule;

use TryCatch::Lite;
use EBox::Util::Random;
use EBox::Users::Computer;

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

sub kerberosCreatePrincipals
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();
    my $hostdomain = $sysinfo->hostDomain();
    my $netbiosName = $users->netbiosName();
    my $baseDn = $users->ldap()->dn();
    my $dcDn = 'CN=' . uc ($hostname) . ',OU=Domain Controllers,' . $baseDn;

    my $data = $self->kerberosServicePrincipals();
    EBox::Sudo::root("rm -f $data->{keytab}");

    foreach my $service (@{$data->{principals}}) {
        my $principal = "$service/$hostname.$hostdomain";

        my $dc = new EBox::Users::Computer(dn => $dcDn);
        $dc->addSpn($principal);
        $dc->addSpn("$principal/$netbiosName");

        # Extract keytab
        my @cmds;
        push (@cmds, "samba-tool domain exportkeytab $data->{keytab} --principal=$principal");
        push (@cmds, "chown root:$data->{keytabUser} '$data->{keytab}'");
        push (@cmds, "chmod 440 '$data->{keytab}'");
        EBox::info("Extracting keytab for service $service, principal $principal");
        EBox::Sudo::root(@cmds);
    }
}

1;
