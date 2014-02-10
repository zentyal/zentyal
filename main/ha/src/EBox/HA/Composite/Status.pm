# Copyright (C) 2014 Zentyal S.L.
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

package EBox::HA::Composite::Status;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{
    my $description = {
        components      => ['StatusHalfTop', 'Errors'],
        layout          => 'top-bottom',
        printableName   => 'Cluster status',
        compositeDomain => 'ha',
        name            => 'Status',
        help            => __x('Here you can show the status of your cluster. ' .
                              'If you want to see more info about the errors ' .
                               'shown, please go to {logfile}',
                                                logfile => '/var/log/syslog'),
    };

    return $description;
}

1;

