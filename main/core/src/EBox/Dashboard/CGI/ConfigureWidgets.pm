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

use strict;
use warnings;

package EBox::Dashboard::CGI::ConfigureWidgets;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use TryCatch;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_, title => __('Configure Widgets'),
                    'template' => '/dashboard/configurewidgets.mas');
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
    my $global = EBox::Global->getInstance(1);
    my @modNames = @{$global->modNames()};
    my $modules = [];

    my $present_widgets = {};
    my $sysinfo = $global->modInstance('sysinfo');

    for my $wname (@{$sysinfo->getDashboard('dashboard1')}) {
        $present_widgets->{$wname} = 1;
    }
    for my $wname (@{$sysinfo->getDashboard('dashboard2')}) {
        $present_widgets->{$wname} = 1;
    }

    unless (defined $widgetsToHide) {
        $widgetsToHide = {
            map { $_ => 1 } split (/,/, EBox::Config::configkey('widgets_to_hide'))
        };
    }

    foreach my $name (@modNames) {
        my $mod = $global->modInstance($name);
        my $widgets = $mod->widgets();
        if (%{$widgets}) {
            my $modtitle = $mod->{'printableName'};
            if (not defined($modtitle)) {
                $modtitle = $mod->{'title'};
            }
            my $module = {
                'title' => $modtitle,
                'name' => $mod->{'name'},
                'widgets' => []
               };
            for my $k (sort keys %{$widgets}) {
                my $fullname = "$name:$k";
                next if exists $widgetsToHide->{$fullname};
                my $wid = {'name' => $k, 'title' => $widgets->{$k}->{'title'}};
                $wid->{'present'} = $present_widgets->{$fullname};
                push(@{$module->{'widgets'}}, $wid);
            }
            push(@{$modules}, $module) if (@{$module->{'widgets'}});
        }
    }

    my @params = ();
    push(@params, 'modules' => $modules);
    return \@params;
}

1;
