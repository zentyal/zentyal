# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::Network::Types::Text::AutoReadOnly;

use strict;
use warnings;

use base 'EBox::Types::Text';

sub new
{
    my $class = shift;
    my %opts = @_;

    my $self = $class->SUPER::new(%opts);

    bless($self, $class);
    return $self;
}

# Method: editable
#
#   Make the field read-only when the row is auto
#
# Overrides:
#
#       <EBox::Types::Abstract::editable>
#
sub editable
{
    my ($self) = @_;

    my $row = $self->row();

    unless ($row) {
        return 1;
    }

    my $auto = $row->valueByName('auto');

    return (not $auto);
}

sub setMemValue
{
    my ($self, $params) = @_;

    if ($self->_paramIsSet($params)) {
        $self->SUPER::setMemValue($params);
    }
}

1;
