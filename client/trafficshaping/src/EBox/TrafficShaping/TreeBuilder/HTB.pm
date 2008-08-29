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

package EBox::TrafficShaping::TreeBuilder::HTB;

use strict;
use warnings;

# Its parent class is AbstractTreeBuilder
use base 'EBox::TrafficShaping::TreeBuilder::Abstract';

use EBox::TrafficShaping::Class;
use EBox::TrafficShaping::QDisc::Base;
use EBox::TrafficShaping::QDisc::Root;
use EBox::TrafficShaping::Filter::Fw;
use EBox::TrafficShaping::QueueDiscipline::HTB;
use EBox::TrafficShaping::QueueDiscipline::SFQ;

use EBox::Exceptions::MissingArgument;

use EBox::Iptables;

use EBox::Gettext;

# Dependencies
use Clone;

use constant R2Q => 5;
# We assume an MTU of 1500 Bytes
use constant MTU => 1500;
# Maximum rate allowed by the network card (Ex. 1Gb/s)
use constant MAX_RATE => 10 * (2 ** 20);

# Constructor: new
#
#       Constructor for TreeBuilder::HTB class. It encapsulates
#       all HTB logic. It acts a concrete builder in Builder pattern.
#
# Parameters:
#
#       interface - Interface to build the tree
#       trafficShaping - <EBox::TrafficShaping> module which this class belongs to
#
# Returns:
#
#      A recently created <EBox::TrafficShaping::TreeBuilder::HTB> object
#
sub new # (iface)
  {

    my ($class, $iface, $trafficShaping) = @_;
    my $self = {};

    $self->{trafficShaping} = $trafficShaping;
    $self->{defaultClass} = undef;

    bless($self, $class);

    # Set up the all things
    $self->SUPER::_init($iface);

    return $self;

  }

# Method: buildRoot
#
#         Implement <EBox::TrafficShaping::AbstractTreeBuilder::buildRoot> method.
#
# Parameters:
#
#         defaultClass - default class where all unknown traffic is
#         sent
#
#         rate - Int Maximum rate are guaranteed in Kilobits per
#         second
#
# Returns:
#
#         <Tree> - the tree built
#
# Exceptions:
#
#         <EBox::Exceptions::MissingArgument> - throw if any mandatory
#         argument is missing
#
sub buildRoot # (defaultClass, rate)
  {

    my ($self, $defaultClass, $rate) = @_;

    $self->{rate} = $rate;
    throw EBox::Exceptions::MissingArgument('defaultClass')
      unless defined( $defaultClass );
    throw EBox::Exceptions::MissingArgument('rate')
      unless defined( $self->{rate} );


    # There are different ways to implement depending on if the
    # interface is internal or external
    my $netMod = EBox::Global->modInstance('network');
    my $external = $netMod->ifaceIsExternal($self->getInterface());

    # Set maximum rate for the root class
    my $maxRate;
    if ( $external ) {
        $maxRate = $self->{rate};
    } else {
        $maxRate = MAX_RATE;
    }

    # Set highest major number
    $self->{highestMajorNumber} = $defaultClass + 1;

    # HTB qdisc root

    # We set r2q to the half (5) because minimum guaranteed rate would
    # be 1200 kbit/s and in my dev country (Spain) this upload rate is
    # quite high. It is due to quantum given to the exceeded rate
    # given to a class. A more detailed explanation is pointed at
    # http://www.docum.org/docum.org/faq/cache/31.html
    my $HTBRoot = EBox::TrafficShaping::QueueDiscipline::HTB->new(
								  defaultClass => $defaultClass,
								  r2q          => R2Q,
								 );
    my $rootQDisc = EBox::TrafficShaping::QDisc::Root->new(
							 interface   => $self->getInterface(),
							 majorNumber => 1,
							 realQDisc   => $HTBRoot,
							);

    # Create the tree structure
    $self->{treeRoot} = Tree->new($rootQDisc);

    # Create unique child class from root qdisc
    my $childHTB = EBox::TrafficShaping::QueueDiscipline::HTB->new(
								   rate => $maxRate,
								   ceil => $maxRate,
                                                                  );
    my $childClass = EBox::TrafficShaping::Class->new(
                                                      minorNumber     => 1,
                                                      parent          => $self->{treeRoot},
                                                      queueDiscipline => $childHTB,
                                                     );

    # We add to the tree
    my $childNode = Tree->new( $childClass );
    $self->{treeRoot}->add_child( $childNode );

    if ( $external ) {
        $self->_createExternalStructure($defaultClass);
    } else {
        $self->_createInternalStructure($defaultClass);
    }

    return $self->{treeRoot};

  }

# Method: buildRule
#
#        Add a new rule to the tc tree
#
# Parameters:
#
#    service        - String the service identifier related to ebox-services module
#                     *(Optional)*
#    source         - <EBox::Types::IPAddr> or <EBox::Types::MACAddr> the source
#                     *(Optional)*
#    destination    - <EBox::Types::IPAddr> the destination *(Optional)*
#    guaranteedRate - maximum guaranteed rate in Kilobits per second
#                     0 => no guaranteed rate
#    limitedRate    - maximum allowed rate in Kilobits per second
#                     0 => unlimited rate (maximum for this interface)
#    priority       - filter priority
#    identifier     - identifier attached to the new rule
#                     *(Optional)*
#    testing        - if build the rule, it's only a test.
#                     Default: false *(Optional)*
#
#    - (Named Parameters)
#
# Returns:
#
#    hash ref - the built class identifier to manage the
#    new rule, useful to destroy rules
#
# Exceptions:
#
#    <EBox::Exceptions::InvalidData> - throw if the new data
#    introduced is invalid
#    <EBox::Exceptions::External> - throw if the new data violates
#    the rest stuff
#    <EBox::Exceptions::MissingArgument> - throw if any argument is missing
#
sub buildRule
  {

    my ($self, %args) = @_;

    throw EBox::Exceptions::MissingArgument ( 'Missing one of the 3 elements' )
      unless ( scalar( keys %args ) >= 3 );

    # Check guaranteed rate
    if (not $self->_canSupportGuaranteedRate( $args{guaranteedRate} )){
      throw EBox::Exceptions::External(__x('Guaranteed Rate exceeds the allowed rate: {rate} kbit/s',
					   rate => $self->_allowedGuaranteedRate()));
    }

    if ($args{guaranteedRate} != 0 ) {
      if ($args{guaranteedRate} < $self->_minimumAllowedQuantum() or
	  $args{guaranteedRate} > $self->_maximumAllowedQuantum()) {
	throw EBox::Exceptions::External(__x('Guaranteed Rate must be in this interval: ( {minRate}, ' .
					     '{maxRate} ) kbit/s',
					     minRate => $self->_minimumAllowedQuantum(),
					     maxRate => $self->_maximumAllowedQuantum(),
					     rate => $args{guaranteedRate},
					    ));
      }
    }

    # Check limited rate
    if ($args{guaranteedRate} != 0 and $args{limitedRate} != 0 and
	$args{guaranteedRate} > $args{limitedRate} ) {
      throw EBox::Exceptions::External(__x("Limited Rate {lR} kbit/s should be " .
					  "higher than Guaranteed Rate {gR}kbit/s",
					  lR => $args{limitedRate},
					  gR => $args{guaranteedRate}));
    }
    # Check limited rate -> sum(children(ceil)) <= parent(ceil)
    if (not $self->_canSupportLimitedRate( $args{limitedRate} )) {
      throw EBox::Exceptions::External(__x('Limited Rate {lR} kbit/s should be ' .
					   'lower than {maxLR}kbit/s or you should increase ' .
					   'maximum upload traffic to the gateways associated ' .
					   'to this external interface',
					  lR    => $args{limitedRate},
					  maxLR => $self->_allowedLimitedRate()));
    }

    # All remainder parameters has been checked by TrafficShaping
    # class
    # The rule can be added now
    if ( $args{testing} ) {
      return undef;
    }

    # Parent node
    my $childNode = $self->_parentUserDefinedClassesNode();
    # It's high time to add class to the tree
    my $emptySFQ = EBox::TrafficShaping::QueueDiscipline::SFQ->new();

    my $classId;
    # If the class id comes from arguments take from them
    if ( defined( $args{identifier} ) ) {
      $classId = $args{identifier};
    }

    else {
      $classId = $self->_getMajorNumber();
    }

    my $leafQDisc = EBox::TrafficShaping::QDisc::Base->new(
						     majorNumber => $classId,
						     realQDisc   => $emptySFQ,
						    );

    # If limited rate is set to 0, the maximum rate allowed is the
    # maximum rate of the link
    $args{limitedRate} = $self->{rate} if ( $args{limitedRate} == 0);

    my $HTB = EBox::TrafficShaping::QueueDiscipline::HTB->new(
					     prio => $args{priority},
					     rate => $args{guaranteedRate},
					     ceil => $args{limitedRate},
					    );
    my $leafClass = EBox::TrafficShaping::Class->new(
						       minorNumber     => $classId,
						       parent          => $childNode,
						       qdiscAttached   => $leafQDisc,
						       queueDiscipline => $HTB,
						      );
    # Add recently created class to the tree structure
    my $leafNode = Tree->new( $leafClass );
    $childNode->add_child( $leafNode );
    $leafQDisc->setParent( $leafNode );

    # If there's no policy to classify, not adding a new filter
    if ( defined ( $args{source} ) or defined ( $args{destination} ) or
        defined( $args{service} ) ) {
      # Filter to the new class attached to the root qdisc
      my $rootQDisc = $self->{treeRoot}->value();

      my $filter = new EBox::TrafficShaping::Filter::Fw(
							flowId    => {
								      rootHandle => 1,
								      classId    => $classId
								     },
							mark      => $classId,
						        parent    => $rootQDisc,
							service   => $args{service},
							srcAddr   => $args{source},
							dstAddr   => $args{destination},
							matchPrio => $args{priority},
						       );

      # Attach filter to the root qdisc
      $rootQDisc->attachFilter( $filter );
    }

    # Set lowest priority to class with default traffic
    my $lowest = $self->{trafficShaping}->getLowestPriority($self->{interface}, 'search');
    $self->{defaultClass}->getAssociatedQueueDiscipline()->setAttribute( 'prio', $lowest );
    # Set remainder guaranteed traffic to the default class
    $self->{defaultClass}->getAssociatedQueueDiscipline()->setAttribute( 'rate', $self->_allowedGuaranteedRate() );

    # Rule added!
    return $classId;

  }

# Method: updateRule
#
#         Update a rule from the tc tree
#
# Parameters:
#
#        identifier     - the leaf class identifier which represents the
#        rule internally which is updated
#
#        service        - String the service id *(Optional)*
#        guaranteedRate - maximum gua+ranteed rate in Kilobits per second
#                         *(Optional)*
#        limitedRate    - maximum allowed rate in Kilobits per second
#                         *(Optional)*
#        priority       - filter priority *(Optional)*
#        testing        - if build the rule, it's only a test.
#                         Default: false *(Optional)*
# Exceptions:
#
#    - <EBox::Exceptions::DataNotFound> - throw if the class does not
#    exist
#    - <EBox::Exceptions::InvalidData> - throw if the new data
#    introduced is invalid
#    - <EBox::Exceptions::External> - throw if the new data violates
#    the rest stuff
#    - <EBox::Exceptions::Internal> - throw if the class is NOT a
#    leaf one or it's the *default* one
#
sub updateRule
  {

    my ($self, %args) = @_;

    my $leafClassId = $args{identifier};

    # Treat the argument
    throw EBox::Exceptions::MissingArgument('identifier')
      unless defined( $leafClassId );

#    if ( not( defined( $leafClassId->{minor} ) and
#	      defined( $leafClassId->{major} ) )) {
#      throw EBox::Exceptions::InvalidType( 'leafClass', 
#			 'a hash with major and minor as arguments');
#    }

    $leafClassId = {
		    major => 1,
		    minor => $leafClassId,
		   };

    # Search previous properties
    my $foundNode = $self->_getNode($leafClassId);
    # Throw exception if not found
    if (not defined( $foundNode ) ) {
      use Data::Dumper;
      throw EBox::Exceptions::DataNotFound(
					   data  => 'leafClassId',
					   value => Dumper($leafClassId),
					  );
    }

    my $assocQueue = $foundNode->value()->getAssociatedQueueDiscipline();
    my $prevGuaranteedRate = $assocQueue->attribute('rate');
    my $prevLimitedRate = $assocQueue->attribute('ceil');

    # Check guaranteed rate
    if ( defined ( $args{guaranteedRate} ) ) {
      if (not $self->_canSupportGuaranteedRate( $args{guaranteedRate} - $prevGuaranteedRate )){
	throw EBox::Exceptions::External(__x("Guaranteed Rate exceeded the allowed rate: {rate}",
					     rate => $self->_allowedGuaranteedRate()));
      }
    }

    if ( defined ( $args{guaranteedRate} ) and
	 $args{guaranteedRate} != 0 ) {
      if ($args{guaranteedRate} < $self->_minimumAllowedQuantum() or
	  $args{guaranteedRate} > $self->_maximumAllowedQuantum()) {
	throw EBox::Exceptions::External(__x('Guaranteed Rate must be in this interval: ( {minRate}, ' .
					     '{maxRate} ) kbit/s',
					     minRate => $self->_minimumAllowedQuantum(),
					     maxRate => $self->_maximumAllowedQuantum(),
					    ));
      }
    }

    # Check limited rate
    if ( defined ( $args{limitedRate} ) ){
      if ($args{guaranteedRate} != 0 and $args{limitedRate} != 0 and
	  $args{guaranteedRate} > $args{limitedRate} ) {
	throw EBox::Exceptions::External(__x("Limited Rate {lR} kbit/s should be " .
					     "higher than Guaranteed Rate {gR}kbit/s",
					     lR => $args{limitedRate},
					     gR => $args{guaranteedRate}));
      }

      # Check limited rate -> sum(children(ceil)) <= parent(ceil)
      if (not $self->_canSupportLimitedRate( $args{limitedRate} - $prevLimitedRate )) {
	throw EBox::Exceptions::External(__x("Limited Rate {lR} kbit/s should be " .
					     "lower than {maxLR} or you should increase " .
					     "maximum allowed traffic",
					     lR    => $args{limitedRate},
					     maxLR => $self->_allowedLimitedRate()));
      }
    }

    # All remainder parameters has been checked by TrafficShaping
    # class
    # The rule can be added now
    if ( $args{testing} ) {
      return undef;
    }

    # TODO: Actually, update rule
    # FIXME Dead code?
    # First the associated queue
    $assocQueue->setAttribute('prio', $args{priority}) if defined ( $args{priority} );
    $assocQueue->setAttribute('rate', $args{guaranteedRate}) if defined ( $args{guaranteedRate} );
    $assocQueue->setAttribute('ceil', $args{limitedRate}) if defined ( $args{limitedRate} );
    # Then the filter
    my $filterAssoc = $self->_findFilterFromClass($leafClassId);
    $filterAssoc->setAttribute('service', $args{service}) if defined ( $args{service} );

  }


# Method: destroyRule
#
#        Remove a rule from the tc tree
#
# Parameters:
#
#        leafClassId - the leaf class identifier
#        which represents the rule internally which is destroyed
#
# Exceptions:
#
#    - <EBox::Exceptions::DataNotFound> - throw if the class does not
#    exist
#    - <EBox::Exceptions::Internal> - throw if the class is NOT a
#    leaf one or it's the *default* one
#    - <EBox::Exceptions::MissingArgument> - throw if any argument is
#    missing
#    - <EBox::Exceptions::InvalidType> - throw if the argument
#    type is NOT correct
#
sub destroyRule # (leafClassId)
  {

    my ($self, $leafClassId) = @_;

    # Treat the argument
    throw EBox::Exceptions::MissingArgument('leafClassId')
      unless defined( $leafClassId );

#    if ( not( defined( $leafClassId->{minor} ) and
#	      defined( $leafClassId->{major} ) )) {
#      throw EBox::Exceptions::InvalidType( 'leafClass', 
#			 'a hash with major and minor as arguments');
#    }

    $leafClassId = {
		    major => 1,            # FIXME: when more than a root qdisc will be settled on
		    minor => $leafClassId,
		   };

    throw EBox::Exceptions::Internal('The leaf class is the default one')
      if ($self->{defaultClass}->equals( $leafClassId ));

    my $foundNode = $self->_getNode($leafClassId);

    # Throw exception if not found
    if (not defined( $foundNode ) ) {
      use Data::Dumper;
      throw EBox::Exceptions::DataNotFound(
					   data  => 'leafClassId',
					   value => Dumper($leafClassId),
					  );
    }

    # Let's start to destroy the rule
    # Delete the node
    my $filterId = $leafClassId->{minor};
    # $childNode->remove_child( $foundNode );
    $self->_removeNode( $foundNode );

    # De-attach the filter from root qdisc
    my $rootQDisc = $self->{treeRoot}->value();
    $rootQDisc->deAttachFilter( $filterId );
    # Set lowest priority to default class and the remainder
    # guaranteed rate
    my $lowest = $self->{trafficShaping}->getLowestPriority(
							    $self->{interface},
							    'search',
							   );
    $self->{defaultClass}->getAssociatedQueueDiscipline()->setAttribute('prio', $lowest );
    $self->{defaultClass}->getAssociatedQueueDiscipline()->setAttribute('rate', $self->_allowedGuaranteedRate() );

  }

# Method: findLeafClassId
#
# Parameters:
#
#        protocol       - inet protocol
#        port           - port number
#        guaranteedRate - maximum guaranteed rate in Kilobits per second
#        limitedRate    - maximum allowed rate in Kilobits per second
#
# Returns:
#
#        hash ref - with the identifier
#
sub findLeafClassId
  {

    my ($self, %args) = @_;

    # Get class id related with such
    my $classesAssociated_ref = $self->_findTargetFromFilter($args{protocol}, $args{port});

    my $childNode = $self->_parentUserDefinedClassesNode();
    my @leafNodes = $childNode->children();
    # Node which has the node to destroy
    my $foundNode;
    foreach my $leafNode (@leafNodes) {
      my $class = $leafNode->value();
      foreach my $classAssociated (@{$classesAssociated_ref}) {
	if ( $class->equals($classAssociated) ) {
	  my $qd = $class->getAssociatedQueueDiscipline();
	  next unless $qd->attribute('rate') == $args{guaranteedRate};
	  next unless $qd->attribute('ceil') == $args{limitedRate};
	  $foundNode = $leafNode;
	}
	last if ( defined ($foundNode) );
      }
      last if ( defined ( $foundNode ));
    }

    return undef unless defined ( $foundNode );
    # If found, returns the identifier leaf class
    return $foundNode->value()->getIdentifier();

  }

# Method: addFilter
#
#     Add a filter to classify traffic to direct to a certain leaf class.
#     At least, a source address or destination address should be provided.
#
# Parameters:
#
#    leafClassId - Int the leaf class identifier to direct traffic which
#                  matches with the given filter value
#    priority    - Int the filter priority
#    srcAddr - a source address (<EBox::Types::IPAddr> or <EBox::Types::MACAddr>) *(Optional)*
#    dstAddr - a destination address (<EBox::Types::IPAddr>) *(Optional)*
#    service   - undef or <EBox::Types::Union> from 
#                <EBox::TrafficShaping::Model::RuleTable> that can contains
#                 a port based service, l7 protocol service or a group
#                 of l7 protocol services.
#                  
#                 If undef, any service is assumed
#
#    id      - the filter identifier *(Optional)*
#              Default value: $leafClassId
#
#    - Named Parameters
#
# Exceptions:
#
#    <EBox::Exceptions::MissingArguments> - throw if any of the parameters
#                                           is missing
#
sub addFilter
  {

    my ($self, %params) = @_;

    my $leafClassId = delete $params{leafClassId};
    my $service = delete $params{service};
    my $srcAddr = delete $params{srcAddr};
    my $dstAddr = delete $params{dstAddr};
    my $id = delete $params{id};
    my $priority = delete $params{priority};

    throw EBox::Exceptions::MissingArgument(__('Leaf class identifier'))
      unless defined ( $leafClassId );
    throw EBox::Exceptions::MissingArgument('Filter priority')
      unless defined ( $priority );
    throw EBox::Exceptions::MissingArgument(__('Address'))
      unless defined ( $srcAddr ) or defined ( $dstAddr );

    $leafClassId = {
		    major => 1,            # FIXME: when more than a root qdisc will be settled on
		    minor => $leafClassId,
		   };

    my $filter = undef;
    # The filters are attached to the root
    my $rootQDisc = $self->{treeRoot}->value();

    # Set filter identifier
    $id = $leafClassId->{minor} unless ( defined ( $id ) );

    $filter = new EBox::TrafficShaping::Filter::Fw(
						   identifier => $id,
						   flowId     => {
							          rootHandle => 1,
								  classId    => $leafClassId->{minor}
								 },
						   mark       => $leafClassId->{minor},
						   parent     => $rootQDisc,
						   service    => $service,
						   srcAddr    => $srcAddr,
						   dstAddr    => $dstAddr,
						   matchPrio  => $priority,
						  );

    if ( $filter ) {
      # Attach to the qdisc
      $rootQDisc->attachFilter ( $filter );
    }

  }

###################################
# Private Methods
###################################

###
# Rate helper
###

# Ask if this guaranteed rate gr can be supported
# True if it's possible, false otherwise
sub _canSupportGuaranteedRate # (gr)
  {

    my ($self, $gr) = @_;

    return ($gr <= $self->_allowedGuaranteedRate());

  }

# Ask about what is the maximum guaranteed rate
# Return a result in kbit/s
sub _allowedGuaranteedRate
  {

    my ($self) = @_;

    my $mainChild = $self->_parentUserDefinedClassesNode();
    my @leafClasses = $mainChild->children();

    my $givenGuaranteedRate = 0;
    foreach my $leafClass (@leafClasses) {
      # Don't take default class' rate into account
      if (not $leafClass->value()->equals( $self->{defaultClass} )) {
          my $guaranteedRate = $leafClass->value()->
            getAssociatedQueueDiscipline()->attribute('rate');
          # Add every leaf class (Default has no guaranteed rate)
          $givenGuaranteedRate += $guaranteedRate;
      }
    }

    return $self->{rate} - $givenGuaranteedRate;

  }

# Ask if this limited rate lr can be supported
# True if it's possible, false otherwise
sub _canSupportLimitedRate # (lr)
  {

    my ($self, $lr) = @_;

    return ($lr <= $self->_allowedLimitedRate());

  }

# Ask about what is the maximum limited rate
# Return a result in kbit/s
sub _allowedLimitedRate
{

    my ($self) = @_;

    my $maxRate = $self->{rate};

    return $maxRate;

}


# Minimum allowed guaranteed rate to have at least a quantum of 1
# packet.
# Returns kbit/s
sub _minimumAllowedQuantum
  {
    my ($self) = @_;

    # Minimum quantum = MTU Bytes

    return (MTU * R2Q * 8) / 1000;

  }

# Maximum allowed guaranteed rate not to produce class starvation
# Returns kbit/s
sub _maximumAllowedQuantum
  {

    my ($self) = @_;

    # Maximum quantum = 60000 (HTB hardcoded)

    return (60000 * R2Q * 8) / 1000;

  }


###
# Numbers helpers
###

# Get the highest major number
# Increments its value after it returns
# It is set by default class
sub _getMajorNumber
  {

    my ($self) = @_;

    my $retVal = $self->{highestMajorNumber};

    $self->{highestMajorNumber} += 1;

    return $retVal;

  }

###
# Shortcut helper
###

# Check if the interface which belongs this queue is internal
sub _isIfaceInternal
{

    my ($self) = @_;

    return ! ($self->{'trafficShaping'}->{'network'}->ifaceIsExternal($self->getInterface()));

}

###
# Helper builders
###

# Method: _createExternalStructure
#
#      Build the HTB tree used by *external* interface. It is the basic
#      one. We may think this as a simple case where we are restricted
#      by the upload rate ($self->{rate} attribute)
#
#      The structure is the next one:
#
#                         QDisc HTB 1:0
#                             |
#                         Class 1:1 (rate UPLOAD ceil UPLOAD)
#                             |
#       -----------------------------------------
#       |                                        |
#  Class 1:21 (Default)              User defined classes (1:256, 1:512 ...)
#       |                                        |
#  QDisc SFQ 21:0                    QDisc SFQ (256:0, 512:0 ...)
#
#       All filters are associated to the parent Qdisc.
#
sub _createExternalStructure  # (defaultClass)
{
    my ($self, $defaultClass) = @_;

    my $childNode = $self->{treeRoot}->children(0);
    my $rootQDisc = $self->{treeRoot}->value();
    # Create the leaf default qdisc which always exist in a HTB tree
    my $emptySFQ = EBox::TrafficShaping::QueueDiscipline::SFQ->new();
    my $leafQDisc = EBox::TrafficShaping::QDisc::Base->new(
                                                           majorNumber => $defaultClass,
                                                           realQDisc   => $emptySFQ,
                                                          );

    # All traffic should be guaranteed, default will have remainder values
    my $defaultHTB = EBox::TrafficShaping::QueueDiscipline::HTB->new(rate => $self->{rate},
								     ceil => $self->{rate},
								     prio => $self->{trafficShaping}->getLowestPriority($self->getInterface()),
								    );
    my $leafClass = EBox::TrafficShaping::Class->new(
                                                     minorNumber     => $defaultClass,
                                                     parent          => $childNode,
                                                     qdiscAttached   => $leafQDisc,
                                                     queueDiscipline => $defaultHTB,
                                                    );
    $self->{defaultClass} = $leafClass;

    # Add class to the structure
    my $leafNode = Tree->new( $leafClass );
    $childNode->add_child( $leafNode );
    $leafQDisc->setParent( $leafNode );

    # Filter to default class
    my $defaultFilter = new EBox::TrafficShaping::Filter::Fw(
							     flowId    => { rootHandle => 1,
									    classId    => $defaultClass,
									  },
							     mark      => $defaultClass,
							     prio      => 0,
							     parent    => $rootQDisc,
							    );
    # Attach filter to the root qdisc
    $rootQDisc->attachFilter( $defaultFilter );

}

# Method: _createInternalStructure
#
#      Build the HTB classes used by *internal* interface. It is the
#      complex one. Its structure relies on the traffic flow
#      origin. If it is eBox, the traffic flow must not be
#      shaped. Otherwise the traffic must be shaped by the total
#      download rate.
#
#      The structure is as follows:
#
#                         QDisc HTB 1:0
#                             |
#                         Class 1:1 (rate inf ceil inf)
#                             |
#       -----------------------------------------
#       |                                        |
#  Class 1:FF00 (eBox -> Int)             Class 1:2 (Ext -> Int)
#    (Default)                        (rate DOWNLOAD ceil DOWNLOAD)
#  (rate inf ceil inf)                           |
#       |                                        |----------------------------
#  QDisc SFQ FF00:0                              |                           |
#                                      User defined classes       Default class 1:21
#                                                |                           |
#                                        QDisc SFQ (256:0, 512:0, ...)     |
#                                                                      QDisc SFQ 21:0
#
#      All filters are associated to the parent Qdisc. To distinguish
#      among FE00 and 2 is done by a filter.
#
sub _createInternalStructure # (defaultClassId)
{
    my ($self, $defaultClassId) = @_;

    # Parent 1
    my $parent = $self->{treeRoot}->children(0);
    # Create 1:2 class
    my $parentUserDefinedHTB = new EBox::TrafficShaping::QueueDiscipline::HTB(
                                                                              rate => $self->{rate},
                                                                              ceil => $self->{ceil},
                                                                              prio => 7
                                                                             );
    my $parentUserDefinedClass = new EBox::TrafficShaping::Class(
                                                                 minorNumber     => 2,
                                                                 parent          => $parent,
                                                                 queueDiscipline => $parentUserDefinedHTB,
                                                                );

    # Add class to the structure
    my $parentUserDefinedNode = new Tree($parentUserDefinedClass);
    $parent->add_child( $parentUserDefinedNode );

    # Add QDisc to associated default traffic (ext -> int)
    my $emptySFQ = new EBox::TrafficShaping::QueueDiscipline::SFQ();
    my $leafDefaultQDisc = new EBox::TrafficShaping::QDisc::Base(
                                                                 majorNumber => $defaultClassId,
                                                                 realQDisc   => $emptySFQ,
                                                                );
    my $defaultClass = new EBox::TrafficShaping::Class(
                                                       minorNumber      => $defaultClassId,
                                                       parent           => $parentUserDefinedNode,
                                                       queueDiscipline  => Clone::clone($parentUserDefinedHTB),
                                                       qdiscAttached    => $leafDefaultQDisc,
                                                      );
    $self->{defaultClass} = $defaultClass;
    # Add Class to the structure
    my $leafNode = new Tree( $defaultClass );
    $parentUserDefinedNode->add_child( $leafNode );
    $leafDefaultQDisc->setParent( $leafNode );

    # Filter for default class
    my $defaultFilter = new EBox::TrafficShaping::Filter::Fw(
                                                             flowId => { rootHandle => 1,
                                                                         classId    => $defaultClassId,
                                                                       },
                                                             mark   => $defaultClassId,
                                                             prio   => 0,
                                                             parent => $self->{treeRoot}->value(),
                                                            );
    $self->{treeRoot}->value()->attachFilter( $defaultFilter );

    # Create 1:FF00 class
    my $eBoxHTB = new EBox::TrafficShaping::QueueDiscipline::HTB(
                                                                 rate => MAX_RATE,
                                                                 ceil => MAX_RATE,
                                                                 prio => 7,
                                                                );
    my $eBoxId = $self->{trafficShaping}->MaxIdValue();
    my $eBoxQDisc = new EBox::TrafficShaping::QDisc::Base(
                                                          majorNumber => $eBoxId,
                                                          realQDisc   => $emptySFQ,
                                                         );
    my $eBoxClass = new EBox::TrafficShaping::Class(
                                                    minorNumber     => $eBoxId,
                                                    parent          => $parent,
                                                    queueDiscipline => $eBoxHTB,
                                                    qdiscAttached   => $eBoxQDisc,
                                                   );
    # Add class to the structure
    my $eBoxNode = Tree->new( $eBoxClass );
    $parent->add_child( $eBoxNode );
    $eBoxQDisc->setParent( $eBoxNode );

    # Filter to generated in eBox traffic
    my $netMod = EBox::Global->modInstance('network');
    #my $servMod = EBox::Global->modInstance('services');
    my $ifaceAddr = $netMod->ifaceAddress($self->getInterface());
    my $eBoxIPType = new EBox::Types::IPAddr(fieldName     => 'ifaceAddr',
                                            printableName => 'ifaceAddr');
    $eBoxIPType->setValue("$ifaceAddr/32");
    $self->addFilter(leafClassId => $eBoxId,
                     priority    => 0,
                     srcAddr     => $eBoxIPType,
                     service     => undef,
                    );
    $self->addFilter(leafClassId => $eBoxId,
                     priority    => 0,
                     dstAddr     => $eBoxIPType,
                     service     => undef,
                     id          => $eBoxId + 1,
                    );


}

###
# Helper methods in tree structure
###

# Given an leaf class identifier it returns the node
# which has this node
sub _getNode # (leafClassId)
{

    my ($self, $leafClassId) = @_;

    my $childNode = $self->_parentUserDefinedClassesNode();
    my @leafNodes = $childNode->children();
    # Node which has the node to destroy
    my $foundNode;
    foreach my $leafNode (@leafNodes) {
      my $found = $leafNode->value()->equals($leafClassId);
      $foundNode = $leafNode if ($found);
      last if ($found);
    }

    return $foundNode;

}

# Get the node from where all the user defined classes will hang
# Returns: <Tree>
sub _parentUserDefinedClassesNode
{
    my ($self) = @_;

    my ($mainChild) = $self->{treeRoot}->children(0);
    if ( $self->_isIfaceInternal() ) {
        ($mainChild) = $mainChild->children(0);
    }
    return $mainChild;

}

# Given a node, it removes from the structure
sub _removeNode # (node)
  {

    my ($self, $node) = @_;

    # Get all nodes in pre order
    my @nodes = $self->{treeRoot}->traverse( $self->{treeRoot}->PRE_ORDER );

    foreach my $parentNode (@nodes) {
      if ( $parentNode->has_child( $node )) {
	$parentNode->remove_child( $node );
	last;
      }
    }

  }

###
# Filter helper methods
###

# Find the target (class identifier) from a filter which should be
# found using port and protocol
# Returns all the classes with this protocol and port as an array ref
sub _findTargetFromFilter # (protocol, port)
  {

    my ($self, $protocol, $port) = @_;

    $protocol = '' unless defined ( $protocol );
    $port     = 0  unless defined ( $port );

    my $rootQDisc = $self->{treeRoot}->value();
    my $filters_ref = $rootQDisc->filters();

    my @classesFound;
    foreach my $filter (@{$filters_ref}) {
      if  ( defined( $filter->attribute('fProtocol') ) and
	    defined( $filter->attribute('fPort')) ){
	if ( $filter->attribute('fProtocol') eq $protocol and
	     $filter->attribute('fPort') == $port) {
	  my $flowId = $filter->attribute('flowId');
	  my $classId = {
			 major => $flowId->{rootHandle},
			 minor => $flowId->{classId}
			};
	  push (@classesFound, $classId);
	}
      }
    }

    return \@classesFound;

  }

# Find the filter associated to a leaf class
# Returns the filter
sub _findFilterFromClass # (leafClassId)
  {

    my ($self, $leafClassId) = @_;

    my $rootQDisc = $self->{treeRoot}->value();
    my $filters_ref = $rootQDisc->filters();

    my $filterFound;
    foreach my $filter (@{$filters_ref}) {
      my $flowId = $filter->attribute('flowId');
      if ( $flowId->{rootHandle} == $leafClassId->{major}
	   and $flowId->{classId} == $leafClassId->{minor} ) {
	$filterFound = $filter;
	# The filter was found
	last;
      }
    }

    return $filterFound;

  }

1;
