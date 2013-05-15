# Copyright (C) 2011-2013 Zentyal S.L.
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

# Class: EBox::Types::Virt::Status;
#
use strict;
use warnings;

package EBox::Virt::Types::Status;

use base 'EBox::Types::Basic';

sub new
{
    my $class = shift;
    my %opts = @_;
    $opts{'type'} = 'status';
    my $self = $class->SUPER::new(%opts);
    bless($self, $class);
    return $self;
}

# Method: volatile
#
#   Overrides <EBox::Types::Basic::volatile>.
#
sub volatile
{
    my ($self) = @_;

    return 1;
}

# Method: editable
#
#   Overrides <EBox::Types::Basic::editable>.
#
sub editable
{
    my ($self) = @_;

    return 0;
}

# Method: optional
#
#   Overrides <EBox::Types::Basic::optional>.
#
sub optional
{
    my ($self) = @_;

    return 1;
}

# Method: value
#
#   Overrides <EBox::Types::Basic::value>.
#
sub value
{
    my ($self) = @_;

    my $row = $self->row();
    return undef unless ($row);

    my $model = $self->model();
    my $virt = $model->parentModule();
    my $name = $row->valueByName('name');

    return 'paused' if $virt->vmPaused($name);
    return $virt->vmRunning($name) ? 'running' : 'stopped';
}

# Method: printableValue
#
#   Overrides <EBox::Types::Basic::printableValue>.
#
sub printableValue
{
    my ($self) = @_;

    return $self->value();
}

# Method: restoreFromHash
#
#   Overrides <EBox::Types::Basic::restoreFromHash>
#
sub restoreFromHash
{

}

# Method: storeInHash
#
#   Overrides <EBox::Types::Basic::storeInHash>
#
sub storeInHash
{

}

# Method: HTMLViewer
#
#   Overrides <EBox::Types::Basic::HTMLViewer>
#
sub HTMLViewer
{
    return '/virt/statusViewer.mas';
}

1;
