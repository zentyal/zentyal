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

# Class: EBox::Ntop::Composite::General
#
#   General configuration page for the module
#

use strict;
use warnings;

package EBox::Ntop::Composite::General;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Ntop;

# Group: Public methods


# Method: permanentMessage
#
# Overrides:
#
#     <EBox::Model::Composite::permanentMessage>
#
sub permanentMessage
{
    my ($self) = @_;

    my $message;
    if ($self->parentModule()->isEnabled()) {
        my $NTOPNG_PORT = EBox::Ntop::NTOPNG_PORT;
        my $url = "http://localhost:$NTOPNG_PORT";
        $message = __x('See the {ohref}Ntop User Interface{chref}.',
                       ohref => "<a href='$url' target='_blank' id='ntop_go_url'>",
                       chref => '</a>');
        $message .= "<script>document.getElementById('ntop_go_url').href='http://' + document.domain + ':$NTOPNG_PORT';</script>";
    }
    return $message;
}


# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{
    my $description =
    {
        layout          => 'top-bottom',
        name            => __PACKAGE__->nameFromClass(),
        pageTitle       => __('Network monitoring'),
        compositeDomain => 'Ntop',
    };

    return $description;
}

# Group: Private methods

1;
