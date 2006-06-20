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

package EBox::CGI::Logs::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::Objects;
use Data::Dumper;
use POSIX qw(ceil);

use constant PAGESIZE => 15;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Logs'),
				      'template' => '/logs/index.mas',
				      @_);
	$self->{domain} = 'ebox-logs';
	bless($self, $class);
	return $self;
}

sub _getTime {
	my ($self, $module, $tmpl) = @_;

	foreach my $mod (@{$tmpl}) {
		if ($mod->{'name'} eq $module) {
			return $mod->{'timecol'};
		}
	}

	return undef;
}


sub _actualPage
{
    my ($self, $tpages) = @_;

    my $page = $self->param('page');
    
    unless (defined($self->param('page'))) {
	$page = 0;
    }

    if(defined($self->param('tofirst'))) { 
	$page = 0; 
    }
    if(defined($self->param('toprev'))) { 
	if ($page > 0) { 
	    $page = $page -1; 
	} 
    }
    if(defined($self->param('tonext'))) { 
	if ($page < $tpages) {
	    $page = $page + 1; 
	}
    }
    if(defined($self->param('tolast'))) { 
	$page = $tpages; 
    }

    return $page;
}


sub _encode_filters {
	my ($par) = @_;

	my %encoded = map { $par->{$_} =~ s/'/&#39;/g; $_ => $par->{$_}  } 
			keys %{$par};
	
	return \%encoded;
}

sub _process
{
	my $self = shift;
	my @array;
	
	my $logs = EBox::Global->modInstance('logs');
	my %hret = ();
	my @fromdate = ();
	my @todate = ();
	my $tpages = 0;
	my ($toSec, $toMinute, 
	    $toHour, $toDay, 
	    $toMonth, $toYear, 
	    $toWeekday, $toDayofyear, $tolsDST) = localtime(time());
	my ($fromSec, $fromMinute, 
	    $fromHour, $fromDay, 
	    $fromMonth, $fromYear, 
	    $fromWeekday, $froomDayofyear, $fromlsDST) = localtime(time()-24*3600);

	$toYear += 1900;
	$fromYear += 1900;
	$toMonth += 1;
	$fromMonth += 1;

	my $page;
	
	my $selected = $self->param('selected');
	my $tableinfo;
	my $hfilters;
	if (defined($selected)) {
		$tableinfo = $logs->getTableInfo($selected);
		my $table = $tableinfo->{'tablename'};
		my $timecol = $tableinfo->{'timecol'};

		$tpages = ceil($logs->totalRecords($table) / PAGESIZE) - 1;
		$page = $self->_actualPage($tpages);

	
		my $fromday = $self->param('fromday');
		my $frommonth = $self->param('frommonth');
		my $fromyear = $self->param('fromyear');
		my $fromhour = $self->param('fromhour');
		my $frommin = $self->param('frommin');
		my $fromsec = $self->param('fromsec');

		my $today = $self->param('today');
		my $tomonth = $self->param('tomonth');
		my $toyear = $self->param('toyear');
		my $tohour = $self->param('tohour');
		my $tomin = $self->param('tomin');
		my $tosec = $self->param('tosec');

		defined($fromday) or $fromday = $fromDay;
		defined($frommonth) or $frommonth = $fromMonth;
		defined($fromyear) or $fromyear = $fromYear;
		defined($frommin) or $frommin = $fromMinute;
		defined($fromhour) or $fromhour = $fromHour;
		defined($fromsec) or $fromsec = $fromSec;

		defined($today) or $today = $toDay;
		defined($tomonth) or $tomonth = $toMonth;
		defined($toyear) or $toyear = $toYear;
		defined($tomin) or $tomin = $toMinute;
		defined($tohour) or $tohour = $toHour;
		defined($tosec) or $tosec = $toSec;

		@fromdate = ($fromday, $frommonth, $fromyear, $fromhour, 
			$frommin, $fromsec);

		@todate = ($today, $tomonth, $toyear, $tohour,
			$tomin, $tosec);
		
		foreach my $filter (grep(s/^filter-//, @{$self->params()})) {
			$hfilters->{$filter} = 
				$self->unsafeParam("filter-$filter");
		}
		
		%hret = %{$logs->search($fromdate[2].'-'.$fromdate[1].'-'.$fromdate[0].' '.$fromdate[3].':'.$fromdate[4].':0',
			$todate[2].'-'.$todate[1].'-'.$todate[0].' '.$todate[3].':'.$todate[4].':0',
			$selected, 
			PAGESIZE,
			$page,
			$timecol,
			$hfilters)};
		
		$tpages = ceil ($hret{'totalret'} / PAGESIZE) -1;
		$page = $self->_actualPage($tpages);
	} 
	else {
		$selected = 'none';
	}

	push(@array, 'logdomains' => $logs->getLogDomains());
	push(@array, 'filters' => _encode_filters($hfilters));
	push(@array, 'tableinfo' => $tableinfo);
	push(@array, 'selected' => $selected);
	push(@array, 'page' => $page);
	push(@array, 'tpages' => $tpages);
	push(@array, 'data' => $hret{'arrayret'});
	push(@array, 'fromdate' => \@fromdate);
	push(@array, 'todate' => \@todate);
	
	$self->{params} = \@array;
}



1;
