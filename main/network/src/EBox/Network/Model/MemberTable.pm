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

use strict;
use warnings;

package EBox::Network::Model::MemberTable;

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
use EBox::Exceptions::ComponentNotExists;

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

sub _table
{
    my @tableHead =
        (

            new EBox::Types::Text
                            (
                                'fieldName' => 'name',
                                'printableName' => __('Name'),
                                'unique' => 1,
                                'editable' => 1
                             ),
            new EBox::Types::Union(
                fieldName => 'address',
                printableName => __('IP address'),
                subtypes => [
                    new EBox::Types::IPAddr (
                        'fieldName' => 'ipaddr',
                        'printableName' => 'CIDR',
                        'editable' => 1,
                       ),
                    new EBox::Types::IPRange(
                        'fieldName' => 'iprange',
                        'printableName' => __('Range'),
                        'editable' => 1,
                       ),
                    ],
            ),
            new EBox::Types::MACAddr
                            (
                                'fieldName' => 'macaddr',
                                'printableName' => __('MAC address'),
                                'unique' => 1,
                                'editable' => 1,
                                'optional' => 1
                            ),

          );

    my $dataTable =
        {
            'tableName' => 'MemberTable',
            'printableTableName' => __('Members'),
            'automaticRemove' => 1,
            'defaultController' => '/Network/Controller/MemberTable',
            'defaultActions' => ['add', 'del', 'editField', 'changeView', 'clone' ],
            'tableDescription' => \@tableHead,
            'class' => 'dataTable',
            'help' => __('For the IP addresses you can use CIDR notation (address/netmask) or specify the first and last addresses of a range that will also include all the IP addresses between them.'),
            'printableRowName' => __('member'),
            'sortedBy' => 'name',
        };

    return $dataTable;
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
            __x(
                    q{{ip} overlaps with the address or another object's member},
                    ip => $printableValue
                   )
           );
    }
}

# Method: alreadyInSameObject
#
#       Checks if a member (i.e: its ip and mask) overlaps with another object's member
#
# Parameters:
#
#           (POSITIONAL)
#
#       memberId - memberId
#       ip - IPv4 address
#       mask - network mask
#
# Returns:
#
#       boolean - true if it overlaps, otherwise false
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
#       Return the members
#
# Parameters:
#
#       (POSITIONAL)
#
#       id - object's id
#
# Returns:
#       <EBox::Objects::Members>
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument>
sub members
{
    my ($self) = @_;

    my @members;
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

        push @members, \%member;
    }

    my $membersObject = \@members;
    bless $membersObject, 'EBox::Objects::Members';
    return $membersObject;
}

# addresses
#
#       Return the network addresses
#
# Parameters:
#
#       mask - return also addresses' mask (named optional, default false)
#
# Returns:
#
#       array ref - containing an ip addresses
#                   empty array if there are no addresses in the table
#
#       If mask parameter is on, the elements of the array would be [ip_without_mask, mask]
#
sub addresses
{
    my ($self, @params) = @_;

    my $members = $self->members();
    return $members->addresses(@params);
}

# Method: pageTitle
#
#   Overrides <EBox::Model::DataTable::pageTitle>
#   to show the name of the domain
sub pageTitle
{
    my ($self) = @_;
    my $parentRow = $self->parentRow();

    if (not $parentRow) {
        # workaround: sometimes with a logout + apache restart the directory
        # parameter is lost. (the apache restart removes the last directory used
        # from the models)
        EBox::Exceptions::ComponentNotExists->throw('Directory parameter and attribute lost');
    }

    return $parentRow->printableValueByName('name');
}

1;
