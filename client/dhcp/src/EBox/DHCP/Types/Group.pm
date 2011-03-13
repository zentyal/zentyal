# Copyright (C) 2011 eBox Technologies S.L.
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

# Class: EBox::DHCP::Types::Group
#
#     This class implements an object within the DHCP realm with an
#     index in the constructor to be able to select the objects used
#     by FixedAddressTable model

package EBox::DHCP::Types::Group;

use strict;
use warnings;

use base 'EBox::Types::Select';

# uses
use EBox::Exceptions::MissingArgument;
use EBox::Model::ModelManager;

# Group: Public methods

# Constructor: new
#
sub new
{
    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);

    foreach my $opt (qw(index foreignModelName)) {
        unless (exists $self->{$opt} ) {
            throw EBox::Exceptions::MissingArgument($opt);
        }
    }

    return $self;

}

# Method: options
#
#     Return the options manually
#
# Overrides:
#
#     <EBox::Types::Select::options>
#
sub options
{
    my ($self) = @_;

    if ((not exists $self->{'options'}) or $self->disableCache()) {
        $self->{'options'} = $self->_options();
    }
    return $self->{'options'};
}

# Group: Private methods

# Get the objects from the FixedAddressTable
sub _options
{
    my ($self) = @_;

    my $modelName = $self->{foreignModelName};
    my $iface = $self->{index};
    my $model = EBox::Model::ModelManager->instance()->model("/dhcp/$modelName/$iface");

    my @options;
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        push(@options, { value          => $row->valueByName($self->{foreignField}),
                         printableValue => $row->printableValueByName($self->{foreignField}) });
    }
    return \@options;
}

1;
