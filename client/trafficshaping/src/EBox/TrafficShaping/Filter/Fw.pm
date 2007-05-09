# Copyright (C) 2006 Warp Networks S.L.
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

package EBox::TrafficShaping::Filter::Fw;

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::InvalidData;

use EBox::TrafficShaping;

use constant MARK_MASK => '0xFF00';
use constant LOWEST_PRIORITY => 7;

# Constructor: new
#
#       Constructor for FwFilter class. It should extendable to all
#       kinds of filter but we use iptables filter. So it will be a fw
#       filter.
#
# Parameters:
#
#     - Following are *tc* arguments to do filtering:
#
#       flowId - A hash containing the following entries:
#                - rootHandle - handle from root qdisc
#                - classId    - class id
#       mark - Number used in packet to do filtering afterwards
#
#       parent - parent where filter is attached to (it's a
#       <EBox::TrafficShaping::QDisc>)
#
#       protocol - Only ip it's gonna be supported *(Optional)*
#
#       prio - Filter priority. If several filters are attached to the
#       same qdisc, they're asked in priority sections. Lower number,
#       higher priority. *(Optional)*
#
#       identifier - the filter identifier *(Optional)*
#                    Default value: $flowId->{classId}
#
#     - Following are *iptables* arguments to do filtering:
#
#       service   - <EBox::Types::Service> the service to do filtering
#                   *(Optional)*
#       srcAddr   - <EBox::Types::IPAddr> or <EBox::Types::MACAddr> the
#                   packet source to match *(Optional)*
#       dstAddr   - <EBox::Types::MACAddr> the packet destination to match
#                   *(Optional)*
#       matchPrio - int (0-7) the priority which will have at the
#                   iptables matching *(Optional)* Default value:
#                   lowest priority = 7
#
#       If none is provided, the default redundant mark will be applied
#       - Named parameters
#
# Returns:
#
#      A recently created <EBox::TrafficShaping::Filter::Fw> object
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - throw if parameter is not
#      passed
#      <EBox::Exceptions::InvalidType> - throw if parameter is
#      not with the correct type
#      <EBox::Exceptions::InvalidData> - throw if parameter protocol is not ip one
#
sub new
  {
    my $class = shift;
    my %args = @_;
    my $self = {};

    # Treat arguments
    throw EBox::Exceptions::MissingArgument( 'flowId' )
      unless defined( $args{flowId} );
    throw EBox::Exceptions::MissingArgument( 'mark' )
      unless defined( $args{mark} );
    throw EBox::Exceptions::MissingArgument( 'parent' )
      unless defined( $args{parent} );

    # Check flowId has the correct keys
    if ( not( defined( $args{flowId}->{rootHandle} ) and
	      defined( $args{flowId}->{classId} ) )) {
      throw EBox::Exceptions::InvalidType( 'flowId',
			 'a hash with rootHandle and classId as arguments');
    }
    # Check protocol
    if ( defined( $args{protocol} ) ) {
      if ( not $args{protocol} eq 'ip' ) {
	throw EBox::Exceptions::InvalidData( data => 'protocol');
      }
    }
    # Check parent
    if ( not $args{parent}->isa( 'EBox::TrafficShaping::QDisc::Base' ) ) {
      throw EBox::Exceptions::InvalidType( 'parent',
					   'EBox::TrafficShaping::QDisc::Base' );
    }
    # Check the service
    if ( defined ( $args{service} ) and 
	 not $args{service}->isa( 'EBox::Types::Service' ) ) {
      throw EBox::Exceptions::InvalidType( 'service',
					   'EBox::Types::Service');
    }
    # Check addresses
    if ( $args{srcAddr} ) {
      if ( not $args{srcAddr}->isa('EBox::Types::IPAddr') and
	   not $args{srcAddr}->isa('EBox::Types::MACAddr') ) {
	throw EBox::Exceptions::InvalidType( 'srcAddr',
					     'EBox::Types::IPAddr or EBox::Types::MACAddr');
      }
    }
    if ( $args{dstAddr} ) {
      if ( not $args{dstAddr}->isa('EBox::Types::IPAddr') ) {
	throw EBox::Exceptions::InvalidType( 'srcAddr',
					     'EBox::Types::IPAddr');
      }
    }

    # We take the identifier as the flowId->classid
    $self->{id} = $args{identifier};
    $self->{id} = $args{flowId}->{classId} unless  $args{identifier};
    $self->{flowId} = $args{flowId};
    $self->{mark} = $args{mark};
    $self->{protocol} = $args{protocol};
    # If no protocol is given, use ip by default
    $self->{protocol} = "ip" unless defined( $args{protocol} );
    $self->{prio} = $args{prio};
    $self->{parent} = $args{parent};

    if ( defined ( $args{service} ) ) {
      $self->{fProtocol} = $args{service}->protocol();
      $self->{fPort} = $args{service}->port();
    }

    if ( $args{srcAddr} ) {
      if ( $args{srcAddr}->isa('EBox::Types::IPAddr')) {
	$self->{srcIP} = $args{srcAddr}->ip();
	$self->{srcNetMask} = $args{srcAddr}->mask();
      }
      elsif ( $args{srcAddr}->isa('EBox::Types::MACAddr') ) {
	$self->{srcMAC} = $args{srcAddr}->value();
      }
    }
    if ( $args{dstAddr} ) {
      $self->{dstIP} = $args{dstAddr}->ip();
      $self->{dstNetMask} = $args{dstAddr}->mask();
    }

    # Iptables priority
    $self->{matchPrio} = $args{matchPrio};
    $self->{matchPrio} = LOWEST_PRIORITY unless defined ( $self->{matchPrio} );

    bless($self, $class);

    return $self;

  }

# Method: equals
#
#       Check equality between an object and this
#
# Parameters:
#
#       object - the object to compare
#
# Returns:
#
#       true - if the object is the same
#       false - otherwise
#
# Exceptions:
#
#       <EBox::Exceptions::InvalidType> - if object is not the correct type
#
sub equals # (object)
  {

    my ($self, $object) = @_;

    throw EBox::Exceptions::InvalidType('object', 'EBox::TrafficShaping::Filter::Fw')
      unless $object->isa( 'EBox::TrafficShaping::Filter::Fw' );

    return $object->getIdentifier() == $self->getIdentifier();

  }

# Method: getIdentifier
#
#       Accessor to the filter identifier
#
# Returns:
#
#       Integer - the unique filter identifier
#
sub getIdentifier
  {

    my ($self) = @_;

    return $self->{id};

  }

# Method: attribute
#
#       Get an attribute from the filter
#
# Parameters:
#
#       name - String with the attribute's name
#
# Returns:
#
#       the attribute's value
#
sub attribute # (name)
  {

    my ($self, $name) = @_;

    if (not defined ( $self->{$name} ) ) {
      return undef;
    }

    return $self->{$name};

  }

# Method: setAttribute
#
#       Set an attribute from the filter
#
# Parameters:
#
#       name  - String with the attribute's name
#       value - String with the new attribute's value
#
sub setAttribute # (name, value)
  {

    my ($self, $name, $value) = @_;

    if (not defined ( $self->{$name} ) or
	not defined ( $value ) ) {
      return;
    }

    # Set the new value
    $self->{$name} = $value

  }

# Method: dumpTcCommand
#
#       Dump tc command needed to run to make the filter ready in tc
#
#
# Returns:
#
#       String - the tc command (only the *arguments* indeed)
#
sub dumpTcCommand
  {

    my ( $self ) = @_;

    my $iface = $self->{parent}->getInterface();
    my %parentId = %{$self->{parent}->getIdentifier()};

    my $tcCommand = "filter add dev $iface parent " .
      "$parentId{major}:$parentId{minor} ";
    $tcCommand .= "prio " . $self->{prio} . " "
      if ( $self->{prio} );
    $tcCommand .= "protocol " . $self->{protocol} . " ";
    $tcCommand .= "handle " . $self->getIdentifier() . " ";
    $tcCommand .= "fw flowid " . $self->{flowId}->{rootHandle} .
      ":" . $self->{flowId}->{classId} . " ";

    return $tcCommand;

  }

# Method: dumpIptablesCommands
#
#       Dump iptables commands needed to run to make the filter ready
#       in iptables
#
#
# Returns:
#
#       array ref - array with all needed command arguments
#
sub dumpIptablesCommands
  {

    my ($self) = @_;

    # Getting the mask number
    my $mask = hex ( MARK_MASK );
    # Applying the mask
    my $mark = $self->{mark} & $mask;
    my $protocol = $self->{fProtocol};

    # Set no port if protocol is all
    my $sport = undef;
    my $dport = undef;
    unless ( defined ( $protocol ) and
	 ($protocol eq EBox::Types::Service->AnyProtocol )) {
      $sport = $self->{fPort};
      $dport = $self->{fPort};
    }
    my $srcIP = $self->{srcIP};
    my $srcMAC = $self->{srcMAC};
    my $srcNetMask = $self->{srcNetMask};
    my $dstIP = $self->{dstIP};
    my $dstNetMask = $self->{dstNetMask};

    my $shaperChain;
    if ( defined ( $srcMAC ) ) {
      $shaperChain = EBox::TrafficShaping->ShaperChain($self->{parent}->getInterface(),
						       'forward');
    }
    else {
      $shaperChain = EBox::TrafficShaping->ShaperChain($self->{parent}->getInterface(),
						       'egress');
    }

    my @ipTablesCommands;
    my $leadingStr;
    my $mediumStr;
    if ( defined ( $protocol ) or defined ( $srcIP ) or defined ( $dstIP )) {
      my $leadingStr = "-t mangle -A $shaperChain ";
      my $trailingStr = "-j MARK --set-mark $mark";
      my $mediumStr = q{};

      # Mark if the packet is not already marked
      $mediumStr .= '-m mark --mark 0/' . MARK_MASK . ' ';
      $mediumStr .= "--protocol $protocol " if ( defined ( $protocol ));
      $mediumStr .= "--sport $sport " if ( $sport );
      $mediumStr .= "--source $srcIP" if ( defined ( $srcIP ));
      $mediumStr .= "-m mac --mac-source $srcMAC " if ( defined( $srcMAC) );
      $mediumStr .= "/$srcNetMask" if ( defined ( $srcNetMask ));
      $mediumStr .= q{ }; # Adding a trailing space
      $mediumStr .= "--destination $dstIP" if ( defined ( $dstIP ));
      $mediumStr .= "/$dstNetMask" if ( defined ( $dstNetMask ));
      $mediumStr .= q{ }; # Adding a trailing space
      # Set source port
      push(@ipTablesCommands,
	   $leadingStr . $mediumStr . $trailingStr
	  );
      if ( $self->{fPort} ) {
	# Substituying from src to dst
	$mediumStr =~ s/--sport [0-9]+ /--dport $dport /g;
	# Set destination port
	push(@ipTablesCommands,
	     $leadingStr . $mediumStr . $trailingStr
	    );
      }
    } else {
      # Set redundant mark to send to default one
      push(@ipTablesCommands,
	   "-t mangle -A $shaperChain -m mark --mark 0/" . MARK_MASK . ' ' .
	   "-j MARK --set-mark $mark"
	  );
    }

    return \@ipTablesCommands;

  }

1;
