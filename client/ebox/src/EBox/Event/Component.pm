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

# Class: EBox::Event::Component
#
#  This class incorporates those methods which are common for event
#  architecture components: watchers and dispatchers
#
package EBox::Event::Component;

use strict;
use warnings;

use EBox::Exceptions::MissingArgument;

# Group: Public methods

# Constructor: new
#
#     Create a <EBox::Event::Component> object instance
#
# Parameters:
#
#     domain - String the Gettext domain for this event watcher
#
#     - Named parameters
#
sub new
{

    my ($class, %args) = @_;

    defined ( $args{domain} ) or
      throw EBox::Exceptions::MissingArgument('domain');

    my $self = { domain => $args{domain} };
    bless($self, $class);

    return $self;

}

# Method: domain
#
#       Accessor to the Gettext domain
#
# Returns:
#
#       String - the Gettext domain
#
sub domain
{

      my ($self) = @_;

      return $self->{domain};

}

# Method: name
#
#       Accessor to the event component identifier. If
#       <EBox::Event::Component::_name> is not overridden, the
#       class name is returned.
#
# Returns:
#
#       String - the unique name
#
sub name
{

    my ( $self ) = @_;

    my $oldDomain = EBox::Gettext::settextdomain($self->domain());
    my $componentEventName = $self->_name();
    EBox::Gettext::settextdomain($oldDomain);

    return $componentEventName;

}

# Method: ConfigurationMethod
#
#       Class method which determines which kind of method is used in
#       order to select which kind of configuration will be used. This
#       method should be overridden. *(Abstract)*
#
# Returns:
#
#       String - one of the following:
#           - link - if the configuration is done via URL
#           - model - if the configuration is done via Model
#           - none - if no configuration is required
#
sub ConfigurationMethod
{

      throw EBox::Exceptions::NotImplemented();

}

# Method: ConfigureURL
#
#       Get the configuration URL to set the configuration. Static
#       method.
#
# Returns:
#
#       String - the URL where to set the configuration
#
sub ConfigureURL
{

      throw EBox::Exceptions::NotImplemented();

}

# Method: ConfigureModel
#
#       Get the configuration model to set the dispatcher
#       configuration. Static method.
#
# Returns:
#
#       String - the model which describe the configuration
#
sub ConfigureModel
{

      throw EBox::Exceptions::NotImplemented();

}

# Method: EditableByUser
#
#       Check if the given event component is editable
#       (enable/disable) by user or only by eBox code
#
# Returns:
#
#       Boolean - indicating if editable by user or not
#
sub EditableByUser
{
    return 1;
}


# Group: Protected methods

# Method: _name
#
#      The i18ned method to name the event watcher. To be
#      overridden by subclasses.
#
# Returns:
#
#      String - the name. Default value: the class name
#
sub _name
{

    my ($self) = @_;

    # Default, return the class name
    return ref ( $self );

}

1;
