# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::Dashboard::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;
use EBox::Dashboard::Widget;
use EBox::Dashboard::Item;
use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_, title => __('Dashboard'),
                    'template' => '/dashboard/index.mas');
	bless($self, $class);
	return $self;
}

# Method: masonParameters
#
# Overrides:
#
#   <EBox::CGI::Base::masonParameters>
#
sub masonParameters
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance(1);
    my $sysinfo = $global->modInstance('sysinfo');
    my @modNames = @{$global->modNames};
    my $widgets = {};
    foreach my $name (@modNames) {
        my $mod = $global->modInstance($name);
        settextdomain($mod->domain);
        my $wnames = $mod->widgets();
        for my $wname (keys(%{$wnames})) {
            my $widget = $mod->widget($wname);
            defined($widget) or next;
            $widgets->{$name . ':' . $wname} = $widget;
        }
    }

    #put the widgets in the dashboards according to the last configuration
    my @dashboard1 = ();
    for my $wname (@{$sysinfo->getDashboard('dashboard1')}) {
        my $widget = delete $widgets->{$wname};
        if ($widget) {
            push(@dashboard1, $widget);
        }
    }

    my @dashboard2 = ();
    for my $wname (@{$sysinfo->getDashboard('dashboard2')}) {
        my $widget = delete $widgets->{$wname};
        if ($widget) {
            push(@dashboard2, $widget);
        }
    }

    #put the remaining widgets in the dashboards trying to balance them
    foreach my $wname (keys %{$widgets}) {
        if (!$sysinfo->isWidgetKnown($wname)) {
            $sysinfo->addKnownWidget($wname);
            my $widget = delete $widgets->{$wname};
            if ($widget->{'default'}) {
                if (scalar(@dashboard1) <= scalar(@dashboard2)) {
                    push(@dashboard1, $widget);
                } else {
                    push(@dashboard2, $widget);
                }
            }
        }
    }

    #save the current state
    my @dash_widgets1 = map { $_->{'module'} . ":" . $_->{'name'} } @dashboard1;
    $sysinfo->setDashboard('dashboard1', \@dash_widgets1);
    my @dash_widgets2 = map { $_->{'module'} . ":" . $_->{'name'} } @dashboard2;
    $sysinfo->setDashboard('dashboard2', \@dash_widgets2);

    my @params = ();
    push(@params, 'dashboard1' => \@dashboard1);
    push(@params, 'dashboard2' => \@dashboard2);
    push(@params, 'toggled' => $sysinfo->toggledElements());
    return \@params;
}

1;
