# Copyright (C) 2009 eBox Technologies S.L.
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


package EBox::Network::Composite::WANFailover;
use base 'EBox::Model::Composite';

## eBox uses
use EBox::Gettext;
use EBox::Global;
use EBox::Model::ModelManager;

# Group: Public methods

# Constructor: new
#
#         Constructor for the DNS composite
#
# Returns:

sub new
  {

      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);

      return $self;

  }

# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{
    my $description = {
        components      => [
                              'WANFailoverOptions',
                              'WANFailoverRules',
                           ],
        layout          => 'top-bottom',
        printableName   => __('WAN Failover'),
        compositeDomain => 'Network',
        name            => 'WANFailover',
    };

    return $description;
}

sub precondition
{
    return (_isEventsEnabled() and _isWatcherEnabled());
}

sub preconditionFailMsg
{
    unless (_isEventsEnabled()) {
        return __('Events module is not enabled. You have to enable it and also enable the WAN Failover event in order to use this feature.');
    }

    unless (_isWatcherEnabled()) {
        return __('WAN Failover event is not enabled. You have to enable it in order to use this feature');
    }
}

sub _isEventsEnabled
{
    my $events = EBox::Global->getInstance()->modInstance('events');

    return $events->isEnabled();
}

sub _isWatcherEnabled
{
    my $events = EBox::Global->getInstance()->modInstance('events');

    return $events->isEnabledWatcher('EBox::Event::Watcher::Gateways')->value();
}


1;
