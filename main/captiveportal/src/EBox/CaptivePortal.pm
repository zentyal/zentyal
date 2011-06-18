# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::CaptivePortal;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
            EBox::FirewallObserver);

use EBox;
use EBox::Gettext;
use EBox::Menu::Item;
use Error qw(:try);
use EBox::Sudo;
use EBox::CaptivePortalFirewall;

use constant CAPTIVE_DIR => '/var/lib/zentyal-captiveportal/';
use constant APACHE_CONF => CAPTIVE_DIR . 'apache2.conf';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'captiveportal',
                                      printableName => __('Captive Portal'),
                                      @_);
    bless($self, $class);
    return $self;
}

# Method: actions
#
#   Override EBox::Module::Service::actions
#
sub actions
{
    return [
        {
            'action' => __('FIXME'),
            'reason' => __('Zentyal will take care of FIXME'),
            'module' => 'activeportal'
        }
    ];
}

# Method: usedFiles
#
#   Override EBox::Module::Service::usedFiles
#
#sub usedFiles
#{
#    return [
#            {
#             'file' => '/tmp/FIXME',
#             'module' => 'captiveportal',
#             'reason' => __('FIXME configuration file')
#            }
#           ];
#}


sub modelClasses
{
    return [
        'EBox::CaptivePortal::Model::Interfaces',
        'EBox::CaptivePortal::Model::Settings',
    ];
}

sub compositeClasses
{
    return [ 'EBox::CaptivePortal::Composite::General' ];
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'CaptivePortal/Composite/General',
                                    'text' => $self->printableName(),
                                    'separator' => 'Gateway',
                                    'order' => 226));
}

sub _setConf
{
    my ($self) = @_;
    my $settings = $self->model('Settings');

    # Apache conf file
    EBox::Module::Base::writeConfFileNoCheck(APACHE_CONF,
        "captiveportal/captiveportal-apache2.conf.mas",
        [
            http_port => $settings->http_portValue(),
            https_port => $settings->https_portValue(),
        ])

}

sub _daemons
{
    my ($self) = @_;

    return [
        {
            'name' => 'zentyal.apache2-captiveportal'
        },
    ];
}

# Method: widgets
#
#   Returns the widgets offered by this module
#
# Overrides:
#
#       <EBox::Module::widgets>
#
#sub widgets
#{
#}


sub firewallHelper
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        return new EBox::CaptivePortalFirewall();
    }
    return undef;
}



# Function: usesPort
#
#   Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
    my ($self, $protocol, $port, $iface) = @_;

    ($protocol eq 'tcp') or return undef;
    ($self->isEnabled()) or return undef;

    my $model = $self->model('Settings');

    ($port eq $model->http_portValue()) and return 1;
    ($port eq $model->https_portValue()) and return 1;

    return undef;
}


# Function: httpPort
#
#   Returns the port where captive portal HTTP redirection resides
#
sub httpPort
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    return $settings->http_portValue(),
}


# Function: httpsPort
#
#   Returns the port where captive portal resides
#
sub httpsPort
{
    my ($self) = @_;
    my $settings = $self->model('Settings');
    return $settings->https_portValue(),
}


# Function: ifaces
#
#   Interfaces where captive portal is enabled
#
sub ifaces
{
    my ($self) = @_;
    my $model = $self->model('Interfaces');
    my $ids = $model->ids();
    my @ifaces;
    for my $id (@{$ids}) {
        my $row = $model->row($id);
        if($row->valueByName('enabled')) {
            push(@ifaces, $row->valueByName('interface'));
        }
    }
    return \@ifaces;
}


1;
