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

package EBox::DNS::Types::Hostname;

use strict;
use warnings;

use base 'EBox::Types::Select';

use EBox::DNS;

# Group: Public methods

# Constructor: new
sub new
{

    my ($class, %opts) = @_;

    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;

}

# Method: foreignModel
#
#    Override to set the foreign model manually without a callback method
#
# Overrides:
#
#    <EBox::Types::Select::foreignModel>
#
sub foreignModel
{
    my ($self) = @_;

    my $model = $self->model();
    return unless (defined($model));

    my $row = $model->parentRow();

    return unless defined($row);
    return $row->subModel('hostnames');

}

# Method: options
#
#    Override to avoid caching in options from foreign model
#
# Overrides:
#
#    <EBox::Types::Select::options>
#
sub options
{
    my ($self) = @_;

    my $model = $self->foreignModel();
    my $field = $self->{'foreignField'};

    return unless (defined($model) and defined($field));

    # Perform the EBox::Model::DataTable::optionsFromForeignModel
    my @options;
    foreach my $id (@{$model->ids()}) {
        my $row = $model->row($id);
        push(@options, {
              'value'          => $id,
              'printableValue' => $row->printableValueByName($field) });
    }

    $self->{'options'} = \@options;
    return $self->{'options'};

}

# Group: Protected methods

# Method: _setValue
#
#     Override this in order to avoid call _optionsFromForeignModel
#
# Overrides:
#
#     <EBox::Types::Select::_setValue>
#
sub _setValue
{
    my ($self, $value) = @_;

    my $mappedValue = $value;
    my $options = $self->options();

    foreach my $option (@{$options}) {
        if ( $option->{printableValue} eq $value ) {
            $mappedValue = $option->{value};
            last;
        } elsif ( $option->{value} eq $value ) {
            last;
        }
    }
    my $params = { $self->fieldName() => $mappedValue };

    $self->setMemValue($params);

}

1;
