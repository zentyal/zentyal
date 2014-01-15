# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::TrafficShaping::TreeBuilder::Abstract;

use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use Tree;

#       TreeBuilder::Abstract is an abstract class.  It is an
#       abstract interface to create parts of a tree of qdisc and
#       classes for traffic control. It is using a Builder design
#       pattern.

# Method: _init
#
#       Initilization done by all subclasses in constructor
#
# Parameters:
#
#       interface - interface where the builder is attached
#
# Exceptions:
#
#       <EBox::Exceptions::MissingArgument> - throw if any argument is
#       missing
#
sub _init
  {

    my ($self, $iface) = @_;

    throw EBox::Exceptions::MissingArgument( 'interface' )
      unless defined( $iface );

    # Set up the tree, setting root value as self object
    $self->{treeRoot} = undef;

    # Setting up the common attributes
    $self->{interface} = $iface;

  }

# Method: buildRoot
#
#         Build base for a queue discipline
#
# Parameters:
#
#         defaultClass - default class where all unknown traffic is
#         sent
#
# Returns:
#
#         <Tree> - the tree built
#
sub buildRoot
  {

    throw EBox::Exceptions::NotImplemented();

  }

# Method: dumpTcCommands
#
#         Dump from the tree all tc commands without the path from the
#         built tree
#
# Returns:
#
#         array ref - each element contain tc arguments
#
# Exceptions:
#
#         <EBox::Exceptions::Internal> - throw if buildRoot has not been called before
#
sub dumpTcCommands
  {
    my ( $self ) = @_;

    throw EBox::Exceptions::Internal unless defined( $self->{treeRoot} );

    my @nodes = $self->{treeRoot}->traverse( $self->{treeRoot}->LEVEL_ORDER );

    # Class and qdisc commands
    my @tcCommands;
    # Filter commands attached to the qdisc
    my @tcFilterCommands;
    foreach my $node (@nodes) {
      # Run dumpTcCommands
      my @newTcCommands = @{$node->value()->dumpTcCommands()};
      # Take the filter commands
      my @newTcFilterCommands = grep { /^filter/ } @newTcCommands;
      # Delete them
      @newTcCommands = grep { !/^filter/ } @newTcCommands;
      # Store in the tc commands
      push (@tcCommands,  @newTcCommands);
      push (@tcFilterCommands, @newTcFilterCommands);
    }

    # Now adds the filter commands
    push (@tcCommands, @tcFilterCommands);

    # Return the reference
    return \@tcCommands;

  }

# Method: dumpIptablesCommands
#
#         Dump from the tree all iptables commands without the path from the
#         built tree
#
# Returns:
#
#         array ref - each element contains iptables *arguments*
#
# Exceptions:
#
#         <EBox::Exceptions::Internal> - throw if buildRoot has not been called before
#
sub dumpIptablesCommands
  {
    my ( $self ) = @_;

    throw EBox::Exceptions::Internal unless defined( $self->{treeRoot} );

    my @nodes = $self->{treeRoot}->traverse( $self->{treeRoot}->LEVEL_ORDER );

    my @iptCommands;
    foreach my $node (@nodes) {
      my $value = $node->value();

      next unless
	$value->isa( 'EBox::TrafficShaping::QDisc::Base' ) or
	  ( $value->isa( 'EBox::TrafficShaping::Class' ) and
	    defined( $value->getAttachedQDisc() ));

      my @newIptCommands;
      if ( $value->isa( 'EBox::TrafficShaping::QDisc::Base' ) ) {
	@newIptCommands = @{$value->dumpIptablesCommands()};
      } elsif ($value->isa( 'EBox::TrafficShaping::Class' )) {
	@newIptCommands =
	  @{$value->getAttachedQDisc()->dumpIptablesCommands()};
      }

      # Store the iptables commands
      push (@iptCommands,  @newIptCommands);
    }

    # Remove duplicated iptables commands
    my @uniqueIPTCommands = ();
    my %seen = ();
    foreach my $elem (@iptCommands) {
        next if $seen{$elem}++;
        push(@uniqueIPTCommands, $elem);
    }

    # Return the reference
    return \@uniqueIPTCommands;

  }

# Method: dumpProtocols
#
#       Dump l7 filter protocols and its iptables mark
#
# Returns:
#
#       hash ref - array containing l7 filter protocols as keys and marks as values
#
# Exceptions:
#
#         <EBox::Exceptions::Internal> - throw if buildRoot has not been called before
#
sub dumpProtocols
{
    my ( $self ) = @_;

    throw EBox::Exceptions::Internal unless defined( $self->{treeRoot} );

    my %protocols;
    my @nodes = $self->{treeRoot}->traverse( $self->{treeRoot}->LEVEL_ORDER );

    foreach my $node (@nodes) {
        my $value = $node->value();

        next unless
            $value->isa( 'EBox::TrafficShaping::QDisc::Base' ) or
            ( $value->isa( 'EBox::TrafficShaping::Class' ) and
              defined( $value->getAttachedQDisc() ));

        my %newProtocols;
        if ( $value->isa( 'EBox::TrafficShaping::QDisc::Base' ) ) {
            %newProtocols = %{$value->dumpProtocols()};
        } elsif ($value->isa( 'EBox::TrafficShaping::Class' )) {
            %newProtocols = %{$value->getAttachedQDisc()->dumpProtocols()};
        }

        foreach my $protocol ( keys %newProtocols ) {
            $protocols{$protocol} = $newProtocols{$protocol};
        }
    }

    return \%protocols;
}

# Method: getInterface
#
#         Accessor to the interface attached to the builder
#
# Returns:
#
#         String - the interface attached to the builder
#
sub getInterface
  {

    my ($self) = @_;

    return $self->{interface};

  }

1;
