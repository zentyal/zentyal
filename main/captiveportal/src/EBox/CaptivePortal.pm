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

use constant VNC_PORT => 5900;

my $UPSTART_PATH= '/etc/init/';

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


# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

}

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
}

sub _daemons
{
    my ($self) = @_;

    return [];
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


1;
