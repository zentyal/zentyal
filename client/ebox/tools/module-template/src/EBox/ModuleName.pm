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

use base qw(EBox::GConfModule EBox::Model::ModelProvider EBox::Model::CompositeProvider);

use EBox::Gettext;
use EBox::Summary::Module;

# Constructor: _create
#
#        Create an module
#
# Overrides:
#
#        <EBox::GConfModule::_create>
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

# Method: statusSummary
#
#       Show the module summary
#
# Overrides:
#
#       <EBox::Module::summary>
#
sub summary
{
	my ($self) = @_;
	my $item = new EBox::Summary::Module(__("ModuleName stuff"));
	return $item;
}

# Method: statusSummary
#
#       Show the module status summary
#
# Overrides:
#
#       <EBox::Module::statusSummary>
#
sub statusSummary
{

    my ($self) = @_;

    return new EBox::Summary::Status(
                                     'domain',
                                     __('Modulename'),
                                     $self->running(),
                                     $self->service(),
                                    );

}

# Method: models
#
#       Return the models used by the module
#
# Overrides:
#
#       <EBox::Model::ModelProvider::models>
#
sub models
{
}

# Method: composites
#
#       Return the composites used by the module
#
# Overrides:
#
#       <EBox::Model::CompositeProvider::composites>
#
sub composites
{

}

1;
