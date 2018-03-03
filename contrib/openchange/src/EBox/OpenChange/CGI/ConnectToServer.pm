# Copyright (C) 2013 Zentyal S.L.
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

package EBox::OpenChange::CGI::ConnectToServer;

use base 'EBox::CGI::Base';

use EBox;
use EBox::Global;
use EBox::Gettext;
use Net::LDAP;
use EBox::Samba::AuthKrbHelper;
use Authen::SASL;

use TryCatch;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title'    => 'none',
                                  'template' => 'none',
                                  @_);
    bless ($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    try {
        $self->{json}->{success} = 0;

        $self->_requireParam('server', __('Server'));
        my $server = $self->unsafeParam('server');

        my $krbHelper = new EBox::Samba::AuthKrbHelper(RID => 500);

        # Set up a SASL object
        my $sasl = new Authen::SASL(mechanism => 'GSSAPI');
        unless ($sasl) {
            throw EBox::Exceptions::External(
                __x("Unable to setup SASL object: {x}",
                    x => $@));
        }

        my $ldap = new Net::LDAP($server);
        unless ($ldap) {
            throw EBox::Exceptions::External(
                __x("Unable to setup LDAP object: {x}",
                    x => $@));
        }

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
                    server => $server, error => $bindResult->error_desc()));
        }

        $self->{json}->{success} = 1;
    } catch ($error) {
        $self->{json}->{success} = 0;
        $self->{json}->{error} = qq{$error};
    }
}

1;
