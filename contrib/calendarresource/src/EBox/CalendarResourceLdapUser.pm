# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::CalendarResourceLdapUser;

use base qw(EBox::LdapUserBase);

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use Perl6::Junction qw(any);


sub new
{
    my $class = shift;
    my $self  = {};
    $self->{calendarresource} = EBox::Global->modInstance('calendarresource');
    bless($self, $class);
    return $self;
}

sub _userAddOns
{
    my ($self, $user) = @_;

    return unless ($self->{calendarresource}->configured());

    my $is_resource = 'no';
    $is_resource = 'yes' if ($self->isCalendarResource($user));

    my $autoschedule = 0;
    $autoschedule = 1 if ($self->hasAutoschedule($user));

    my $multiplebookings = $self->getMultipleBookings($user);

    my @args;
    my $args = {
        'user' => $user,
        'is_resource'  => $is_resource,
        'autoschedule' => $autoschedule,
        'multiplebookings' => $multiplebookings,
        'service' => $self->{calendarresource}->isEnabled(),
    };

    return { path => '/calendarresource/calendarresource.mas', params => $args };
}

sub schemas
{
    return [
	EBox::Config::share() . 'zentyal-calendarresource/calentry.ldif',
	EBox::Config::share() . 'zentyal-calendarresource/calresource.ldif',
	]
}

sub hasAutoschedule
{
    my ($self, $user) = @_;

    return ($user->get('autoschedule') eq 'TRUE');
}

sub setAutoschedule
{
    my ($self, $user, $option) = @_;
    my $global = EBox::Global->getInstance();

    return unless ($self->hasAutoschedule($user) xor $option);

    if ($option){
	$user->set('autoschedule', 'TRUE');
    } else {
	$user->set('autoschedule', 'FALSE');
    }
    $global->modChange('calendarresource');
    return 0;
}

sub getMultipleBookings
{
    my ($self, $user) = @_;

    return $user->get('multiplebookings');
}

sub setMultipleBookings
{
    my ($self, $user, $option) = @_;
    my $global = EBox::Global->getInstance();

    return unless ($self->getMultipleBookings($user) ne $option);

    $user->set('multiplebookings', $option);
    $global->modChange('calendarresource');
    return 0;
}

sub isCalendarResource
{
    my ($self, $user) = @_;

    return ('CalendarResource' eq any $user->get('objectClass'));
}

sub setIsCalendarResource
{
    my ($self, $user, $option) = @_;

    if ($self->isCalendarResource($user) and not $option) {
        my @objectclasses = $user->get('objectClass');
        @objectclasses = grep { ! /SchedApprovalInfo|CalendarResource|calEntry/ } @objectclasses;

        $user->delete('Kind', 1);
        $user->delete('Multiplebookings', 1);
        $user->delete('Autoschedule', 1);
        $user->set('objectClass',\@objectclasses, 1);
        $user->save();
    }
    elsif (not $self->isCalendarResource($user) and $option) {
        my @objectclasses = $user->get('objectClass');
        push (@objectclasses, 'calEntry');
        push (@objectclasses, 'CalendarResource');
        push (@objectclasses, 'SchedApprovalInfo');

        $user->set('Kind', 'location', 1);
        $user->set('Multiplebookings', 0, 1);
        $user->set('Autoschedule', 'TRUE', 1);
        $user->set('objectClass', \@objectclasses, 1);
        $user->save();
    }

    return 0;
}

sub _delUserWarning
{
    my ($self, $user) = @_;

    return unless ($self->{calendarresource}->configured());

    $self->isCalendarResource($user) or
        return;

    return __('This account is a calendar resource, if go ahead and' .
	      ' delete it any planned events might suddenly be in the' .
	      ' air!');
}

1;
