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

package EBox::MailFilter::Migration;
use EBox::Service;

use Error qw(:try);

sub removeSpamdService
{
    my $service = 'ebox.spamd';
    my $serviceFile = '/etc/init/' . $service . '.conf';
    try {
        if (EBox::Service::running($service)) {
            EBox::Service::manage($service, 'stop');
        }
    } otherwise {
        # ignore errors, we assume that service is stopped
    };
    EBox::Sudo::root("rm -f $serviceFile");
}


1;
