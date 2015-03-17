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

package EBox::Squid::Model::NoAuthDomains;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::DomainName;
use EBox::Validate;

# Method: _table
#
#
sub _table
{
    my @tableHeader = (
       new EBox::Types::DomainName(
                             fieldName     => 'domain',
                             printableName => __('Domain Name Address'),
                             unique        => 1,
                             editable      => 1,
                             optional      => 0,
                            ),
       new EBox::Types::Boolean(
                             fieldName     => 'noAuth',
                             printableName => __('Exempt address from Auth and Cache'),
                             defaultValue  => 1,
                             editable      => 1,
                            ),
    );

    my $dataTable = {
        tableName          => 'NoAuthDomains',
        printableTableName => __('Auth and Cache Exemptions'),
        modelDomain        => 'Squid',
        defaultController  => '/Squid/Controller/NoAuthDomains',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        order              => 0,
        rowUnique          => 1,
        printableRowName   => __('domain name address'),
        help               => __('You can exempt some addresses from Auth and Cache'),
        messages           => {
                                add => __('Address added'),
                                del => __('Address removed'),
                                update => __('Address updated'),
                              },
        sortedBy           => 'domain',
    };
}

sub noAuthDomains
{
    my ($self, $policy) = @_;

    my @domains = map {
        my $row = $self->row($_);
        if ($row->valueByName('noAuth')) {
            $row->valueByName('domain');
        }
        else {
            ()
        }
    } @{ $self->ids() };

    return \@domains;
}

1;
