# Copyright (C) 2008-2012 eBox Technologies S.L.
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

# Class: EBox::DHCP::Model::FixedAddressTable
#
# This class is used to set the fixed addresses on a dhcp server
# attached to an interface. The fields are the following:
#
# - object: Network Object (Foreign model)
# - description : Text
#
use strict;
use warnings;

package EBox::DHCP::Model::FixedAddressTable;
use base 'EBox::Model::DataTable';

use EBox::Exceptions::External;
use EBox::Global;
use EBox::Gettext;
use EBox::NetWrappers;
use EBox::Types::Text;
use EBox::Types::Select;
use Net::IP;

# Constructor: new
#
#       Constructor for Rule table
#
# Returns :
#
#      A recently created <EBox::DHCP::Model::RangeTable> object
#
sub new
{
    my $class = shift;

    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: validateTypedRow
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    # # Check the given fixed address is not in any user given
    # # range, it is within the available range and it cannot be the
    # # interface address
    # if ( exists ( $changedFields->{ip} )) {
    #     my $newIP = new Net::IP($changedFields->{ip}->value());
    #     my $net = EBox::Global->modInstance('network');
    #     my $dhcp = $self->{confmodule};
    #     my $netIP = new Net::IP( $dhcp->initRange($self->{interface}) . '-'
    #                              . $dhcp->endRange($self->{interface}));
    #     # Check if the ip address is within the network
    #     unless ( $newIP->overlaps($netIP) == $IP_A_IN_B_OVERLAP ) {
    #         throw EBox::Exceptions::External(__x('IP address {ip} is not in '
    #                                              . 'network {net}',
    #                                              ip => $newIP->print(),
    #                                              net  => EBox::NetWrappers::to_network_with_mask(
    #                                                      $net->ifaceNetwork($self->{interface}),
    #                                                      $net->ifaceNetmask($self->{interface}))
    #                                             ));
    #     }
    #     # Check the ip address is not the interface address
    #     my $ifaceIP = new Net::IP($net->ifaceAddress($self->{interface}));
    #     unless ( $newIP->overlaps($ifaceIP) == $IP_NO_OVERLAP ) {
    #         throw EBox::Exceptions::External(__x('The selected IP is the '
    #                                              . 'interface IP address: '
    #                                              . '{ifaceIP}',
    #                                              ifaceIP => $ifaceIP->print()
    #                                             ));
    #     }
    #     # Check the new IP is not within any given range by RangeTable model
    #     # FIXME: When #847 is done
    #     # my $rangeModel = $dhcp->model('RangeTable');
    #     my $rangeModel = EBox::Model::Manager->instance()->model('/dhcp/RangeTable/'
    #                                                                   . $self->{interface});
    #     foreach my $id (@{$rangeModel->ids()}) {
    #         my $rangeRow = $rangeModel->row($id);
    #         my $from = $rangeRow->valueByName('from');
    #         my $to   = $rangeRow->valueByName('to');
    #         my $range = new Net::IP( $from . '-' . $to);
    #         unless ( $newIP->overlaps($range) == $IP_NO_OVERLAP ) {
    #             throw EBox::Exceptions::External(__x('IP address {ip} is in range '
    #                                                  . "'{range}': {from}-{to}",
    #                                                  ip => $newIP->print(),
    #                                                  range => $rangeRow->valueByName('range'),
    #                                                  from  => $from, to => $to));
    #         }
    #     }
    # }
    # if ( exists ( $changedFields->{name} )) {
    #     my $newName = $changedFields->{name}->value();
    #     # Check remainder FixedAddressTable models uniqueness since
    #     # the dhcpd.conf may confuse those name repetition
    #     my @fixedAddressTables = @{EBox::Model::Manager->instance()->model(
    #          '/dhcp/FixedAddressTable/*'
    #                                                                          )};
    #     # Delete the self model
    #     @fixedAddressTables = grep { $_->index() ne $self->index() }
    #       @fixedAddressTables;

    #     my $row = grep { $_->findValue( name => $newName ) }
    #       @fixedAddressTables;

    #     if ( $row ) {
    #         my $i18nAction = '';
    #         if ( $action eq 'update' ) {
    #             $i18nAction = __('update');
    #         } else {
    #             $i18nAction = __('add');
    #         }
    #         throw EBox::Exceptions::External(__x('You cannot {action} a fixed address with a '
    #                                              . 'name which is already used in other fixed '
    #                                              . 'address table',
    #                                              action => $i18nAction));
    #     }

    # }

}

# Method: viewCustomizer
#
#   Overrides this to warn the user only those members with an IP
#   address within the valid range and a MAC address and not in the
#   range.
#
# Overrides:
#
#   <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    if ($self->size()) {
        $customizer->setPermanentMessage(_message());
    }

    $customizer->setHTMLTitle([]);

    return $customizer;
}


# Group: Protected methods

# Method: _table
#
#	Describe the DHCP ranges table
#
# Returns:
#
# 	hash ref - table's description
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
       new EBox::Types::Select(
                               fieldName     => 'object',
                               foreignModel  => $self->objectModelGetter(),
                               foreignField  => 'name',
                               foreignNextPageField => 'members',

                               printableName => __('Object'),
                               unique        => 1,
                               editable      => 1,
                               optional      => 0,
                              ),
       new EBox::Types::Text(
                             fieldName     => 'description',
                             printableName => __('Description'),
                             editable      => 1,
                             optional      => 1,
                            ),
      );

      my $dataTable = {
      'tableName'          => 'FixedAddressTable',
      'printableTableName' => __('Fixed addresses'),
      'defaultActions'     =>
        [ 'add', 'del', 'editField', 'changeView' ],
      'modelDomain'        => 'DHCP',
      'tableDescription'   => \@tableDesc,
      'class'              => 'dataTable',
      'rowUnique'          => 1,  # Set each row is unique
      'printableRowName'   => __('fixed address'),
      'order'              => 0,  # Ordered by tailoredOrder
      'sortedBy'           => 'object',
      'noDataMsg'         => _message(1),
        };

    return $dataTable;

}


sub objectModelGetter
{
    my ($self) = @_;

    my $global = $self->global();
    return sub {
        return $global->modInstance('objects')->model('ObjectTable');
    };
}

sub _message
{
    my ($empty) = @_;
    my $msg;
    if ($empty) {
        $msg = __('Not object added for fixed addresses') . '<p>';
    }

    $msg .=  __('Only those object members whose IP address is a host (/32), a '
              . 'valid MAC, the IP address is not used by the available range '
              . 'and whose name is unique as fixed address will be used') . '. '
         . __('Members whose name is not a valid hostname will be modified to '
              . 'become a valid domain name.');
}


sub addresses
{
    my ($self, $iface, $readOnly) = @_;
    my %addrs;

    my $global = $self->global();
    my $objMod = $global->modInstance('objects');
    for my $id (@{$self->ids()}) {
        my $row   = $self->row($id);
        my $objId = $row->valueByName('object');
        my $mbs   = $objMod->objectMembers($objId);
        # TODO: Restore this when more than one config per interface is possible
        $addrs{$objId} = { options => {},#$self->_thinClientOptions($iface, $objId),
                           members => [] };

        foreach my $member (@{$mbs}) {
            # use only IP address member type
            if ($member->{type} ne 'ipaddr') {
                next;
            }

            # Filter out the ones which does not have a MAC address
            # and a mask of 32, it does not belong to the given
            # interface and member name is unique within the fixed
            # addresses realm
            if ( $self->_allowedMemberInFixedAddress($iface, $member, $objId, $readOnly) ) {
                push (@{$addrs{$objId}->{members}}, {
                    name => $member->{name},
                    ip   => $member->{ip},
                    mac  => $member->{macaddr},
                });
            }
        }
    }

    if ( $readOnly ) {
        # The returned value is grouped by object id
        return \%addrs;
    } else {
        my @mbs = ();
        foreach my $obj (values %addrs) {
            push(@mbs, @{$obj->{members}});
        }
        return \@mbs;
    }
}

# Check if the given member is allowed to be a fixed address in the
# given interface
# It should match the following criteria:
#  * The member name must be a valid hostname
#    - If not, then the member name is become to a valid one
#  * Be a valid host IP address
#  * Have a valid MAC address
#  * The IP address must be in range available for the given interface
#  * It must be not used by in the range for the given interface
#  * It must be not the interface address
#  * The member name must be unique in the object realm
#  * The MAC address must be unique for subnet
#
sub _allowedMemberInFixedAddress
{
    my ($self, $iface, $member, $objId, $readOnly) = @_;

    unless (EBox::Validate::checkDomainName($member->{'name'})) {
        $member->{'name'} = lc($member->{'name'});
        $member->{'name'} =~ s/[^a-z0-9\-]/-/g;
    }

    if ($member->{mask} != 32 or (not defined($member->{macaddr}))) {
        return 0;
    }

    my $dhcp     = $self->parentModule();
    my $memberIP = new Net::IP($member->{ip});
    my $gl       = EBox::Global->getInstance($readOnly);
    my $net      = $gl->modInstance('network');
    my $objs     = $gl->modInstance('objects');
    my $netIP    = new Net::IP($dhcp->initRange($iface)
                               . '-' . $dhcp->endRange($iface));

    # Check if the IP address is within the network
    unless ($memberIP->overlaps($netIP) == $IP_A_IN_B_OVERLAP) {
        # The IP address from the member is not in the network
        EBox::debug('IP address ' . $memberIP->print() . ' is not in the '
                    . 'network ' . $netIP->print());
        return 0;
    }

    # Check the IP address is not the interface address
    my $ifaceIP = new Net::IP($net->ifaceAddress($iface));
    unless ( $memberIP->overlaps($ifaceIP) == $IP_NO_OVERLAP ) {
        # The IP address is the interface IP address
        EBox::debug('IP address ' . $memberIP->print() . " is the $iface interface address");
        return 0;
    }

    # Check the member IP address is not within any given range by
    # RangeTable model
    my $rangeModel = $dhcp->_getModel('RangeTable', $iface);
    foreach my $id (@{$rangeModel->ids()}) {
        my $rangeRow = $rangeModel->row($id);
        my $from     = $rangeRow->valueByName('from');
        my $to       = $rangeRow->valueByName('to');
        my $range    = new Net::IP( $from . '-' . $to);
        unless ( $memberIP->overlaps($range) == $IP_NO_OVERLAP ) {
            # The IP address is in the range
            EBox::debug('IP address ' . $memberIP->print() . ' is in range '
                        . $rangeRow->valueByName('name') . ": $from-$to");
            return 0;
        }
    }

    # Check the given member is unique within the object realm
    my $network = $dhcp->global()->modInstance('network');
    my @otherDHCPIfaces = grep {
        my $other = $_;
        ($network->ifaceMethod($other) eq 'static') and
        ($other ne $iface)
    } @{ $network->InternalIfaces()  };
    my @fixedAddressTables = map {
        $dhcp->_getModel('FixedAddressTable', $_)
    } @otherDHCPIfaces;

    foreach my $model (@fixedAddressTables) {
        my $ids = $model->ids();
        foreach my $id (@{$ids}) {
            my $row = $model->row($id);
            my $otherObjId = $row->valueByName('object');
            my $mbs = $objs->objectMembers($otherObjId);
            next if ( $otherObjId eq $objId); # If they are the same object

            # Check for the same member name in other object
            my @matches = grep { $_->{name} eq $member->{name} } @{$mbs};
            foreach my $match (@matches) {
                next unless ( $match->{mask} == 32 and defined($match->{macaddr}));
                EBox::warn('IP address ' . $memberIP->print() . ' not added '
                           . 'because there are two members with the same name '
                           . $member->{name} . ' in other fixed address table');
                return 0;
            }
        }
    }

    # Check for the same MAC address
    my $fixedAddrModel = $dhcp->_getModel('FixedAddressTable', $iface);
    my $ids = $fixedAddrModel->ids();
    foreach my $id ( @{$ids} ) {
        my $row = $fixedAddrModel->row($id);
        my $otherObjId = $row->valueByName('object');
        next if ( $otherObjId eq $objId ); # Check done by unique MAC address property
        my $mbs = $objs->objectMembers($otherObjId);
        my @matches = grep {
            defined($_->{macaddr})
            and ($_->{macaddr} eq $member->{macaddr})
            and ($_->{name} ne $member->{name})
        } @{$mbs};
        if ( @matches > 0 ) {
            EBox::warn('MAC address ' . $member->{macaddr} . ' is being '
                       . 'used by ' . $member->{name} . ' and, at least, '
                       . $matches[0]->{name});
            return 0;
        }
    }

    return 1;
}


1;
