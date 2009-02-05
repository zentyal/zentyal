# Copyright (C) 2009 Warp Networks S.L.
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

package EBox::Squid::Model::FilterGroupDomainFilter;
use base 'EBox::Squid::Model::DomainFilterBase';

use strict;
use warnings;


use EBox::Exceptions::Internal;
use EBox::Gettext;



sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;
    return $self;
}



# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my $dataTable =
        {
            tableName          => 'FilterGroupDomainFilter',
            printableTableName => __('Domains rules'),
            modelDomain        => 'Squid',
            'defaultController' => '/ebox/Squid/Controller/FilterGroupDomainFilter',
            'defaultActions' =>
                [	
                    'add', 'del',
                    'editField',
                    'changeView'
                   ],
            tableDescription   => $self->_tableHeader(),
            class              => 'dataTable',
            order              => 0,
            rowUnique          => 1,
            printableRowName   => __('internet domain'),
            help               => __('Allow/Deny the HTTP traffic from/to the listed internet domains.'),
            messages           => {
                add => __('Domain added'),
                del => __('Domain removed'),
                update => __('Domain updated'),

            },
            sortedBy           => 'domain',
        };

}


sub precondition
{
    my ($self) = @_;

    my $parentComposite = $self->topParentComposite();
    my $useDefault = $parentComposite->componentByName('UseDefaultDomainFilter', 1);

    return not $useDefault->useDefaultValue();
}



1;

