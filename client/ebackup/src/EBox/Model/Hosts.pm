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


package EBox::EBackup::Model::Hosts;

# Class: EBox::EBackup::Model::Hosts
#
#
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::DomainName;
use EBox::Types::Text;
use EBox::Types::Int;

# Group: Public methods

# Constructor: new
#
#       Create the new Hosts model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::EBackup::Model::Hosts> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}


# Method: syncRows
#
#       Syncronizes rdiff status with the current model.
#
# Overrides:
#
#       <EBox::Model::DataTable::syncRows>
#
#sub syncRows
#{
#    my ($self, $currentRows) = @_;
#
#    my @srvs = @{EBox::CA::Certificates->srvsCerts()};
#    my %currentSrvs = map { $self->row($_)->valueByName('service') => 1 } @{$currentRows};
#
#    my @srvsToAdd = grep { not exists $currentSrvs{$_->{'service'}} } @srvs;
#
#    return 0 unless (@srvsToAdd);
#
#    for my $srv (@srvsToAdd) {
#        $self->add(module => $srv->{'module'}, service => $srv->{'service'}, cn => 'ebox', enable => 0);
#    }
#
#    my %srvsToAdd = map { $_ => 1 } @srvsToAdd;
#    for my $id (@{$currentRows}) {
#        my $currentService = $self->row($id)->valueByName('service');
#        unless (exists $srvsToAdd{$currentService}) {
#            $self->removeRow($id);
#        }
#    }
#
#    return 1;
#}


# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader =
      (
       new EBox::Types::DomainName(
                                fieldName     => 'hostname',
                                printableName => __('Hostname'),
                                unique        => 1,
                                editable      => 1,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'status',
                                printableName => __('Status'),
                                unique        => 0,
                                editable      => 0,
                               ),
       new EBox::Types::Text(
                                fieldName     => 'update',
                                printableName => __('Last Update'),
                                size          => 24,
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
       new EBox::Types::Int(
                                fieldName     => 'keep',
                                printableName => __('Days to Keep'),
                                unique        => 0,
                                editable      => 1,
                                optional      => 1,
                               ),
       new EBox::Types::Int(
                                fieldName     => 'size',
                                printableName => __('Size'),
                                unique        => 0,
                                editable      => 0,
                               ),
      );

    my $dataTable =
    {
        tableName          => 'Hosts',
        printableTableName => __('Hosts'),
        printableRowName   => __('host'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'EBackup',
        enableProperty     => 1,
        defaultEnabledValue => 1,
#        orderedBy          => 'hostname'
    };

    return $dataTable;

}

1;
