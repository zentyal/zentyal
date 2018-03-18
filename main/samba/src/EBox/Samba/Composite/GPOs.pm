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

package EBox::Samba::Composite::GPOs;

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
        name            => 'GPOs',
        pageTitle       => '',
        compositeDomain => 'Samba',
    };

    return $description;
}

sub permanentMessage
{
    my ($self) = @_;

    return '' unless ($self->parentModule()->isProvisioned());

    return '<font size="2">' .
           __x('<b>Group Policy Objects</b> can be managed downloading {oh}Microsoft Remote Server Administration Tools{ch} for your Windows version.',
               oh => '<a target="_blank" href="https://www.microsoft.com/en-us/search/result.aspx?q=Remote+Server+Administration+Tools">', ch => '</a>') .
           '</font>';
}

sub permanentMessageType
{
    return 'emptynote';
}

1;
