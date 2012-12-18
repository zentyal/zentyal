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

sub kerberosKeytab
{
    my ($self) = @_;

    return undef;
}

sub kerberosCreatePrincipals
{
    my ($self, $data) = @_;

    my $users = EBox::Global->modInstance('users');
    if ($users->master() ne 'zentyal') {
        my $principals = $self->kerberosServicePrincipals();
        foreach my $princ (@{$principals}) {
            EBox::UsersAndGroups::Principal->create($princ);
        }
    }

#    unless (defined $data) {
#        $data = $self->kerberosServicePrincipals();
#    }
#
#    if (defined $data->{keytab}) {
#        EBox::Sudo::silentRoot("rm -f $data->{keytab}");
#    }
#
#    my $pass = EBox::Util::Random::generate(20);
#    foreach my $p (@{$data->{principals}}) {
#        my @cmds=();
#        push (@cmds, 'kadmin -l add ' .
#                  "--password='$pass' " .
#                  "--max-ticket-life='1 day' " .
#                  "--max-renewable-life='1 week' " .
#                  "--attributes='' " .
#                  "--expiration-time=never " .
#                  "--pw-expiration-time=never " .
#                  "--policy=default '$p'");
#        if (defined $data->{keytab}) {
#            push (@cmds, "kadmin -l ext -k '$data->{keytab}' '$p'");
#            push (@cmds, "chown root:$data->{keytabUser} '$data->{keytab}'");
#            push (@cmds, "chmod 440 '$data->{keytab}'");
#        }
#
#        EBox::Sudo::silentRoot("kadmin -l del $p");
#        EBox::debug("Creating service principal $p");
#        EBox::Sudo::root(@cmds);
#    }
#
#    # Import service principals from Zentyal to samba
#    if (EBox::Global->modExists('samba')) {
#        my $sambaModule = EBox::Global->modInstance('samba');
#        if ($sambaModule->isEnabled() and $sambaModule->isProvisioned()) {
#            $sambaModule->ldb->ldapServicePrincipalsToLdb();
#        }
#    }
}

1;
