# Copyright (C) 2004-2007 Warp Networks S.L
# Copyright (C) 2008-2012 Zentyal S.L.
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

package EBox::CGI::SysInfo::General;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox;
use EBox::Global;
use EBox::Gettext;

use Sys::Hostname;
use File::Basename;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('General Configuration'),
                      'template' => '/general.mas',
                      @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;

    # Get hostname
    my $apache = EBox::Global->modInstance('apache');
    my $newHostname = $apache->get_string('hostname');

    # Get current date
    my ($second,$minute,$hour,$day,$month,$year) = localtime(time);
    $day = sprintf ("%02d", $day);
    $month = sprintf ("%02d", ++$month);
    $year = sprintf ("%04d", ($year+1900));
    $hour = sprintf ("%02d", $hour);
    $minute= sprintf ("%02d", $minute);
    $second = sprintf ("%02d", $second);
    my @date = ($day,$month,$year,$hour,$minute,$second);

    # Get timezones table
    my $zoneinfo = '/usr/share/zoneinfo';
    my @zonedata = `cat $zoneinfo/zone.tab |grep -v '#'|cut -f3|cut -d '/' -f1|sort -u`;
    my %b;
    my @zonea;
    foreach (@zonedata) {
        push (@zonea, $_) unless($b{$_}++);
    }
    my @list = ();
    my %table;
    foreach my $item (@zonea) {
        chomp $item;
        @list = `cat $zoneinfo/zone.tab |grep -v '#'|cut -f3|grep \"^$item\"|sed -e 's/$item\\///'| sort -u`;
        foreach my $elem (@list) {
            chomp $elem;
            push (@{$table{$item}}, $elem);
        }
    }
    # Add US and Etc zones
    foreach my $dir ('US', 'Etc') {
        foreach my $file (glob ("$zoneinfo/$dir/*")) {
            push (@{$table{$dir}}, basename($file));
        }
    }

    # Get current timezone
    my $sysinfo = EBox::Global->modInstance('sysinfo');
    my $oldcontinent = $sysinfo->get_string('continent');
    my $oldcountry = $sysinfo->get_string('country');

    my @array = ();
    push (@array, 'port' => $apache->port());
    push (@array, 'lang' => EBox::locale());
    push (@array, 'hostname' => Sys::Hostname::hostname());
    push (@array, 'newHostname' => $newHostname);
    push (@array, 'date' => \@date);
    push (@array, 'table' => \%table);
    push (@array, 'oldcontinent' => $oldcontinent);
    push (@array, 'oldcountry' => $oldcountry);

    $self->{params} = \@array;
}

1;
