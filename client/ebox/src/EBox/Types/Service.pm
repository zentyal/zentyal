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

package EBox::Types::Service;

use strict;
use warnings;

use EBox::Validate qw( checkPort checkProtocol);
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Gettext;

use base 'EBox::Types::Abstract';

# Constructor: new
#
#     Create a type which includes the protocol and the port from
#     Internet as a service
#
# Returns:
#
#     a <EBox::Types::Service> object
#
sub new
  {
    my $class = shift;
    my %opts = @_;

    unless (exists $opts{'HTMLSetter'}) {
        $opts{'HTMLSetter'} ='/ajax/setter/serviceSetter.mas';
    }
    unless (exists $opts{'HTMLViewer'}) {
        $opts{'HTMLViewer'} ='/ajax/viewer/textViewer.mas';
    }
    $opts{optional} = 0 unless defined ( $opts{optional} );
    $opts{'type'} = 'service';

    my $self = $class->SUPER::new(%opts);

    $self->{protocols} = $self->_protocolsHash();
    bless($self, $class);
    return $self;
  }

# Method: paramExist
#
#    Overrides <EBox::Types::Abstract::paramExist> method
#
sub paramExist
  {

    my ($self, $params) = @_;

    my $proto = $self->fieldName() . '_protocol';
    my $port = $self->fieldName() . '_port';

    return ( defined($params->{$proto}) );

  }

# Method: printableValue
#
#    Overrides <EBox::Types::Abstract::printableValue> method
#
sub printableValue
  {

    my ($self) = @_;

    if ( defined($self->{protocol}) ) {
      if ( $self->_needPort($self->{protocol}) ) {
        return $self->{port} . '/' . $self->_printableValue($self->{protocol});
      }
      else {
        return $self->_printableValue($self->{protocol});
      }
    }
    else {
      return '';
    }

  }

# Method: paramIsValid
#
#    Overrides <EBox::Types::Abstract::paramIsValid> method
#
#sub paramIsValid
#  {
#
#
#  }

# Method: compareToHash
#
#    Overrides <EBox::Types::Abstract::compareToHash> method
#
sub compareToHash
  {
    my ($self, $hash) = @_;

    my $oldProtocol = $self->protocol();
    my $oldPort = $self->port();

    my $newProtocol = $self->fieldName() . '_protocol';
    my $newPort = $self->fieldName() . '_port';

    if ( not defined ( $oldProtocol ) or
         not defined ( $hash->{$newProtocol} )) {
      return 0;
    }

    if ($oldProtocol ne $hash->{$newProtocol}) {
      return 0;
    }

    if ($oldPort ne $hash->{$newPort}) {
      return 0;
    }

    return 1;

}



# Method: cmp
#
#    Overrides <EBox::Types::Abstract::cmp> method
#
sub cmp
{
    my ($self, $compared) = @_;

    $compared->isa(__PACKAGE__) or 
        return undef;

    my $portA = $self->port();
    my $portB = $compared->port();

    my $res = $portA <=> $portB;
    if ( $res != 0 ) {
        return $res;
    }

    my $protoA = $self->protocol();
    my $protoB = $self->protocol();

    if ($protoA gt $protoB) {
        return 1;
    }
    elsif ($protoA lt $protoB) {
        return -1;
    }
    else {
        return 0;
    }

}

# Method: fields
#
#    Overrides <EBox::Types::Abstract::fields> method
#
sub fields
  {
    my ($self) = @_;

    my $proto = $self->fieldName() . '_protocol';
    my $port = $self->fieldName() . '_port';

    return ($proto, $port);

  }

###
# Own methods
###

# Method: protocols
#
#     Get the protocols available (Static method)
#
# Returns:
#
#     array ref - the protocols in a hash with the following elements
#              - value - the protocol name
#              - printableValue - the protocol printable name
#              - needPort - set true if it needs a port
#
sub protocols
  {

    my ($self) = @_;

    my @protocols = (
                     {
                      value => 'all',
                      printableValue => __('Any'),
                      needPort => 0,
                     },
                     {
                      value => 'tcp',
                      printableValue => 'TCP',
                      needPort => 1,
                     },
                     {
                      value => 'udp',
                      printableValue => 'UDP',
                      needPort => 1,
                     },
                     {
                      value => 'icmp',
                      printableValue => 'ICMP',
                      needPort => 0,
                     },
                     {
                      value => 'gre',
                      printableValue => 'GRE',
                      needPort => 0,
                     },
                    );

    return \@protocols;
 }

# Method: protocolsJS
#
#     Get the JavaScript definition of an array with
#     the protocols which need a port (Static method)
#
# Returns:
#
#     String
#
sub protocolsJS
  {

    my ($self) = @_;

    my $str = "[ ";

    foreach my $proto ( @{$self->protocols()} ) {
      if ( $proto->{needPort} ) {
        $str .= q{"} . $proto->{value} . q{", };
      }
    }

    # Deleting the trailing comma value from array variable
    $str =~ s/, $//;
    $str .= ']';

    return $str;

  }

# Method: protocol
#
#     Get the protocol value
#
# Returns:
#
#     String - the Internet protocol
#
sub protocol
  {
    my ($self) = @_;

    return $self->{protocol};
  }

# Method: port
#
#     Get the port value
#
# Returns:
#
#     Int - the port associated to that protocol
#
sub port
  {
    my ($self) = @_;

    return $self->{port};
  }

# Method: AnyProtocol
#
#     Get the name of the protocol which represents all protocols.
#     (Class method)
#
# Returns:
#
#     String - containing the desired name
#
sub AnyProtocol
  {

    my ($class) = @_;

    return 'all';

  }

# Group: Protected methods

# Method: _setMemValue
#
# Overrides:
#
#       <EBox::Types::Abstract::_setMemValue>
#
sub _setMemValue
  {

    my ($self, $params) = @_;

    my $proto = $self->fieldName() . '_protocol';
    my $port = $self->fieldName() . '_port';

    $self->{protocol} = $params->{$proto};
    $self->{port} = $params->{$port};

  }

# Method: _storeInGConf
#
# Overrides:
#
#       <EBox::Types::Abstract::_storeInGConf>
#
sub _storeInGConf
  {
    my ($self, $gconfmod, $key) = @_;

    my $protoKey = "$key/" . $self->fieldName() . '_protocol';
    my $portKey = "$key/" . $self->fieldName() . '_port';

    if (defined ($self->{protocol}) ) {
      $gconfmod->set_string($protoKey, $self->{protocol});
    }
    else {
      $gconfmod->unset($protoKey);
    }

    if (defined ($self->{port}) ) {
      $gconfmod->set_int($portKey, $self->{port});
    }
    else {
      $gconfmod->unset($portKey);
    }
}

# Method: _restoreFromHash
#
# Overrides:
#
#       <EBox::Types::Abstract::_restoreFromHash>
#
sub _restoreFromHash
  {
    my ($self, $hash) = @_;

    my $proto = $self->fieldName() . '_protocol';
    my $port = $self->fieldName() . '_port';

    $self->{protocol} = $hash->{$proto};
    $self->{port} = $hash->{$port};

  }

# Method: _paramIsValid
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsValid>
#
sub _paramIsValid
  {

      my ($self, $params) = @_;

      my $proto = $self->fieldName() . '_protocol';
      my $port = $self->fieldName() . '_port';

      checkProtocol($params->{$proto}, $self->printableName());

      if ( $self->_needPort($params->{$proto}) ) {
          checkPort($params->{$port}, $self->printableName());
      }

      return 1;

  }

# Method: _paramIsSet
#
# Overrides:
#
#       <EBox::Types::Abstract::_paramIsSet>
#
sub _paramIsSet
  {

      my ($self, $params) = @_;

      my $proto = $self->fieldName() . '_protocol';
      my $port = $self->fieldName() . '_port';

      return undef unless ( $params->{$proto} );

      if ( $self->_needPort($params->{$proto}) ) {
          return undef unless ( $params->{$port} );
      }

      return 1;

  }

# Method: _setValue
#
#     Set the value defined as a string in the
#     printableValue. That is, to define an service you must set
#     a valid port/protocol.
#
# Overrides:
#
#     <EBox::Types::Abstract::_setValue>
#
# Parameters:
#
#     value - String a valid port/protocol
#
sub _setValue # (value)
  {

      my ($self, $value) = @_;

      my ($port, $protocol) = split ('/', $value);

      unless ( defined ( $protocol )) {
          $protocol = $port;
          $port = undef;
      }

      my $params = {
                    $self->fieldName() . '_port'   => $port,
                    $self->fieldName() . '_protocol' => $protocol,
                   };

      $self->setMemValue($params);

  }


####
# Group: Private methods
###

# Return if a protocol needs a port
sub _needPort # (proto)
  {

    my ($self, $proto) = @_;

    return $self->{protocols}->{$proto}->{needPort};

  }

# Return the printable value from a protocol
sub _printableValue # (proto)
  {

    my ($self, $proto) = @_;

    return $self->{protocols}->{$proto}->{printableValue};

  }


# Return a hash ref with the allowed protocols
# indexed by protocol value
sub _protocolsHash
  {

    my ($self) = @_;

    my %protocolsHash = map { $_->{value} => $_ } @{$self->protocols()};

    return \%protocolsHash;

  }

1;
