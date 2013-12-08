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

package EBox::Squid::Model::TransparentExceptions;

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::DomainName;
use EBox::Types::Boolean;
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
                             fieldName     => 'enabled',
                             printableName => __('Skip Transparent Proxy'),
                             defaultValue  => 1,
                             editable      => 1,
                            ),
    );

    my $dataTable = {
        tableName          => 'TransparentExceptions',
        printableTableName => __('Transparent Proxy Exemptions'),
        modelDomain        => 'Squid',
        defaultController  => '/Squid/Controller/TransparentExceptions',
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        order              => 0,
        rowUnique          => 1,
        printableRowName   => __('domain name address'),
        help               => __('You can exempt some addresses from transparent proxy'),
        messages           => {
                                add => __('Address added'),
                                del => __('Address removed'),
                                update => __('Address updated'),
                              },
        sortedBy           => 'domain',
    };
}

1;
