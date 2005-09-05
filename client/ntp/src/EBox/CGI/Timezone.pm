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

package EBox::CGI::NTP::Timezone;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Timezone settings'),
				      'template' => 'ntp/timezone.mas',
				      @_);
	$self->{domain} = "ebox-ntp";	
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my @array = ();
	my $ntp = EBox::Global->modInstance('ntp');
	
	my @zonedata = `cat /usr/share/zoneinfo/zone.tab |grep -v '#'|cut -f3|cut -d '/' -f1|sort -u`;
	my %b;
	my @zonea;

	foreach(@zonedata) {
		unless($b{$_}++) {
			push(@zonea,$_);
		}
	}

	my @list = ();
	my %table;

	foreach my $item(@zonea) {
		chomp $item;
		@list = `cat /usr/share/zoneinfo/zone.tab |grep -v '#'|cut -f3|grep \"^$item\"|sed -e 's/$item\\///'| sort -u`;
		
		foreach my $elem(@list) {
			chomp $elem;
			push(@{$table{$item}}, $elem);
		}
	}
	
	my $oldcontinent = $ntp->get_string('continent');
	my $oldcountry = $ntp->get_string('country');

	push (@array, 'zonea'		=> \@zonea);
	push (@array, 'table'		=> \%table);
	push (@array, 'oldcontinent'		=> $oldcontinent);
	push (@array, 'oldcountry'		=> $oldcountry);
	$self->{params} = \@array;

}

1;
