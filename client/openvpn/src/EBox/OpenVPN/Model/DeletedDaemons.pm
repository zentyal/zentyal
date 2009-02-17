# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::OpenVPN::Model::DeletedDaemons;
use base 'EBox::Model::DataTable';
#

use strict;
use warnings;

use EBox::Gettext;

sub new 
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableHead = ( 
                     new EBox::Types::Text
                     (
                      'fieldName' => 'name',
                      'printableName' => __('Name'),
                      'size' => '20',
                      'editable' => 1,
                      'unique'   => 1,
                     ),
                     new EBox::Types::Text
                     (
                      fieldName => 'type',
                      editable  => 1,
                     ),
                    );
    
    my $dataTable = 
        { 
            'tableName'              => __PACKAGE__->name(),
            'printableTableName' => __('Deleted daemons'),
            'automaticRemove' => 1,
            'defaultController' => '/ebox/OpenVPN/Controller/DeletedDaemons',
            'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'printableRowName' => __('daemon'),
            'modelDomain' => 'OpenVPN',
        };

    return $dataTable;
}


sub name
{
    return __PACKAGE__->nameFromClass();
}



sub addDaemon
{
    my ($self, $name, $type) = @_;

    if ($self->daemonIsDeleted($name)) {
        # we have already a daemons called like that..
        return;
    }

    $self->addRow(
                  name => $name,
                  type => $type,
                 );
}


sub clear
{
    my ($self) = @_;
    $self->removeAll(1);
}



sub daemons
{
    my ($self) = @_;

    my @daemons = map {
        my $row = $self->row($_);
        my $name = $_->elementByName('name')->value();
        my $type = $_->elementByName('type')->value();

        { name => $name, type => $type }
    } @{  $self->ids() };

    return \@daemons;
}


sub daemonIsDeleted
{
    my ($self, $name) = @_;

    $name or
        throw EBox::Exceptions::MissingArgument('name');

    my $row = $self->findValue(name => $name);
    return defined $row
}

1;
