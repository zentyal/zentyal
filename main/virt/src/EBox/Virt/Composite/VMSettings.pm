# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::Virt::Composite::VMSettings;

use base 'EBox::Model::Composite';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#      Constructor for the General composite
#
# Returns:
#
#      <EBox::Virt::Model::GeneralComposite> - the recently created model
#
sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new();

    return $self;
}


# Group: Protected methods

# Method: _description
#
# Overrides:
#
#       <EBox::Model::Composite::_description>
#
sub _description
{
    my $description =
    {
        components      => [
                               'virt/SystemSettings',
                               'virt/NetworkSettings',
                               'virt/DeviceSettings',
                           ],
        layout          => 'tabbed',
        name            => 'VMSettings',
        printableName   => __('Virtual Machine Settings'),
        compositeDomain => 'Virt',
    };

    return $description;
}

sub HTMLTitle
{
    my ($self) = @_;

    return ([
             {
              title => __('Virtual Machines'),
              link  => '/Virt/View/VirtualMachines',
             },
             {
              title => $self->parentRow()->valueByName('name'),
              link => '',
             },
    ]);
}

1;
