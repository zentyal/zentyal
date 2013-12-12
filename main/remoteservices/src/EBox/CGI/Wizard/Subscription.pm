# Copyright (C) 2011-2012 Zentyal S.L.
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

use feature qw(switch);

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Validate;
use Error qw(:try);
use SOAP::Lite;
use Sys::Hostname;

use constant SOAP_URI => 'http://www.zentyal.com';
use constant SOAP_PROXY => 'https://api.zentyal.com/3.0/';
use constant PROMO_AVAILABLE => 'https://api.zentyal.com/3.0/promo_available';

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => 'remoteservices/wizard/subscription.mas',
                                  @_);
    bless($self, $class);
    return $self;
}


sub _masonParameters
{
    my ($self) = @_;

    my @params = ();
    my $global = EBox::Global->getInstance();

    # check if subscription promo is available (to show the banner)
    my $res;
    try {
        $res = join('', @{EBox::Sudo::command('curl --connect-timeout 5 ' . PROMO_AVAILABLE)});
        chomp($res);
    } otherwise {
        EBox::error("Could not retrieve subscription promo status: $res");
    };

    my $promo = ($res eq '1');

    my ($lang) = split ('_', EBox::locale());
    $lang = 'en' unless ($lang eq 'es');

    my $hostname = Sys::Hostname::hostname();
    ($hostname) = split( /\./, $hostname); # Remove the latest part of
                                           # the hostname to make it a
                                           # valid subdomain name

    push (@params, promo_available => $promo);
    push (@params, lang => $lang);
    push (@params, hostname => $hostname);
    return \@params;
}


sub _processWizard
{
    my ($self) = @_;

    my $rs = EBox::Global->modInstance('remoteservices');
    if ( $rs->eBoxSubscribed() ) {
        throw EBox::Exceptions::External('You cannot register a server if you are already registered. '
                                         . 'Deregister first to go on');
    }

    $self->_requireParam('username', __('Email Address'));
    $self->_requireParam('password', __('Password'));
    $self->_requireParam('servername', __('Server name'));
    $self->_requireParam('action', 'action');

    # Registration
    if ($self->param('action') eq 'register') {
        $self->_requireParam('firstname', __('First name'));
        $self->_requireParam('lastname', __('Last name'));
        $self->_requireParam('phone', __('Phone number'));
        $self->_requireParam('password2', __('Repeated password'));

        unless ($self->param('password') eq $self->param('password2')) {
            throw EBox::Exceptions::External(__('Introduced passwords do not match'));
        }

        unless ( defined($self->param('agree')) and ($self->param('agree') eq 'on') ) {
            throw EBox::Exceptions::External(__s('You must agree to the privacy policy to continue'));
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

    my $position   = $self->param('position');
    $position = "" unless (defined($position));

    my $sector   = $self->param('sector');
    $sector = "" unless (defined($sector));

    my $newsletter = $self->param('newsletter');
    $newsletter = "off" unless(defined($newsletter));

    my $result;
    try {
        $result  = SOAP::Lite
             ->uri(SOAP_URI)
             ->proxy(SOAP_PROXY)
             ->autotype(0)
             ->encoding('iso-8859-1')
             ->register_basic($self->param('firstname'),
                              $self->param('lastname'),
                              '', # country no longer sent
                              $self->param('username'),
                              $self->param('password'),
                              $self->param('phone'),
                              $self->param('company'),
                              $newsletter,
                              $position,
                              $sector);
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
        given ($result->result() ) {
            when ( 1 ) {
                throw EBox::Exceptions::External(__('An user with that email is already registered. You can check your account data at ') . '<a href="https://store.zentyal.com">store.zentyal.com</a>');
            }
            when ( 2 ) {
                throw EBox::Exceptions::External(__('Password must have at least 6 characters. Leading or trailing spaces will be ignored.'));
            }
            default {
                throw EBox::Exceptions::External(__('Sorry, an unknown exception has ocurred. Try again later or contact info@zentyal.com'));
            }
        }
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
