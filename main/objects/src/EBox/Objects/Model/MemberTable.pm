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

package EBox::Objects::Model::MemberTable;

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
    my $type = $parentRow->elementByName('type');
    return $self->SUPER::ids() unless defined $type->set();

    my $ipset = $self->_ipset();
    my $ids = $ipset->{members};

    # Filter elements if filter is defined in the parent row
    my ($ipsetName, $filterIp, $filterMask) = $type->value();
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

    my $parentRow = $self->parentRow();
    my $type = $parentRow->elementByName('type');
    return $self->SUPER::row($id) unless defined $type->set();

    my $row = new EBox::Model::Row(dir => $self->directory(),
        confmodule => $self->parentModule());
    $row->setId($id);
    $row->setModel($self);
    $row->setReadOnly(1);

    my $table = $self->table();
    foreach my $type (@{$table->{tableDescription}}) {
        my $element = $type->clone();
        if ($type->fieldName() eq 'name') {
            my ($ipset, undef, undef) = $parentRow->valueByName('type');
            $element->setValue("dynamic_${ipset}_${id}");
        } elsif ($type->fieldName() eq 'address') {
            $element->setValue({ ipaddr => "$id/32"});
        } elsif ($type->fieldName() eq 'macaddr') {
            $element->setValue(undef);
        }
        $row->addElement($element);
    }

    return $row;
}

sub _table
{
    my ($self) = @_;

    my $tableHead = [
        new EBox::Types::Text(
            fieldName       => 'name',
            printableName   => __('Name'),
            unique          => 1,
            editable        => 1
        ),
        new EBox::Types::Union(
            fieldName       => 'address',
            printableName   => __('IP address'),
            subtypes        => [
                new EBox::Types::IPAddr(
                    fieldName       => 'ipaddr',
                    printableName   => 'CIDR',
                    editable        => 1
                ),
                new EBox::Types::IPRange(
                    fieldName       => 'iprange',
                    printableName   => __('Range'),
                    editable        => 1
                ),
            ],
        ),
        new EBox::Types::MACAddr(
            fieldName       => 'macaddr',
            printableName   => __('MAC address'),
            unique          => 1,
            editable        => 1,
            optional        => 1,
        ),
    ];

    my $helpMessage = __('For the IP addresses you can use CIDR notation ' .
        '(address/netmask) or specify the first and last addresses of a ' .
        'range that will also include all the IP addresses between them.');


    my $dataTable = {
        tableName           => 'MemberTable',
        printableTableName  => __('Members'),
        automaticRemove     => 1,
        defaultController   => '/Objects/Controller/MemberTable',
        defaultActions      => [],
        tableDescription    => $tableHead,
        class               => 'dataTable',
        printableRowName    => __('member'),
        sortedBy            => 'name',
        help                => $helpMessage,
    };

    return $dataTable;
}

sub _defaultActions
{
    my ($self) = @_;

    my $defaultActions = [ 'changeView' ];
    my $type = $self->parentRow->elementByName('type');
    unless (defined $type->set()) {
        push (@{$defaultActions}, qw( add del editField clone ));
    }
    return $defaultActions;
}

# Method: setDirectory
#
#   XXX This is an EVIL HACK to show a different set of default actions
#   depending on the parent row and should be implemented in the framework
#
sub setDirectory
{
    my ($self) = shift;

    $self->SUPER::setDirectory(@_);

    my $table = $self->{'table'};
    $table->{actions} = undef;

    my $defAction = $self->_mainController();
    if ($defAction) {
        foreach my $action (@{$self->_defaultActions()}) {
            # Do not overwrite existing actions
            unless ( exists ( $table->{'actions'}->{$action} )) {
                $table->{'actions'}->{$action} = $defAction;
            }
        }
    }
}

sub validateTypedRow
{
    my ($self, $action, $params, $actual) = @_;

    my $id = $params->{id}; # XXX not sure
    my $address = exists $params->{address} ?
                         $params->{address} : $actual->{address};
    my $mac = exists $params->{macaddr} ?
                         $params->{macaddr}->value() : $actual->{macaddr}->value();
    my $addressType = $address->selectedType();
    my $printableValue;

    if ($addressType eq 'ipaddr') {
        my $ipaddr = $address->subtype();
        my $ip = $ipaddr->ip();
        my $mask = $ipaddr->mask();

        if ($mask eq '32') {
            if ($ip =~ /\.0+$/) {
                throw EBox::Exceptions::External(
                        __('Only network addresses can end with a zero'));
            }
        } else {
            if (defined ($mac)) {
                throw EBox::Exceptions::External(
                        __('You can only use MAC addresses with hosts'));
            }
        }
        $printableValue = $ipaddr->printableValue();
    } elsif ($addressType eq 'iprange') {
        if (defined $mac) {
            throw EBox::Exceptions::External(
            __('You cannot use MAC addresses with IP ranges'));
        }
        my $range = $address->subtype();
        $printableValue = $range->printableValue();
    }

    if ($self->_alreadyInSameObject($id, $printableValue)) {
        throw EBox::Exceptions::External(
            __x("{ip} overlaps with the address or another object's member",
                ip => $printableValue));
    }
}

# Method: _alreadyInSameObject
#
#   Checks if a member (i.e: its ip and mask) overlaps with another object's
#   member
#
# Parameters:
#
#   (POSITIONAL)
#   memberId - memberId
#   ip - IPv4 address
#   mask - network mask
#
# Returns:
#
#   boolean - true if it overlaps, otherwise false
#
sub _alreadyInSameObject
{
    my ($self, $memberId, $printableValue) = @_;

    my $new = new Net::IP($printableValue);

    foreach my $id (@{$self->ids()}) {
        next if ((defined $memberId) and ($id eq $memberId));

        my $row  = $self->row($id);
        my $memaddr = new Net::IP($row->printableValueByName('address'));

        if ($memaddr->overlaps($new) != $IP_NO_OVERLAP){
            return 1;
        }

    }

    return undef;
}

# Method: members
#
#   Return the members
#
# Returns:
#
#   <EBox::Objects::Members>
#
# Exceptions:
#
#   <EBox::Exceptions::MissingArgument>
#
sub members
{
    my ($self) = @_;

    my $members = [];

    # If object is dynamic, return just the ipset name and filter
    my $parentRow = $self->parentRow();
    my $type = $parentRow->elementByName('type');
    if (defined $type->set()) {
        my ($ipset, $filterIp, $filterMask) = $type->value();
        my $member = {
            type => 'ipset',
            name => $ipset,
            filterip => $filterIp,
            filtermask => $filterMask,
        };
        push (@{$members}, $member);
    } else {
        foreach my $id (@{$self->ids()}) {
            my $memberRow = $self->row($id);
            my $address = $memberRow->elementByName('address');
            my $type =  $address->selectedType();

            my %member = (
                name => $memberRow->valueByName('name'),
                type => $type,
               );

            if ($type eq 'ipaddr') {
                my $ipaddr = $address->subtype();
                $member{ipaddr} = $ipaddr->printableValue();
                $member{ip}     = $ipaddr->ip();
                $member{mask}   = $ipaddr->mask();
                $member{macaddr} = $memberRow->valueByName('macaddr');
            } elsif ($type eq 'iprange') {
                my $range = $address->subtype();
                $member{begin} = $range->begin();
                $member{end} = $range->end();
                $member{addresses} = undef;
                $member{mask} = 32,
            }

            push (@{$members}, \%member);
        }
    }

    my $membersObject = $members;
    bless ($membersObject, 'EBox::Objects::Members');
    return $membersObject;
}

# Method: addresses
#
#   Return the network addresses
#
# Parameters:
#
#   mask - return also addresses' mask (named optional, default false)
#
# Returns:
#
#   array - containing ip addresses. Empty array if there are no addresses
#           in the table
#   If mask parameter is on, the elements of the array would be
#   [ip_without_mask, mask]
#
sub addresses
{
    my ($self, @params) = @_;

    my $members = $self->members();
    return $members->addresses(@params);
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
    my ($ipsetName, $filterIp, $filterMask) = $parent->valueByName('type');

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
