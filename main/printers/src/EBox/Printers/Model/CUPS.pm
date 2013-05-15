# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Printers::Model::CUPS;

use base 'EBox::Model::DataTable';

use EBox::Gettext;
use EBox::View::Customizer;
use EBox::Types::Text;
use EBox::Types::Boolean;

# Group: Public methods

# Constructor: new
#
#       Create the new model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ($self, $class);

    return $self;
}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    my $net = EBox::Global->modInstance('network');
    my $ifaces = $net->ifaces();
    my %newIfaces =
        map { $_ => 1 } @{$ifaces};
    my %currentIfaces =
        map { $self->row($_)->valueByName('iface') => 1 } @{$currentRows};

    my $modified = 0;

    my @ifacesToAdd = grep { not exists $currentIfaces{$_} } @{$ifaces};

    foreach my $iface (@ifacesToAdd) {
        my $enabled = not $net->ifaceIsExternal($iface);
        $self->add(iface => $iface, enabled => $enabled);
        $modified = 1;
    }

    # Remove old rows
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $ifaceName = $row->valueByName('iface');
        next if exists $newIfaces{$ifaceName};
        $self->removeRow($id);
        $modified = 1;
    }

    return $modified;
}

# Method: precondition
#
# Overrides:
#
#      <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    return $self->parentModule()->isEnabled();
}

# Method: preconditionFailMsg
#
# Overrides:
#
#      <EBox::Model::DataTable::preconditionFailMsg>
#
sub preconditionFailMsg
{
    return __x('Prior to configure printers you need to enable '
               . 'the module in the {openref}Module Status{closeref} '
               . ' section and save changes after that.',
               openref => '<a href="/ServiceModule/StatusView">',
               closeref => '</a>');
}

# Group: Protected methods

sub _table
{
    my ($self) = @_;

    my @tableDesc = (
         new EBox::Types::Text(
             'fieldName' => 'iface',
             'printableName' => __('Interface'),
             'unique' => 1,
             'editable' => 0
         ),
         new EBox::Types::Boolean(
             'fieldName' => 'enabled',
             'printableName' => __('Listen'),
             'editable' => 1
        ),
    );

    my $dataForm =
    {
        tableName          => 'CUPS',
        printableTableName => __('Select CUPS Interfaces'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,
        modelDomain        => 'Printers',
        sortedBy           =>    'iface',
        printableRowName   => __('interface'),
        help               => __('Select in which interfaces the CUPS webserver will listen on. Take into account that is not probably a good idea to listen on external interfaces. If none are selected, it will be listening only at localhost'),
    };
    return $dataForm;
}

1;
