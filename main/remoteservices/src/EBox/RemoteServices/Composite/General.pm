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

# Class: EBox::RemoteServices::Composite::General
#
#    Display the two forms that are exclusively used by remote
#    services
#

use strict;
use warnings;

package EBox::RemoteServices::Composite::General;

use base 'EBox::Model::Composite';

use EBox::Gettext;
use EBox::Global;

use constant SUBS_WIZARD_URL => '/Wizard?page=RemoteServices/Wizard/Subscription';
use constant TRIAL_URL       => 'https://remote.zentyal.com/trial/ent/';

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{
    my $printableName = __('Your Zentyal Server Account');

    my $description = {
          layout          => 'top-bottom',
          name            => 'General',
          compositeDomain => 'RemoteServices',
          printableName   => $printableName,
          pageTitle       => $printableName,
    };

    my $rs = EBox::Global->modInstance('remoteservices');
    if ( $rs->eBoxSubscribed() and $rs->subscriptionLevel() <= 0) {
        $description->{permanentMessage} = _commercialTrialMsg();
        $description->{permanentMessageType} = 'ad';
    } elsif ( not $rs->eBoxSubscribed() ) {
        $description->{permanentMessage} = _commercialMsg();
        $description->{permanentMessageType} = 'ad';
    }

    return $description;
}

# Group: Private methods

sub _commercialMsg
{
    return __sx('Are you interested in a remote configuration backup of your Zentyal '
                . 'Server? Or do you want to use a subdomain, such as '
                . 'yourserver.zentyal.me? Get a {ohb}Free Zentyal Account{ch} that gives you '
                . 'access to these features and much more! Or, if you already have a Commercial '
                . 'Edition, use your credentials for full access.',
                ohb => '<a href="' . SUBS_WIZARD_URL . '">', ch  => '</a>');
}

sub _commercialTrialMsg
{
    return __sx('Are you interested in upgrading to one of commercial editions? Get '
                . 'a {ohb}Free 30-day trial{ch}.',
                ohb => '<a href="' . TRIAL_URL . '">', ch  => '</a>');
}

1;
