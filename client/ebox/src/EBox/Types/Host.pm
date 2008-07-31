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

# Class: EBox::Types::Host
#
#      A specialised text type to represent either a host IP address or a host name.
#
package EBox::Types::Host;

use strict;
use warnings;

use base 'EBox::Types::Text';

# eBox uses
use EBox::Validate;

# Dependencies
use Net::IP;

# Group: Public methods

# Constructor: new
#
#      The constructor for the <EBox::Types::Host>
#
# Returns:
#
#      the recently created <EBox::Types::Host> object
#
sub new
{
        my $class = shift;
        my $self = $class->SUPER::new(
                                      @_,
                                     );
        $self->{'type'} = 'host';
        bless($self, $class);
        return $self;
}

# Method: cmp
#
# Overrides:
#
#      <EBox::Types::Abstract::cmp>
#
sub cmp
{
    my ($self, $compareType) = @_;

    unless ( (ref $self) eq (ref $compareType) ) {
        return undef;
    }

    my $aIsIp = $self->isIPAddress();
    my $bIsIp = $compareType->isIPAddress();;

    if ($aIsIp and $bIsIp) {
        $self->_cmpIP($compareType);
    }
    elsif ((not $aIsIp) and (not $bIsIp)) {
        $self->_cmpHostname($compareType);
    }
    else {
        # we cannot compare host name with an a host address
        return undef;
    }

}


sub _cmpIP
{
    my ($self, $compareType) = @_;

    my $ipA = new Net::IP($self->value());
    my $ipB = new Net::IP($compareType->value());

    if ( $ipA->bincomp('lt', $ipB) ) {
        return -1;
    } elsif ( $ipA->bincomp('gt', $ipB)) {
        return 1;
    } else {
        return 0;
    }

}

sub _cmpHostname
{
    my ($self, $compareType) = @_;

    my $aValue = $self->value();
    my $bValue = $compareType->value();

    if ($aValue gt $bValue) {
        return 1;
    }
    elsif ($aValue lt $bValue) {
        return -1;
    }
    else {
        return 0;
    }
}

# Method: isIPAddress
#
# Returns:
#    true - if the value contained is an IP address
sub isIPAddress
{
    my ($self) = @_;
    my $value = $self->value();
    return $value =~ m/^[\d.]+$/;
}

# Group: Protected methods

# Method: _paramIsValid
#
#     Check if the params has a correct host IP address
#
# Overrides:
#
#     <EBox::Types::Text::_paramIsValid>
#
# Parameters:
#
#     params - the HTTP parameters with contained the type
#
# Returns:
#
#     true - if the parameter is either a correct host IP address or name
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - throw if it's not a correct
#                                       host IP address or name
#
sub _paramIsValid
{
    my ($self, $params) = @_;

    my $value = $params->{$self->fieldName()};

    if (defined ( $value )) {
        EBox::Validate::checkHost($value, $self->printableName());
    }

    return 1;

}

1;
