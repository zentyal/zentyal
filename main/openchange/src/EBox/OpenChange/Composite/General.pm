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

sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    return $self;
}


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

    my $sogoModule = $self->parentModule()->global()->modInstance('sogo');
    my $openchangeModule = $self->parentModule();

    my $readyToUseMessage = __x('You can access the {open_href}OpenChange Webmail{close_href}',
            open_href => "<a href='#' target='_blank' id='sogo_url'>",
            close_href => '</a>');
    $readyToUseMessage .= "<script>document.getElementById('sogo_url').href='http://' + document.domain + '/SOGo';</script>";

    my $needProvisionMessage = __('OpenChange webmail is enabled but you still need to complete the OpenChange module setup.');

    if ($sogoModule->isEnabled() and not $openchangeModule->isProvisioned()) {
        return $needProvisionMessage;
    }

    if ($sogoModule->isEnabled() and $openchangeModule->isProvisioned()) {
        return $readyToUseMessage;
    }

    return undef;
}

1;
