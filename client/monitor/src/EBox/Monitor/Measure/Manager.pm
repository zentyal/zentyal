# Copyright 2008 (C) eBox Technologies S.L.
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

# Class: EBox::Monitor::Measure::Manager
#
#     This singleton class is intended to manage the measures
#     collected by stats collector
#
#     Each measure must register themselves in this manager by
#     <register> instance method to appear in monitoring solution
#

package EBox::Monitor::Measure::Manager;

use strict;
use warnings;

use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::Internal;

# Singleton variable
my $_instance = undef;

# Group: Public static methods

# Method: Instance
#
#   Return a singleton instance of class <EBox::Monitor::Measure::Manager>
#
# Returns:
#
#   object of class <EBox::ModelManager>
#
sub Instance
{
    my ($class) = @_;

    unless(defined($_instance)) {
        $_instance = $class->_new();
    }

    return $_instance;
}

# Group: Public instance methods

# Method: register
#
#     Register a measure in the manager
#
# Parameters:
#
#     className - String the class name to register
#
# Exceptions:
#
#     <EBox::Exceptions::Internal> - thrown if the class cannot be
#     loaded
#
#     <EBox::Exceptions::InvalidType> - thrown if the measure class is
#     not derived from <EBox::Monitor::Measure::Base> class
#
sub register
{
    my ($self, $measureToRegister) = @_;

    eval "use $measureToRegister";
    if ( $@ ) {
        throw EBox::Exceptions::Internal("Cannot load $measureToRegister: $@");
    }
    if ( exists($self->{measures}->{$measureToRegister}) ) {
        EBox::warn("Loading $measureToRegister measure again");
    }
    unless ( $measureToRegister->isa('EBox::Monitor::Measure::Base') ) {
        throw EBox::Exceptions::InvalidType(arg => $measureToRegister,
                                            type => 'child of EBox::Monitor::Measure::Base');
    }
    $self->{measures}->{$measureToRegister} = $measureToRegister->new();

    return 1;

}

# Method: measures
#
#     Return the measure instances
#
# Returns:
#
#     array ref - containing instances from every registered measure
#     class
#
sub measures
{
    my ($self) = @_;

    my @measureInstances = values(%{$self->{measures}});
    return \@measureInstances;
}

# Method: measure
#
#      Return a measure instance given its name
#
# Parameters:
#
#      name - String the measure class name or its common name
#
# Returns:
#
#      an instance of a measure which is a subclass of
#      <EBox::Monitor::Measure::Base>
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given measure
#      name does not registered
#
sub measure
{
    my ($self, $name) = @_;

    $name or throw EBox::Exceptions::MissingArgument('name');

    if ( exists($self->{measures}->{$name}) ) {
        return $self->{measures}->{$name};
    } else {
        my @measures = grep { $_ =~ m/::$name$/i } keys(%{$self->{measures}});
        if ( @measures == 1 ) {
            return $self->{measures}->{$measures[0]};
        } else {
            throw EBox::Exceptions::DataNotFound(data  => 'measure',
                                                 value => $name);
        }
    }

}

# Group: Private methods
sub _new
{
    my ($class) = @_;

    my $self = {measures => {}};
    bless($self, $class);
    return $self;
}

1;
