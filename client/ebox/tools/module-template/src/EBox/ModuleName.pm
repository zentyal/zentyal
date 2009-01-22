# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::ModuleName
#
#      Class description
#

package EBox::ModuleName;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::Model::CompositeProvider
           );

use EBox::Gettext;
use EBox::Service;
use EBox::Dashboard::Module;

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
#        <EBox::ModuleName> - the recently created module
#
sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'modulename');
	bless($self, $class);
	return $self;
}

# Method: _regenConfig
#
#        Regenerate the configuration
#
# Overrides:
#
#       <EBox::Module::_regenConfig>
#
sub _regenConfig
{
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
    return [];
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
    return [];
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

# Method: isRunning
#
#        Check if the service is running or not
#
# Overrides:
#
#        <EBox::Module::Service::isRunning>
#
sub isRunning
{

}

# Group: Private methods

1;
