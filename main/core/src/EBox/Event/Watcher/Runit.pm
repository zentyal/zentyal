# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Event::Watcher::Runit;

use base 'EBox::Event::Watcher::Base';

# Class: EBox::Event::Watcher::Runit
#
#   This class is a watcher which checks if a service has been down
#   for MAX_DOWN_PERIODS in PERIODS and send an event notifying it
#

use constant PERIOD => 60;
use constant MAX_DOWN_PERIODS => 5;
use constant DOMAIN => 'ebox';

use EBox::Event;
use EBox::Event::Watcher::Base;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Service;
use EBox::Global;

# Core modules
use Error qw(:try);
use Fcntl qw(:flock); # Import LOCK * constants

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::Runit>
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
#        <EBox::Event::Watcher::Runit> - the newly created object
#
sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new(
                                  period      => PERIOD,
                                  domain      => DOMAIN,
                                 );
    bless( $self, $class);

    $self->{downPeriods} = {};

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
#        Check if any service is being restarted many times within a
#        time interval.
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        undef - if no services are out of control (Chemical
#        Brothers!)
#
#        array ref - <EBox::Event> an event is sent when some service
#        is out of control or come back to order
#
sub run
{
    my ($self) = @_;

    my $modules = $self->_runningAlertServices();
    my @events = ();
    if (@{$modules->{notRunning}->{names}}) {
        $msg = __x("The following modules are not running but they are enabled: {modules}\n",
                   modules => join(', ', @{$modules->{notRunning}->{printableNames}}) );

        my %modules = map { $_ => 1 } @{$modules->{notRunning}->{names}};

        push(@events, new EBox::Event(
            message     => $msg,
            level       => 'error',
            source      => 'networkservice',
            additional  => \%modules,
           ));
    }
    if (@{$modules->{runningAgain}->{names}}) {
        $msg = __x("The following modules are running again: {modules}\n",
                   modules => join(', ', @{$modules->{runningAgain}->{printableNames}}) );

        my %modules = map { $_ => 1 } @{$modules->{runningAgain}->{names}};

        push(@events, new EBox::Event(
            message     => $msg,
            level       => 'info',
            source      => 'networkservice',
            additional  => \%modules));
    }

    return \@events;
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
    return __('Service');
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
    return __('Check if any Zentyal service is not running when it is enabled');
}

# Method: _runningAlertServices
#
#   Generate events for services which are running or not when they should
sub _runningAlertServices
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance(1);

    my $class = 'EBox::Module::Service';
    my %ret = ( notRunning => { printableNames => [], names => [] },
                runningAgain => { printableNames => [], names => [] } );
    for my $mod (@{$gl->modInstancesOfType($class)}) {
        next unless ($mod->can('isRunning'));
        my $enabled = $mod->isEnabled();
        my $running = $mod->isRunning();
        my $name = $mod->name();

        if (not $running and $enabled) {
            unless (exists $self->{downPeriods}->{$name}) {
                $self->{downPeriods}->{$name} = 0;
            }

            if ($self->{downPeriods}->{$name}++ >= MAX_DOWN_PERIODS) {
                push (@{$ret{notRunning}->{printableNames}}, $mod->printableName());
                push (@{$ret{notRunning}->{names}}, $name);
            }

            EBox::debug("Module $name is not running (" .
                $self->{downPeriods}->{$name} . ')');
        } elsif (exists $self->{downPeriods}->{$name}
                 and $self->{downPeriods}->{$name} >= MAX_DOWN_PERIODS) {
            EBox::debug("Module $name is running again");
            delete $self->{downPeriods}->{$name};
            push (@{$ret{runningAgain}->{printableNames}}, $mod->printableName());
            push (@{$ret{runningAgain}->{names}}, $name);
        }
    }
    return \%ret;
}

1;
