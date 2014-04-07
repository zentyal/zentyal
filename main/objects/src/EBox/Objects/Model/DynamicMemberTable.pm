# Copyright (C) 2008-2013 Zentyal S.L.
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
#   EBox::Object::Model::ObjectTable
#
#   This class inherits from <EBox::Model::DataTable> and represents the
#   membembers beloging to an object
#
#
use strict;
use warnings;

package EBox::Objects::Model::DynamicMemberTable;

use EBox::Objects::Members;
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Sudo;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::MACAddr;
use EBox::Types::IPAddr;
use EBox::Types::IPRange;

use EBox::Exceptions::External;

use Net::IP;

use base 'EBox::Model::DataTable';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: ids
#
#   Return the current list of members
#
# Overrides:
#
#     <EBox::Model::DataTable::ids>
#
sub ids
{
    my ($self)  = @_;

    my $parentRow = $self->parentRow();
    my ($filterIp, $filterMask) = $parentRow->valueByName('filter');

    my $ipset = $self->_ipset();
    my $ids = $ipset->{members};

    # Filter elements if filter is defined in the parent row
    if (defined $filterIp and defined $filterMask) {
        my $range = new Net::IP("$filterIp/$filterMask");
        $ids = [ grep {
            my $ip = new Net::IP("$_/32");
            $range->overlaps($ip) == $IP_B_IN_A_OVERLAP
        } @{$ids} ];
    }

    return $ids;
}

# Method: row
#
#     Return a node names
#
# Overrides:
#
#     <EBox::Model::DataTable::row>
#
sub row
{
    my ($self, $id)  = @_;

    my $socket = '/var/run/p0f/p0f.sock';

    # Query the information to p0f cache. See api.h for struct definitions.
    # TODO
    # struct p0f_api_query {
    #   u32 magic;                            /* Must be P0F_QUERY_MAGIC            */
    #   u8  addr_type;                        /* P0F_ADDR_*                         */
    #   u8  addr[16];                         /* IP address (big endian left align) */
    # }

    my $row = new EBox::Model::Row(dir => $self->directory(),
        confmodule => $self->parentModule());
    $row->setId($id);
    $row->setModel($self);
    $row->setReadOnly(1);

    my $table = $self->table();
    foreach my $type (@{$table->{tableDescription}}) {
        my $element = $type->clone();
        if ($type->fieldName() eq 'address') {
            $element->setValue("$id/32");
        }
        $row->addElement($element);
    }

    return $row;
}


sub _table
{
    my @tableHead = (
        new EBox::Types::IPAddr(
            fieldName       => 'address',
            printableName   => __('IP address'),
            editable        => 0,
        ),
    );

    my $helpMessage = __('For the IP addresses you can use CIDR notation ' .
        '(address/netmask) or specify the first and last addresses of a ' .
        'range that will also include all the IP addresses between them.');

    my $dataTable = {
        tableName           => 'DynamicMemberTable',
        printableTableName  => __('Dynamic members'),
        automaticRemove     => 1,
        defaultController   => '/Objects/Controller/DynamicMemberTable',
        defaultActions      => [ 'changeView' ],
        withoutActions      => 1,
        tableDescription    => \@tableHead,
        class               => 'dataTable',
        printableRowName    => __('dynamic member'),
        sortedBy            => 'name',
        help                => $helpMessage,
    };

    return $dataTable;
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle> to show the name
#   of the domain
#
sub pageTitle
{
    my ($self) = @_;

    my $parentRow = $self->parentRow();
    return $parentRow->printableValueByName('name');
}

# Group: Private methods

# Method: _linesplit
#
#   Auxiliary method to split a line int key and value. It is used to
#   parse the output of 'ipset list' command.
#
# Returns:
#
#   array ref - The first value is the key, second the value
#
sub _linesplit
{
    my ($line) = @_;

    my ($key, $value) = split(/:/, $line);
    $key =~ s/^\s+|\s+$//g if length $key;
    $value =~ s/^\s+|\s+$//g if length $value;

    return [ $key, $value ];
}

# Method: _ipset
#
#   Return the ipset information which this dynamic object represent,
#   including all its members.
#
# Returns:
#
#   hash ref - Contains the ipset information
#
sub _ipset
{
    my ($self) = @_;

    my $parent = $self->parentRow();
    my $ipsetName = $parent->valueByName('type');

    my $output = EBox::Sudo::root("ipset list $ipsetName");

    my $ipset = {};
    $ipset->{name}       = @{_linesplit(shift @{$output})}[1];
    $ipset->{type}       = @{_linesplit(shift @{$output})}[1];
    $ipset->{revision}   = @{_linesplit(shift @{$output})}[1];
    $ipset->{header}     = @{_linesplit(shift @{$output})}[1];
    $ipset->{size}       = @{_linesplit(shift @{$output})}[1];
    $ipset->{references} = @{_linesplit(shift @{$output})}[1];

    shift @{$output};
    $ipset->{members}   = [ map { $_ =~  s/^\s+|\s+$//g; $_ } @{$output} ];

    return $ipset;
}

1;
