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

# Class: EBox::Types::Virt::Status;
#
package EBox::Virt::Types::Status;

use strict;
use warnings;

use base 'EBox::Types::Boolean';

use EBox::Service;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: optional
#
#   Overrides <EBox::Types::Boolean::optional>.
#
sub optional
{
    my ($self) = @_;

    return 1;
}

# Method: value
#
#   Overrides <EBox::Types::Boolean::value>.
#
sub value
{
    my ($self) = @_;

    my $row = $self->row();
    return undef unless ($row);

    my $id = $row->{id};
    my $virt = EBox::Global->modInstance('virt');
    #my $name = $virt->model('VirtualMachines')->row($id)->valueByName('name');
    my $name = 'foo'; #FIXME!

    return $virt->vmRunning($name);
}

# Method: printableValue
#
#   Overrides <EBox::Types::Boolean::printableValue>.
#
sub printableValue
{
    my ($self) = @_;

    return $self->value();
}

# Method: restoreFromHash
#
#   Overrides <EBox::Types::Boolean::restoreFromHash>
#
sub restoreFromHash
{

}

# Method: storeInGConf
#
#   Overrides <EBox::Types::Basic::storeInGConf>
#
sub storeInGConf
{

}

1;
