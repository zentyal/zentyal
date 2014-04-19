# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::RemoteServices::CGI::Wizard::Subscription;

use base 'EBox::CGI::WizardPage';

no warnings 'experimental::smartmatch';
use feature qw(switch);

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::RemoteServices::RESTClient;
use EBox::Validate;
use SOAP::Lite;
use TryCatch::Lite;
use Sys::Hostname;

# Group: Constants

use constant GO_URL          => 'https://go.pardot.com/l/24292/2013-10-28/261g7';
use constant PROMO_AVAILABLE => 'https://api.zentyal.com/3.2/promo_available';
use constant RESET_URL       => 'https://remote.zentyal.com/reset/';

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
    } catch {
        EBox::error("Could not retrieve subscription promo status: $res");
    }

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
                                         . 'Unregister first, to go on');
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

        my $registeringData = $self->_register();
        $self->_track($registeringData);
    }

    # Subscription
    $self->_subscribe();
}

sub _register
{
    my ($self) = @_;

    my $user = $self->param('username');
    EBox::info("Registering a new community subscription ($user)");

    my $position = $self->param('position');
    $position = 'other' unless ($position);

    my $sector = $self->param('sector');
    $sector = 'other' unless ($sector);

    my $newsletter = $self->param('newsletter');
    $newsletter = "" unless(defined($newsletter));

    my $result;
    my $restClient = new EBox::RemoteServices::RESTClient();
    # Construct the registering data to return it back
    my $registeringData = {
        email                 => $self->param('username'),
        first_name            => $self->param('firstname'),
        last_name             => $self->param('lastname'),
        phone                 => $self->param('phone'),
        company_name          => $self->param('company'),
        position_in_company   => $position,
        sector                => $sector,
        subscribed_newsletter => $newsletter,
    };
    try {
        $result = $restClient->POST('/v1/community/users/',
                                    query => { %{$registeringData},
                                               password => $self->param('password') });
    } catch (EBox::Exceptions::External $exc) {
        my $error = $restClient->last_error();
        EBox::error('Error registering user: ' . $exc->stringify());
        my $errorData = $error->data();
        # We assume a single error by key
        my $errorText = "";
        foreach my $key (keys %{$errorData}) {
            given ($key) {
                when ('company_name') {
                    if ($self->param('company')) {
                        if (join("", @{$errorData->{$key}}) =~ m/already/) {
                            $errorText .= '<p>'
                              . __x('Company "{company}" already exists. Please, choose a different name.',
                                    company => $self->param('company'))
                              . '</p>';
                        } else {
                            $errorText .= '<p>' . join(". ", @{$errorData->{$key}}) . '</p>';
                        }
                    } # else, ignore it as the name is composed with name parts
                }
                when ('email') {
                    if (join("", @{$errorData->{$key}}) =~ m/already/) {
                        $errorText .= '<p>'
                          . __x('An user with that email is already registered. You can reset your password at {openhref}here{closehref}.',
                                openhref  => '<a href="' . RESET_URL . '" target="_blank">',
                                closehref => '</a>')
                          . '</p>';
                    } else {
                        $errorText .= '<p>' . join(". ", @{$errorData->{$key}}) . '</p>';
                    }
                }
                when ('password') {
                    $errorText .= '<p>' . __('Password must have at least 6 characters. Leading or trailing spaces will be ignored.') . '</p>';
                }
                default {
                    $errorText .= '<p>' . $key . " : " . join(". ", @{$errorData->{$key}}) . "</p>";
                }
            }
        }
        throw EBox::Exceptions::External($errorText);
    } catch {
        throw EBox::Exceptions::External(__('An error ocurred registering the user, please check your Internet connection.'));
    }

    return $registeringData;
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

sub _track
{
    my ($self, $data) = @_;

    my $trackURI = new URI(GO_URL);
    $trackURI->query_form($data);
    $self->{json}->{trackURI} = $trackURI->as_string();
}

1;
