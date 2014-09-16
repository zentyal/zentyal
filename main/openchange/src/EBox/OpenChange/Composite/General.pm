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

package EBox::OpenChange::Composite::General;
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
        name            => 'General',
        pageTitle       => __('OpenChange'),
        compositeDomain => 'OpenChange',
    };

    return $description;
}

sub permanentMessage
{
    my ($self) = @_;

    # FIXME: add some check when checkbox to enable/disable webmail is added
    #my $sogo = EBox::Global->modInstance('sogo');
    #unless (defined ($sogo) and $sogo->isEnabled()) {
    #    return undef;
    #}

    if ($self->parentModule()->isProvisioned()) {
        my $readyToUseMsg = __x('You can access the {oh}OpenChange Webmail{ch}',
                                    oh => "<a href='#' target='_blank' id='sogo_url'>", ch => '</a>');
        $readyToUseMsg .= "<script>document.getElementById('sogo_url').href='https://' + document.domain + '/SOGo';</script>";
        return $readyToUseMsg;
    } else {
        return __('OpenChange webmail is enabled but you still need to complete the OpenChange module setup.');
    }
}

1;
