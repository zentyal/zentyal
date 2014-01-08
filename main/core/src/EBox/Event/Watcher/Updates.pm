# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Event::Watcher::Updates;
# Class: EBox::Event::Watcher::Updates
#
#   This class is a watcher which checks if there is any software
#   updates available in our system and show a message informing how
#   this could break the system.
#
#   This check is done weekly.
#

use 5.010;

use base 'EBox::Event::Watcher::Base';

use EBox::Event;
use EBox::Gettext;
use EBox::Global;
use EBox::Util::Software;

# Group: Public methods

# Constructor: new
#
#        The constructor for <EBox::Event::Watcher::Updates>
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
#        <EBox::Event::Watcher::Updates> - the newly created object
#
sub new
{
    my ($class) = @_;

    my $self = $class->SUPER::new(period => 50 * 60);
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

# Method: Able
#
#        Overrides to perform the check only if community edition is
#        registered
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::Able>
#
sub Able
{
    my $gl = EBox::Global->getInstance(1);

    my $retVal = 0;
    if ( $gl->modExists('remoteservices') ) {
        my $rs = $gl->modInstance('remoteservices');
        if ( $rs->eBoxSubscribed() ) {
            my $subsLevel = $rs->subscriptionLevel();
            $retVal = ($subsLevel == 0); # Only for paid editions
            if ( $subsLevel == -1) {
                # We don't know yet the subscription level
                if ( $gl->modExists('software') ) {
                    my $software = $gl->modInstance('software');
                    $retVal = (not $software->QAUpdates());
                }
            }
        }
    }

    return $retVal;
}

# Method: HiddenIfNotAble
#
#        Overrides to hide the event when it is not able to watch the
#        event
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::HiddenIfNotAble>
#
sub HiddenIfNotAble
{
    return 1;
}

# Method: DisabledByDefault
#
#        Overrides to enable the event by default
#
# Overrides:
#
#        <EBox::Event::Component::DisabledByDefault>
#
sub DisabledByDefault
{
    return 0;
}

# Method: run
#
#        Check if there is any updates
#
# Overrides:
#
#        <EBox::Event::Watcher::Base::run>
#
# Returns:
#
#        undef - if all partitions have sufficent space left
#
#        array ref - <EBox::Event> an event is sent when some
#        partitions does not have space left
#
sub run
{
    my ($self) = @_;

    my $latestUpdate = EBox::Util::Software::latestUpdate();
    return undef unless ( $latestUpdate > $self->_latestStatus() );

    $self->_setStatus($latestUpdate);

    # [updates, sec_updates]
    my ($nUpdates, $nSecUpdates) = @{EBox::Util::Software::upgradablePkgsNum()};

    my @packages = ();
    my @secUpdates = ();
    if ( $nUpdates > 0 or $nSecUpdates > 0) {
        # Get the package names
        @packages = @{EBox::Util::Software::upgradablePkgs()};

        # Check for a security update or not
        @secUpdates = grep { EBox::Util::Software::isSecUpdate($_) } @packages;

        if ( not @secUpdates ) {
            # No new sec updates, update the list
            $self->_setStoredSecurityUpdates([]);
            return undef;
        }

        my $currentStored = $self->_storedSecurityUpdates();
        # Return if they are the same ones.
        return undef if ( @secUpdates ~~ @{$currentStored} );
    }

    if ( @secUpdates > 0 ) {
        my $msg = __x('There are {nSecUpdates} security updates. The affected packages are: {packages}.',
                      nSecUpdates => $nSecUpdates, packages => join(', ', @secUpdates));
        $msg .= "\n\n";

        my $nSysUpdates = $nUpdates - $nSecUpdates;
        if ($nSysUpdates > 0 ) {
            # Perform the diff among packages and secUpdates
            my %count;
            my @diff;
            foreach my $pkg (@packages, @secUpdates) { $count{$pkg}++; };
            foreach my $pkg (keys %count) {
                push(@diff, $pkg) if ( $count{$pkg} == 1 );
            }
            $msg .= __x('Additionally, there are {nUpdates} more. The upgradable packages are: {packages}.',
                        nUpdates => $nSysUpdates, packages => join(', ', @diff));
        }

        # Commercial msg
        $msg .= "\n\n";
        $msg .= __sx("Warning: These are untested community updates that might harm your system. In production environments we recommend using the {oh}Professional, Business or Premium Editions{ch}: commercial Zentyal server editions fully supported by Zentyal S.L. and Canonical/Ubuntu.",
                     oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
        return [
            new EBox::Event(message => $msg,
                            source  => 'security-software-update',
                            level   => 'warn',
                            additional => {
                                'n_updates'     => $nUpdates,
                                'n_sec_updates' => $nSecUpdates,
                                'updates'       => \@packages,
                                'sec_updates'   => \@secUpdates,
                            }),
           ];
    }
    return [
        new EBox::Event(message    => 'Up-to-date',
                        source     => 'security-software-update',
                        level      => 'info',
                        dispatchTo => [ 'ControlCenter' ],
                        additional => { 'n_updates' => 0 }),
        ];
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
    return __('Security software updates');
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
    return __('Check if there is any security software update.');
}

# Group: Private methods

sub _list_key
{
    return "security_updates/list";
}

# Return the stored security updates
sub _storedSecurityUpdates
{
    my ($self) = @_;

    my $eventsMod = EBox::Global->modInstance('events');

    my $key = $self->_list_key();
    my $list = [];
    if ( $eventsMod->st_entry_exists($key) ) {
        $list = $eventsMod->st_get_list($key);
    }

    return $list;

}

# Set the alerted security updates
sub _setStoredSecurityUpdates
{
    my ($self, $secUpdates) = @_;

    my $eventsMod = EBox::Global->modInstance('events');
    my $key = $self->_list_key();
    $eventsMod->st_set_list($key, $secUpdates);
}

sub _latest_status_key
{
    return 'security_updates/latest_status';
}

# Return the latest apt-get update timestamp with new packages
sub _latestStatus
{
    my ($self) = @_;

    my $eventsMod = EBox::Global->modInstance('events');

    my $key = $self->_latest_status_key();
    my $timestamp = 0;
    if ( $eventsMod->st_entry_exists($key) ) {
        $timestamp = $eventsMod->st_get_int($key);
    }

    return $timestamp;

}

# Set the latest timestamp apt-get update
sub _setStatus
{
    my ($self, $timestamp) = @_;

    my $eventsMod = EBox::Global->modInstance('events');
    my $key = $self->_latest_status_key();
    $eventsMod->st_set_int($key, $timestamp);
}

1;
