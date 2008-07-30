# Copyright (C) 2007 Warp Networks S.L.
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

# Class:
# 
#   EBox::DNS::Model::AliasTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   object table which basically contains domains names and a reference
#   to a member <EBox::DNS::Model::AliasTable>
#
#   
package EBox::DNS::Model::AliasTable;

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Exceptions::External;
use EBox::Exceptions::DataExists;

use EBox::Types::DomainName;
use EBox::Sudo;

use Net::IP;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

# Group: Public methods

sub new 
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: validateTypedRow
#
# Overrides:
#
#    <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#    <EBox::Exceptions::External> - thrown if there is a hostname with
#    the same name of this added/edited alias within the same domain
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    return unless ( exists $changedFields->{alias} );
    my $alias = $changedFields->{alias};

    # Check it is not the nameserver hostname
    my $dnsMod = EBox::Global->modInstance('dns');
    my $newAlias = $alias->value();
    if ($newAlias eq $dnsMod->NameserverHost()) {
        throw EBox::Exceptions::External(
            __x('An alias cannot be the nameserver host name "{ns}". '
                . 'Use a hostname instead',
                 ns => $dnsMod->NameserverHost()));
    }

    my $olddir = $self->directory();

    # Check there is no A RR in the domain with the same name
    my $domain = $alias->row()->parentRow()->parentRow()->valueByName('domain');
    
    for my $hostname (@{$dnsMod->getHostnames($domain)}) {
        if ($hostname->{name} eq $newAlias) {
            throw EBox::Exceptions::External(
                        __x('There is a hostname with the same name "{name}" '
                            . 'in the same domain',
                             name     => $newAlias));

        }
        for my $alias (@{$hostname->{'aliases'}}) {
            if ($hostname->{name} eq $newAlias) {
                throw EBox::Exceptions::External(
                        __x('There is an alias with the same name "{name}" '
                            . 'in the same domain',
                             name     => $newAlias));
            }
        }
    }

    $self->setDirectory($olddir);
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#    <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHead =
        ( 

            new EBox::Types::DomainName
                            (
                                'fieldName' => 'alias',
                                'printableName' => __('Alias'),
                                'size' => '20',
                                'unique' => 1,
                                'editable' => 1
                             )
          );

    my $dataTable = 
        { 
            'tableName' => 'AliasTable',
            'printableTableName' => __('Alias'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/Dns/Controller/AliasTable',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __('Alias'),
            'printableRowName' => __('alias'),
            'sortedBy' => 'alias',
        };

    return $dataTable;
}

1;
