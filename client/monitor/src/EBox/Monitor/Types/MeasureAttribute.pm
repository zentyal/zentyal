# Copyright (C) 2008 eBox Technologies S.L.
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

package EBox::Monitor::Types::MeasureAttribute;

use strict;
use warnings;

use base 'EBox::Types::Select';

# eBox uses
use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;

# Constants
use constant MEASURE_ATTRS => qw(measureInstance typeInstance dataSource);

# Dependencies
use Perl6::Junction qw(any);

# Group: Public methods

# Constructor: new
#
#    Create a <EBox::Monitor::Types::MeasureAttribute>
#
# Parameters:
#
#    Same as <EBox::Types::Select>
#
#    attribute - String indicate which attribute to populate the
#                select from the measure object
#
# Returns:
#
#    <EBox::Monitor::Types::MeasureAttribute> - the instance
#
# Exceptions:
#
#    <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#    argument is missing
#
#    <EBox::Exceptions::InvalidData> - thrown if the given attribute
#    is not one of the allowed ones
#
sub new
{
    my ($class, %opts) = @_;

    unless( exists($opts{attribute}) ) {
        throw EBox::Exceptions::MissingArgument('attribute');
    }

    unless($opts{attribute} eq any(MEASURE_ATTRS)) {
        throw EBox::Exceptions::InvalidData(data   => 'attribute',
                                            value  => $opts{attribute},
                                            advice => 'Use one of the following: '
                                              . join(', ', MEASURE_ATTRS));
    }

    my $self = $class->SUPER::new(%opts);

    $self->{'type'} = 'attribute';

    return $self;

}

# Method: options
#
#     Get the options exclusively from <populate> method
#
# Overrides:
#
#     <EBox::Types::Select::options>
#
sub options
{
    my ($self) = @_;

    return $self->populate();

}

# Method: populate
#
#    Populate the options from this select
#
# Overrides:
#
#    <EBox::Types::Select::populate>
#
# Returns:
#
#    array ref - the same structure as <EBox::Types::select> gives
#    back
#
sub populate
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    my $mon = EBox::Global->modInstance('monitor');

    if ($self->model()) {
        my @dirs = split('/', $self->model()->directory());
        my $parentRow = $self->model()->parent()->row($dirs[-2]);
        my $measureClass = $parentRow->valueByName('measure');
        my ($measureInstance) = grep { $_->name() eq $measureClass }
          @{$mon->measures()};
        my @options = ();
        if ($self->attribute() eq 'measureInstance') {
            my $instances = $measureInstance->instances();
            @options = map {
                { value => $_,
                  printableValue => $measureInstance->printableInstance($_) }
                } @{$instances};
            my $printableValue = __('not applicable');
            if ( @options > 1 ) {
                $printableValue = __('any');
            }
            push(@options, { value => 'none', printableValue => $printableValue});
        } elsif ($self->attribute() eq 'typeInstance') {
            my $typeInstances = $measureInstance->typeInstances();
            @options = map {
                { value => $_,
                    printableValue => $measureInstance->printableTypeInstance($_) }
                } @{$typeInstances};
            if ( @options > 1 ) {
                push(@options, { value => 'none', printableValue => __('any')});
            } elsif ( @options == 0 ) {
                push(@options, { value => 'none', printableValue => __('not applicable')});
            }
        } elsif ($self->attribute() eq 'dataSource') {
            my $dataSources = $measureInstance->dataSources();
            my $printableValue = __('not applicable');
            if ( @{$dataSources} > 1 ) {
                @options = map {
                    { value => $_,
                      printableValue => $measureInstance->printableDataSource($_) }
                } @{$dataSources};
                $printableValue = __('any');
            } elsif ( @options == 0 ) {
                push(@options, { value => 'none', printableValue => $printableValue});
            }
        }
        return \@options;
    } else {
        return undef;
    }

}

# Method: attribute
#
#    Get the measure attribute for this type
#
# Returns:
#
#    String - the measure attribute. Current possible values are:
#
#        measureInstance
#        typeInstance
#
sub attribute
{
    my ($self) = @_;

    return $self->{'attribute'};
}

1;
