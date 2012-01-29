# Copyright (C) 2011-2012 eBox Technologies S.L.
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

package EBox::CGI::RemoteServices::Wizard::Subscription;

use strict;
use warnings;

use base 'EBox::CGI::WizardPage';

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Validate;
use SOAP::Lite;
use Error qw(:try);

use constant SOAP_URI => 'http://www.zentyal.com';
use constant SOAP_PROXY => 'https://api.zentyal.com/';

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'remoteservices/wizard/subscription.mas', @_);
    bless($self, $class);
    return $self;
}


sub _masonParameters
{
    my ($self) = @_;

    my @params = ();
    my $global = EBox::Global->getInstance();
    my $image = $global->theme()->{'image_title'};
    push (@params, image_title => $image);
    return \@params;
}


sub _processWizard
{
    my ($self) = @_;
    $self->_requireParam('username', __('Email Address'));
    $self->_requireParam('password', __('Password'));
    $self->_requireParam('servername', __('Server name'));
    $self->_requireParam('action', 'action');

    # Registration
    if ($self->param('action') eq 'register') {
        $self->_requireParam('firstname', __('First name'));
        $self->_requireParam('lastname', __('Last name'));
        $self->_requireParam('country', __('Country'));
        $self->_requireParam('phone', __('Phone number'));
        $self->_requireParam('password2', __('Repeated password'));

        unless ($self->param('password') eq $self->param('password2')) {
            throw EBox::Exceptions::External(__('Introduced passwords do not match'));
        }

        $self->_register();
    }

    # Subscription
    $self->_subscribe();
}


sub _register
{
    my ($self) = @_;

    my $user = $self->param('username');
    EBox::info("Registering a new basic subscription ($user)");

    my $result;
    try {
        $result  = SOAP::Lite
             ->uri(SOAP_URI)
             ->proxy(SOAP_PROXY)
             ->autotype(0)
             ->encoding('iso-8859-1')
             ->register_basic($self->param('firstname'),
                              $self->param('lastname'),
                              $self->param('country'),
                              $self->param('username'),
                              $self->param('password'),
                              $self->param('phone'),
                              $self->param('company'));
    } otherwise {
        throw EBox::Exceptions::External(__('An error ocurred registering the subscription, please check your Internet connection.'));
    };

    if (not $result or $result->fault) {
        if ($result) {
            EBox::error('Error subscribing [' . $result->faultcode .
                        '] ' .  $result->faultstring);
        }
        throw EBox::Exceptions::External(__('An unknown error ocurred registering the subscription'));
    }

    if ($result->result > 0) {
        if ($result->result == 1) {
            throw EBox::Exceptions::External(__('An user with that email is already registered. You can check your account data at ') . '<a href="https://store.zentyal.com">store.zentyal.com</a>');
        }
        throw EBox::Exceptions::External(__('Sorry, an unknown exception has ocurred. Try again later or contact info@zentyal.com'));
    }
}

sub _subscribe
{
    my ($self, $user, $pass, $servername) = @_;

    my $rservices = EBox::Global->modInstance('remoteservices');
    my $model = $rservices->model('Subscription');
    $model->set(username => $self->param('username'),
                password => $self->param('password'),
                eboxCommonName => $self->param('servername'));
}

1;
