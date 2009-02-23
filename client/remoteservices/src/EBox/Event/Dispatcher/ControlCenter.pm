# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Event::Dispatcher::ControlCenter;

# Class: EBox::Dispatcher::ControlCenter
#
# This class is a dispatcher which sends the event to the control
# center where will be display by control panel
#

use base 'EBox::Event::Dispatcher::Abstract';

use strict;
use warnings;

# eBox uses
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Model::ModelManager;
use EBox::RemoteServices::Alerts;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Dispatcher::ControlCenter>
#
#
# Returns:
#
#        <EBox::Event::Dispatcher::ControlCenter> - the newly created object
#
sub new
{

    my ($class) = @_;

    my $self = $class->SUPER::new('ebox');
    bless( $self, $class );

    return $self;

}

# Method: configured
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::configured>
#
sub configured
{

    my ($self) = @_;

#     my $eBoxSubscribed = EBox::Model::ModelManager->instance()
#       ->model('Subscription')->eBoxSubscribed();

#     return $eBoxSubscribed;
    return 1;

}


# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Component::ConfigurationMethod>
#
sub ConfigurationMethod
{

    return 'link';

}

# Method: ConfigureURL
#
# Overrides:
#
#       <EBox::Event::Component::ConfigureURL>
#
sub ConfigureURL
{

    return '/ebox/RemoteServices/View/Subscription';

}

# Method: EditableByUser
#
# Overrides:
#
#       <EBox::Event::Component::EditableByUser>
#
sub EditableByUser
{
    return 0;
}

# Method: send
#
#        Send the event to the admin using Jabber protocol
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::send>
#
sub send
{

    my ($self, $event) = @_;

    defined ( $event ) or
      throw EBox::Exceptions::MissingArgument('event');

    my $alertSender = new EBox::RemoteServices::Alerts();
    $alertSender->pushAlerts([ $event ]);

}

# Group: Protected methods

# Method: _receiver
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_receiver>
#
sub _receiver
{

    return __('Control panel');

}

# Method: _name
#
# Overrides:
#
#       <EBox::Event::Dispatcher::Abstract::_name>
#
sub _name
{

    return __('Control center');

}

# Method: _enable
#
# Overrides:
#
#        <EBox::Event::Dispatcher::Abstract::_enable>
#
sub _enable
{
}

# Group: Private methods

1;
