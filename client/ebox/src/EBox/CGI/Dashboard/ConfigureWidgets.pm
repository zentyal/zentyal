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

package EBox::CGI::Dashboard::ConfigureWidgets;

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox::Gettext;
use EBox::Global;
use Error qw(:try);

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new(@_, title => __('Configure widgets'),
                    'template' => '/dashboard/configurewidgets.mas');
	bless($self, $class);
	return $self;
}

sub _process
{
	my ($self) = @_;
	my $global = EBox::Global->getInstance(1);
	my @modNames = @{$global->modNames};
    my $modules = [];
    
    my $present_widgets = {};
	my $sysinfo = $global->modInstance('sysinfo');

    for my $wname (@{$sysinfo->getDashboard('dashboard1')}) {
        $present_widgets->{$wname} = 1;
    }
    for my $wname (@{$sysinfo->getDashboard('dashboard2')}) {
        $present_widgets->{$wname} = 1;
    }

	foreach my $name (@modNames) {
        my $mod = $global->modInstance($name);
        settextdomain($mod->domain);
        my $widgets = $mod->widgets();
        if(%{$widgets}) {
            my $modtitle = $mod->{'printableName'};
            if(not defined($modtitle)) {
                $modtitle = $mod->{'title'};
            }
            my $module = {
                'title' => $modtitle,
                'name' => $mod->{'name'},
                'widgets' => []
            };
            for my $k (sort keys %{$widgets}) {
                my $wid = {'name' => $k, 'title' => $widgets->{$k}->{'title'}};
                $wid->{'present'} = $present_widgets->{$name . ':' . $k};
                push(@{$module->{'widgets'}}, $wid);
            }
            push(@{$modules},$module);
        }
    }

    my @params = ();
    push(@params, 'modules' => $modules);
    $self->{params} = \@params;
}

1;
