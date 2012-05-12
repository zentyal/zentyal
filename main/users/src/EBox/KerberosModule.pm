# Copyright (C) 2012 eBox Technologies S.L.
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

    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $hostname = $sysinfo->hostName();
    my $hostdomain = $sysinfo->hostDomain();

    my $data = $self->kerberosServicePrincipals();

    EBox::Sudo::root("rm -f $data->{keytab}");

    my $sambaEnabled = 0;
    if (EBox::Global->modExists('samba')) {
        my $sambaModule = EBox::Global->modInstance('samba');
        if ($sambaModule->isEnabled()) {
            $sambaEnabled = 1;
        }
    }

    if ($sambaEnabled == 1)
    {
        EBox::debug('Creating principals in samba');

        my $sambaModule = EBox::Global->modInstance('samba');
        my $tool = $sambaModule->SAMBATOOL();
        my $account = "$data->{service}-$hostname";

        my @cmds=();
        push (@cmds, "$tool user create --random-password '$account'");

        foreach my $service (@{$data->{principals}}) {
            $service = uc ($service);
            my $principal = "$service/$hostname.$hostdomain";
            push (@cmds, "$tool spn add $principal $account");
            push (@cmds, "$tool domain exportkeytab --principal='$principal' '$data->{keytab}'");
        }
        push (@cmds, "chown root:$data->{keytabUser} '$data->{keytab}'");
        push (@cmds, "chmod 440 '$data->{keytab}'");

        try {
            $sambaModule->ldb->disableZentyalModule();
            EBox::Sudo::silentRoot("$tool user delete $account");
            EBox::debug("Creating service principal $principal");
            EBox::Sudo::root(@cmds);
        } otherwise {
            my $error = shift;
            throw EBox::Exceptions::Internal($error);
        } finally {
            $sambaModule->ldb->enableZentyalModule();
        };
    } else {
        EBox::debug('Creating principals in heimdal');

        foreach my $service (@{$data->{principals}}) {
            $service = uc ($service);
            my $principal = "$service/$hostname.$hostdomain";


            my @cmds=();
            push (@cmds, 'kadmin -l add -r ' .
                      "--max-ticket-life='1 day' " .
                      "--max-renewable-life='1 week' " .
                      "--attributes='' " .
                      "--expiration-time=never " .
                      "--pw-expiration-time=never " .
                      "--policy=default '$principal'");
            push (@cmds, "kadmin -l ext -k '$data->{keytab}' '$principal'");
            push (@cmds, "chown root:$data->{keytabUser} '$data->{keytab}'");
            push (@cmds, "chmod 440 '$data->{keytab}'");
            EBox::Sudo::silentRoot("kadmin -l del $principal");
            EBox::debug("Creating service principal $principal");
            EBox::Sudo::root(@cmds);
        }
    }
}

1;
