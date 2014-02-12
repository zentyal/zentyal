# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

# Class: EBox::WebService::Model::GeneralComposite
#
#

use strict;
use warnings;

package EBox::WebServer::Composite::General;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;

# Method: precondition
#
#   Check that Apache ports are configured in the reverse proxy
#
sub precondition
{
    my ($self) = @_;

    my $webserverMod = $self->parentModule();
    unless ($webserverMod->isHTTPPortEnabled() or $webserverMod->isHTTPSPortEnabled()) {
        $self->{preconditionFail} = 'notEnabledInHAProxy';
        return undef;
    }

    return 1;
}

# Method: preconditionFailMsg
#
#   Show the precondition failure message
#
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconditionFail} eq 'notEnabledInHAProxy') {
        return __x('You must enable {module} ports on the Zentyal\'s reverse proxy configuration at ' .
                   '{ohref}System\'s General configuration page{chref}.',
                   module => $self->parentModule()->printableName(),
                   ohref  => '<a href="/SysInfo/Composite/General">',
                   chref  => '</a>'
        );
    }
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
    my $description = {
       layout          => 'top-bottom',
       name            => 'General',
       printableName   => __('Configuration'),
       pageTitle       => __('Web Server'),
       compositeDomain => 'Web',
       help            => __('The Zentyal webserver allows you ' .
                             'to host HTTP and HTTPS pages ' .
                             'within different virtual hosts.'),
    };

    return $description;
}

1;
