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

package EBox::CGI::CalendarResource::UserOptions;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::CalendarResourceLdapUser;


sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => 'Calendar Resource',
				  @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    my $calendarresource = new EBox::CalendarResourceLdapUser;

    $self->_requireParam('user', __('user'));
    my $dn = $self->unsafeParam('user');
    $self->{redirect} = "UsersAndGroups/User?user=$dn";
    $self->keepParam('user');

    my $user = new EBox::UsersAndGroups::User(dn => $dn);

    if ($self->param('is_resource') eq 'yes') {
        $calendarresource->setIsCalendarResource($user, 1);
        if (defined($self->param('autoschedule')))
        {
            $calendarresource->setAutoschedule($user, 1);
        } else {
            $calendarresource->setAutoschedule($user, 0);
        }
        if (defined($self->param('multiplebookings')))
        {
            $calendarresource->setMultipleBookings(
		$user,
		$self->param('multiplebookings'));
        }
    } else {
        if ($calendarresource->isCalendarResource($user)){
            $calendarresource->setIsCalendarResource($user, 0);
        }
    }
}

1;
