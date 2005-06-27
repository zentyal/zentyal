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

package EBox::CGI::NTP::Datetime;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('NTP'),
				      'template' => 'ntp/datetime.mas',
				      @_);
	$self->{domain} = "ebox-ntp";	
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	$self->{title} = __('NTP');
	my $ntp = EBox::Global->modInstance('ntp');
	
	my @array = ();
	my $synchronized = 'no';
	
	if ($ntp->synchronized()) {
		$synchronized = 'yes';
	}
	
	my $day;
	my $month;
	my $year;
	my $hour;
	my $minute;
	my $second;
	
	($second,$minute,$hour,$day,$month,$year) = localtime(time);

	$day = sprintf ("%02d", $day);
	$month = sprintf ("%02d", ++$month);
	$year = sprintf ("%04d", ($year+1900));
	$hour = sprintf ("%02d", $hour);
	$minute= sprintf ("%02d", $minute);
	$second = sprintf ("%02d", $second);

	my @date = ($day,$month,$year,$hour,$minute,$second);
	my @servers = $ntp->servers;
	
	push (@array, 'synchronized'		=> $synchronized);
	push (@array, 'servers'		=> \@servers);
	push (@array, 'date'			=> \@date);
	$self->{params} = \@array;

}

1;
