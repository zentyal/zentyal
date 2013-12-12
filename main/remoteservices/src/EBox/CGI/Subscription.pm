# Copyright (C) 2012-2012 Zentyal S.L.
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

package EBox::CGI::RemoteServices::Subscription;
use base qw(EBox::CGI::ClientBase  EBox::CGI::ProgressClient);

# Class: EBox::CGI::RemoteServices::Subscription
#
#     CGI to perform the indication of subscription process
#

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Subscription::Action;

# Constructor: new
#
#    Create a new CGI
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);

    # Set error chain to use subscription menu
    $self->{errorchain} = 'RemoteServices/View/Subscription';
    # Set redirect to the whole composite
    $self->{redirect}   = 'RemoteServices/Composite/General';

    bless($self, $class);
    return $self;
}

sub requiredParameters
{
    return [];
}

sub optionalParameters
{
    return ['wizard'];
}

sub actuate
{
    my ($self) = @_;

    my $progress = EBox::RemoteServices::Subscription::Action->subscribe();
    $self->showSubscriptionProgress($progress);
}

sub showSubscriptionProgress
{
    my ($self, $progressIndicator) = @_;

    my $rs = EBox::Global->getInstance()->modInstance('remoteservices');
    my ($title, $endNote, $errorNote) = ( __('Registering your server'),
                                          __('Registration finished'),
                                          __x('There was an error in the registration. '
                                              . 'There are more information in the logs directory {dir}',
                                              dir => EBox::Config->log()),
                                         );
    unless ( $rs->eBoxSubscribed() ) {
        $title     = __('Unregistering your server');
        $endNote   = __('Unregistration finished');
        $errorNote = __x('There was an error in the registration. '
                         . 'There are more information in the logs directory {dir}',
                         dir => EBox::Config->log());
    }

    my @params = (
        progressIndicator  => $progressIndicator,
        title              => $title,
        text               => __('Making changes in your configuration'),
        currentItemCaption => __('Current operation'),
        itemsLeftMessage   => __('operations performed'),
        endNote            => $endNote,
        errorNote          => $errorNote,
        reloadInterval     => 2);

    my @popupProgressParams = (
        raw          => 1,
        inModalbox   => 1,
        nextStepType => 'submit',
        nextStepText => __('OK'),
        nextStepUrl  => '#',
       );

    my $nextStepUrlOnclick = "Modalbox.hide(); window.location.reload(); return false";
    if ( $self->param('wizard' ) ) {
        $nextStepUrlOnclick = "Modalbox.hide(); window.location = '/RemoteServices/Composite/General'; return false";
    }

    push(@params, @popupProgressParams);
    push(@params, (nextStepUrlOnclick => $nextStepUrlOnclick));

    $self->showProgress(@params);

}

# Override to print the modal box
sub _print
{
    my ($self) = @_;
    if (not $self->param('popup')) {
        return $self->SUPER::_print();
    }

    $self->_printPopup();
}


1;
