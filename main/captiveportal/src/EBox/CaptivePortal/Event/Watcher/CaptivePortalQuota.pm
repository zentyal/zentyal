# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Event::Watcher::CaptivePortalQuota;

use base 'EBox::Event::Watcher::Base';

use EBox::Event;
use EBox::Global;
use EBox::Gettext;

sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new(period => 0);
    bless ($self, $class);

    return $self;
}

# Method: ConfigurationMethod
#
# Overrides:
#
#       <EBox::Event::Component::ConfigurationMethod>
#
sub ConfigurationMethod
{
    return 'none';
}

# Method: run
#
#        Do nothing.
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        undef in this case
#
sub run
{
}

# Group: Protected methods

# Method: _name
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_name>
#
# Returns:
#
#        String - the event watcher name
#
sub _name
{
    return __('Captive portal');
}

# Method: _description
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::_description>
#
# Returns:
#
#        String - the event watcher detailed description
#
sub _description
{
    return __('Notify when a user is out of quota');
}

# ebackup module should be enabled to use this event
sub Able
{
    my $captiveportal = EBox::Global->getInstance(1)->modInstance('captiveportal');
    defined $captiveportal or
        return 0;
    return $captiveportal->isEnabled();
}

1;
