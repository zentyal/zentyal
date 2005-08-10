# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Summary::Status;

use strict;
use warnings;

use base 'EBox::Summary::Item';
use EBox::Gettext;

sub new  # (key, value)
{
	my $class = shift;
	my $self = $class->SUPER::new();
	$self->{module} = shift;
	$self->{title} = shift;
	$self->{status} = shift;
	$self->{enabled} = shift;
	$self->{nobutton} = shift;
	bless($self, $class);
	return $self;
}

sub html($) 
{
	my $self = shift;
	my $domain = settextdomain('ebox');
	my $status_str;
	my $status_class;
	my $mod = $self->{module};
	my $restart = __('Restart');

	if ($self->{status}) {
		$status_str = __('Running');
		$status_class = 'summaryRunning';
	} elsif ($self->{enabled}) {
		$status_str = __('Stopped');
		$status_class = 'summaryStopped';
		$restart = __('Start');
	} else {
		$status_str = __('Disabled');
		$status_class = 'summaryDisabled';
	}

	print "<form action='/ebox/EBox/RestartService'>\n";
	print "<tr>\n";
	print "<td class='summaryKey'>\n";
	print $self->{title};
	print "\n</td>\n";
	print "<td class='summaryValue'>\n";
	print "<span class='sleft'>\n";
	print $status_str;
	print "</span>\n";
	if (($self->{status} or $self->{enabled}) and not(defined($self->{nobutton}))) {
		print "<input type='hidden' name='module' value='$mod'/>\n";
		print "<span class='sright'>\n";
		print "<input class='inputButtonRestart' type='submit' name='restart' value='$restart'/>\n";
		print "</span>\n";
	}
	print "</td>\n";
	print "</tr>\n";
	print "</form>\n";
	settextdomain($domain);
}

1;
