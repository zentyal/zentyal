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

use strict;
use warnings;

# Class: EBox::OpenChange::CGI::Provision
#
#   CGI to perform the indication of provision process
#

package EBox::OpenChange::CGI::Provision;

use base qw(EBox::CGI::ClientBase EBox::CGI::ProgressClient);

use EBox::Global;
use EBox::Gettext;

# Constructor: new
#
#    Create a new CGI
#
sub new
{
    my ($class, @params) = @_;

    EBox::info("NEW");
    my $self = $class->SUPER::new(@params);

    # Set error chain to use provision menu
    $self->{errorchain} = 'OpenChange/View/Provision';
    # Set redirect to the whole composite
    $self->{redirect}   = 'OpenChange/View/Provision';

    bless ($self, $class);

    return $self;
}

sub requiredParameters
{
    EBox::info("requiredParameters");
    #return ['firstorganization', 'firstorganizationunit'];
    return [];
}

sub optionalParameters
{
    EBox::info("optionalParameters");
    return [];
}

sub actuate
{
    my ($self) = @_;

    EBox::info("actuate");
    #my $progress = EBox::RemoteServices::Subscription::Action->subscribe();
    #$self->showSubscriptionProgress($progress);

    my $executable = EBox::Config::share() . "/zentyal-openchange/provision";
    my $progressIndicator =  EBox::ProgressIndicator->create(
            executable => $executable,
            totalTicks => 15);

    $progressIndicator->runExecutable();
    $self->showProvisionProgress($progressIndicator);
}

sub showProvisionProgress
{
    my ($self, $progressIndicator) = @_;

    my ($title, $endNote, $errorNote) = ( __('Registering your server'),
                                          __('Registration finished'),
                                          __x('There was an error in the registration. '
                                              . 'There are more information in the logs directory {dir}',
                                              dir => EBox::Config->log()),
                                         );

    my @params = (
        progressIndicator  => $progressIndicator,
        title              => $title,
        text               => __('Making changes in your configuration'),
        currentItemCaption => __('Current operation'),
        itemsLeftMessage   => __('operations performed'),
        endNote            => $endNote,
        errorNote          => $errorNote,
        nextStepTimeout    => 5,
        reloadInterval     => 2);

    my @popupProgressParams = (
        raw          => 1,
        inModalbox   => 1,
        nextStepType => 'submit',
        nextStepText => __('OK'),
        nextStepUrl  => '#',
        nextStepUrlOnclick => "Zentyal.Dialog.close(); window.location.reload(); return false",
       );

    push(@params, @popupProgressParams);

    $self->showProgress(@params);
}

# Override to print the modal box
sub _print
{
    my ($self) = @_;

    EBox::info("_print");
#    if (not $self->param('popup')) {
#        return $self->SUPER::_print();
#    }
#
#    $self->_printPopup();
}

1;
