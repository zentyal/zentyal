# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Event::Watcher::EBackup;

# Class: EBox::Event::Watcher::EBackup;

use base 'EBox::Event::Watcher::Base';
#
# This class is a watcher which checks the data backup status
#

use EBox::Event;
use EBox::Global;
use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::EBackup>
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::new>
#
# Parameters:
#
#        - non parameters
#
# Returns:
#
#        <EBox::Event::Watcher::EBackup> - the newly created object
#
sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new(period => 0);
    bless( $self, $class);

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

# Method: DisabledByDefault
#
#       Backup event is enabled by default
#
# Overrides:
#
#       <EBox::Event::Component::DisabledByDefault>
#
sub DisabledByDefault
{
    return 0;
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
#        array ref - <EBox::Event> an info event is sent if Zentyal is up and
#        running and a fatal event if Zentyal is down
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
    return __('Backup');
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
    return __('Notify the result of scheduled backups.');
}

# ebackup module should be enabled to use this event
sub Able
{
    my $ebackup = EBox::Global->getInstance(1)->modInstance('ebackup');
    defined $ebackup or
        return 0;
    return $ebackup->isEnabled();
}

1;
