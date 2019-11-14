# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::Dashboard::CGI::Index;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Config;
use EBox::WebAdmin;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Item;
use POSIX qw(INT_MAX);
use TryCatch;

# TODO: Currently we can't have more than two dashboards because of
# the design of the interface, but this could be incremented in the future
my $NUM_DASHBOARDS = 2;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_, title => __('Dashboard'),
                                  'template' => '/dashboard/index.mas');
    bless($self, $class);
    return $self;
}

my $widgetsToHide = undef;

# Method: masonParameters
#
# Overrides:
#
#   <EBox::CGI::Base::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;

    # Delete first install and DR files if they exist
    EBox::Global->deleteFirst();

    unless (defined $widgetsToHide) {
        $widgetsToHide = {
            map { $_ => 1 } split (/,/, EBox::Config::configkey('widgets_to_hide'))
        };
    }

    my $global = EBox::Global->getInstance(1);
    my $sysinfo = $global->modInstance('sysinfo');
    my @modNames = @{$global->modNames()};
    my $widgets = {};
    foreach my $name (@modNames) {
        my $mod = $global->modInstance($name);
        my $wnames;
        try {
            $wnames = $mod->widgets();
        } catch($ex) {
            EBox::error("Error loading widgets from module $name: $ex");
        }
        if (not $wnames) {
            next;
        }
        for my $wname (keys (%{$wnames})) {
            my $fullname = "$name:$wname";
            next if exists $widgetsToHide->{$fullname};
            $widgets->{$fullname} = $wnames->{$wname};
        }
    }

    # put the widgets in the dashboards according to the last configuration
    my @dashboards;
    for my $i (1 .. $NUM_DASHBOARDS) {
        my @dashboard;
        for my $wname (@{$sysinfo->getDashboard("dashboard$i")}) {
            if (delete $widgets->{$wname}) {
                my ($module, $name) = split (/:/, $wname);

                my $mod = $global->modInstance($module);
                next unless defined ($mod);

                my $widget = $mod->widget($name);
                next unless defined ($widget);

                push (@dashboard, $widget);
            }
        }
        $dashboards[$i - 1] = \@dashboard;
    }

    # put default order values
    foreach my $widget (values %{$widgets}) {
        defined $widget->{order} or
            $widget->{order} = 0;
    }
    my @orderedWidgets =
        sort { $widgets->{$a}->{order} <=> $widgets->{$b}->{order} }
        keys %{$widgets};

    # put the remaining widgets in the dashboards trying to balance them
    foreach my $wname (@orderedWidgets) {
        next if $sysinfo->isWidgetKnown($wname);

        $sysinfo->addKnownWidget($wname);
        my $winfo = delete $widgets->{$wname};
        next unless (defined ($winfo) and $winfo->{default});

        my ($module, $name) = split (/:/, $wname);

        my $mod = EBox::Global->modInstance($module);
        next unless defined ($mod);

        my $widget = $mod->widget($name);
        next unless defined ($widget);

        # Find the dashboard with less items and add the widget to it
        my $minValue = INT_MAX;
        my $minIndex = 0;
        for my $i (1 .. $NUM_DASHBOARDS) {
            my $size_i = 0;
            foreach my $element (@{$dashboards[$i - 1]}) {
                if ((exists $element->{size}) and $element->{size}) {
                    # size attr are quoted to avoid problems with js
                    my $size = $element->{size};
                    $size =~ tr/'"//d;
                    $size_i += $size;
                }
            }
            if ($size_i < $minValue) {
                $minValue = $size_i;
                $minIndex = $i - 1;
            }
        }
        push (@{$dashboards[$minIndex]}, $widget);
    }

    my @params;
    for my $i (1 .. $NUM_DASHBOARDS) {
        #save the current state
        my @dash_widgets = map { $_->{'module'} . ":" . $_->{'name'} } @{$dashboards[$i-1]};
        $sysinfo->setDashboard("dashboard$i", \@dash_widgets);

        push(@params, "dashboard$i" => \@{$dashboards[$i-1]});
    }
    push(@params, 'toggled' => $sysinfo->toggledElements());

    push(@params, 'brokenPackages' => $global->brokenPackages());
    if (EBox::Global->modExists('software')) {
        push(@params, 'softwareInstalled' => 1);
    }

    if (EBox::Global->communityEdition()) {
        my $upgradeMsgData = $self->_upgradeMessage();
        push (@params, 'upgradeMsg' => $upgradeMsgData);

        my $state = $sysinfo->get_state();
        my $lastTime = $state->{lastMessageTime};
        my $currentTime = time();
        my $offset = ($currentTime - $lastTime) / 60 / 24;
        foreach my $msg (@{_periodicMessages()}) {
            my $name = $msg->{name};
            next if ($state->{closedMessages}->{$name});
            my $text = $msg->{text};
            if ($offset >= $msg->{days}) {
                push (@params, 'message' => $msg);
                last;
            } 
        }
    }
    EBox::info(@params);
    return \@params;
}

sub _periodicMessages
{
    # FIXME: Close the message also when clicking the URL, not only with the close button
    return [
        {
         name => 'trial',
         text => __sx('Are you interested in a commercial Zentyal Server edition? {oh}Get{ch} a FREE 45-day Trial!', 
         oh => '<a href="http://www.zentyal.com/zentyal-server/trial/">', 
         ch => '</a>'),
         days => 7,
        },
        {
         name => 'community',
         text => __sx('Are you a happy Zentyal Server user? Do you want to help the project? Get involved in the {oh}Community{ch}!', 
         oh => '<a href="http://www.zentyal.org">', 
         ch => '</a>'),
         days => 30,
        },
    ];
}

# Method: _upgradeMessage
#
# Returns:
#
#       Returns an array that will be pushed to @params array at masonParameters method
#
sub _upgradeMessage
{
    my ($self) = @_;

    my ($curMajor, $curMinor) = split('[\.]',$self->_getCurrentVersion());
    my $newVersion = $self->_getNewVersionFromCloud();
    my ($newMajor, $newMinor) = split('[\.]', $newVersion);
    chomp($newVersion);
    my $RELEASE_ANNOUNCEMENT_URL = "http://wiki.zentyal.org/wiki/Zentyal_".$newVersion."_Announcement";
    my $upgradeAction = "releaseUpgrade('Upgrading to Zentyal ".$newVersion."')";
    my $msg;
    
    if ($curMajor < $newMajor ||
        $curMinor < $newMinor && 
        $curMajor == $newMajor) {
        $msg = { 
                name => 'upgrade', 
                text =>__sx("{oh}Zentyal ".$newVersion."{ch} is available! {ob}Upgrade now{cb}",
                oh => "<a target=\"_blank\" href=\"$RELEASE_ANNOUNCEMENT_URL\">", 
                ch => '</a>',
                ob => "<button style=\"margin-left: 20px; margin-top: -6px; margin-bottom: -6px;\" onclick=\"$upgradeAction\">", 
                cb => '</button>') };
    } else {
        $msg = undef;
    } 

    return $msg;
}

# Method: _getCurrentVersion
#
# Returns:
#
#       Returns an string that contains the current release minor and major version
#
sub _getCurrentVersion
{
    my ($self) = @_;
    my $versionString = EBox::Config::version();

    return $versionString;
}

# Method: _getNewVersionFromCloud
#
# Returns:
#
#       Returns an string that contains the new release minor and major version
#
sub _getNewVersionFromCloud
{
    my ($self) = @_;

    my $version = EBox::Config::version();
    my $newVersionString;
    system("wget --quiet -O /tmp/new-release - http://update.zentyal.org/update-from-'$version'.txt");
    try {
        $newVersionString = $self->_readVersion();
    } catch($ex) {
        EBox::error("Error getting last release update from update.zentyal.com: $ex");
    }

    if ($newVersionString eq "") {
        $newVersionString = $version;
    } 

    return $newVersionString;
}

sub _readVersion
{
    my $version;
    open (my $fh, '/tmp/new-release');
    read ($fh, $version, 16);
    close ($fh);
    system('rm /tmp/new-release');
    return $version;
}

1;