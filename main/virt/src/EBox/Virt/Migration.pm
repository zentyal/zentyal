# Copyright (C) 2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Virt::Migration;

sub migrateOS
{
    my ($package, $virt) = @_;

    my $virtualMachines = $virt->model('VirtualMachines');
    foreach my $vmId (@{ $virtualMachines->ids() }) {
        my $vmRow = $virtualMachines->row($vmId);
        my $settings = $vmRow->subModel('settings');
        my $sys = $settings->componentByName('SystemSettings', 1);
        my $sysRow = $sys->row();
        my $os = $sysRow->elementByName('os');
        my $arch = $sysRow->elementByName('arch');
        my $oldSystemSettings = $virt->get("VirtualMachines/keys/$vmId/settings/SystemSettings/keys/form");
        if ($oldSystemSettings) {
            # in previous version arch wa in os setting
            $arch->setValue($oldSystemSettings->{os});
        } else {
            $arch->setValue('i686'); # defualt value in previous versions
        }
        # since we are not sure what sort of system is and we want to preserve
        # bus compabilty we set it to other
        $os->setValue('other');
        $sysRow->store();
    }
}

1;
