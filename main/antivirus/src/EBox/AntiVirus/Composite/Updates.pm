# Copyright (C) 2018 Zentyal S.L.
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

package EBox::AntiVirus::Composite::Updates;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;

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
        layout          => 'top-bottom',
        name            => 'Updates',
        pageTitle       => '',
        compositeDomain => 'AntiVirus',
    };

    return $description;
}

sub permanentMessage
{
    my $events = `bash -c "grep -h 'Database updated' /var/log/clamav/freshclam.log{.1,}|sed 's/ from.*//'|tac"`;
    my $msg = '<h3>' . __('Last Database Updates') . '</h3>';
    $msg .= $events ? '<pre>' . $events . '</pre>' : '<p>' .__('No recent updates.') . '</p>';
    return $msg;
}

sub permanentMessageType
{
    return 'item-block';
}

1;
