# Copyright (C) 2009-2010 eBox Technologies S.L.
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

# Class: EBox::IMProxy
#
#      Class description
#

package EBox::IMProxy;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::FirewallObserver
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
           );

use EBox::Gettext;
use EBox::Service;
use EBox::IMProxyFirewall;

use Storable qw(store);

use constant IMSPECTOR_CONF_FILE => "/etc/imspector/imspector.conf";

# Group: Protected methods

# Constructor: _create
#
#        Create an module
#
# Overrides:
#
#        <EBox::Module::Service::_create>
#
# Returns:
#
#        <EBox::IMProxy> - the recently created module
#
sub _create
{
        my $class = shift;
        my $self = $class->SUPER::_create(name => 'improxy',
            domain => 'ebox-improxy',
            printableName => __n('IM Proxy'),
            @_);
        bless($self, $class);
        return $self;
}

# Method: _daemons
#
# Overrides:
#
#       <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'ebox.improxy.imspector'
        },
        {
            'name' => 'ebox.improxy.censord'
        },
    ];
}

# Method: _setConf
#
#        Regenerate the configuration
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    $self->writeConfFile(IMSPECTOR_CONF_FILE, "improxy/imspector.conf.mas");

    my $rules = $self->model('Rules')->rules();
    store($rules, (EBox::Config::conf() . 'censord.conf'));
}

# Group: Public methods

# Method: menu
#
#       Add an entry to the menu with this module
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;
    $root->add(new EBox::Menu::Item('url' => 'IMProxy/View/Rules',
                                    'text' => __('IM Proxy')));
}

# Method: modelClasses
#
#       Return the model classes used by the module.
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [ 'EBox::IMProxy::Model::Rules' ];
}

# Method: compositeClasses
#
#       Return the composite classes used by the module
#
# Overrides:
#
#       <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [];
}

# Method: usedFiles
#
#        Indicate which files are required to overwrite to configure
#        the module to work. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::usedFiles>
#
sub usedFiles
{
    return [
        {
            'file' => IMSPECTOR_CONF_FILE,
            'module' => 'improxy',
            'reason' => 'imspector configuration file'
        }
    ];
}

# Method: actions
#
#        Explain the actions the module must make to configure the
#        system. Check overriden method for details
#
# Overrides:
#
#        <EBox::Module::Service::actions>
sub actions
{
    return [];
}

# Method: enableActions
#
#        Run those actions explain by <actions> to enable the module
#
# Overrides:
#
#        <EBox::Module::Service::enableActions>
#
sub enableActions
{

}

# Method: disableActions
#
#        Rollback those actions performed by <enableActions> to
#        disable the module
#
# Overrides:
#
#        <EBox::Module::Service::disableActions>
#
sub disableActions
{

}

sub firewallHelper
{
    my ($self) = @_;
    if ($self->isEnabled()){
        return new EBox::IMProxyFirewall();
    }
    return undef;
}

# Group: Private methods

1;
