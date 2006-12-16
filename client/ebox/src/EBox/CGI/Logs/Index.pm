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
use POSIX qw(ceil);

use constant PAGESIZE => 15;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Logs'),
				      'template' => '/logs/index.mas',
				      @_);
	$self->{domain} = 'ebox';
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


sub addToMasonParameters
{
    my ($self, @masonParams) = @_;


    defined $self->{params} or $self->{params} = [];
    my $oldParams_r= $self->{params};
    if (defined $oldParams_r) {
	push @masonParams, @{ $oldParams_r };
    }


    
    
    $self->{params}  = \@masonParams;
}


sub _fromDate
{
    my ($self) = @_;
    my $defaultPeriod = -24*3600; # one day
    my $fromDate = $self->_getDateArray('from', $defaultPeriod);

    return $fromDate;
}

sub _toDate
{
    my ($self) = @_;
    my $toDate = $self->_getDateArray('to');

    return $toDate;
}


sub _getDateArray
{
    my ($self, $prefix, $defaultTimeAdjust) = @_;
    defined $defaultTimeAdjust or $defaultTimeAdjust = 0;

    my %time;

    my @localtime = localtime((time() + $defaultTimeAdjust));
    $time{$prefix . 'sec'}   = $localtime[0];
    $time{$prefix . 'min'}   = $localtime[1];
    $time{$prefix . 'hour'}  = $localtime[2];
    $time{$prefix . 'day'}   = $localtime[3];
    $time{$prefix . 'month'} = $localtime[4] + 1;
    $time{$prefix . 'year'}  = $localtime[5]  + 1900;
    
    foreach my $key (keys %time) {
	my $paramValue = $self->param($key);
	if (defined $paramValue) {
	    $time{$key} = $paramValue;
	}
    }

    my @wantedOrder = map { $prefix . $_  }  qw(day month year hour min sec) ;
    my @dateArray = map {  $time{$_} }  @wantedOrder;

    return \@dateArray;
}


sub _searchLogs
{
    my ($self, $logs, $selected) = @_;

    my %hret;
    my $hfilters;
    my $tableinfo = $logs->getTableInfo($selected);
    my $table     = $tableinfo->{'tablename'};
    my $timecol   = $tableinfo->{'timecol'};

    my $tpages = ceil($logs->totalRecords($table) / PAGESIZE) - 1;
    my $page = $self->_actualPage($tpages);
    
    my @fromdate = @{ $self->_fromDate() };
    my @todate   = @{ $self->_toDate() };
    
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

    my @masonParameters;
    push(@masonParameters, 'filters' => _encode_filters($hfilters));
    push(@masonParameters, 'tableinfo' => $tableinfo);

    push(@masonParameters, 'page' => $page);
    push(@masonParameters, 'tpages' => $tpages);
    push(@masonParameters, 'data' => $hret{'arrayret'});
    push(@masonParameters, 'fromdate' => \@fromdate);
    push(@masonParameters, 'todate' => \@todate);
	
    $self->addToMasonParameters(@masonParameters);

}

sub _encode_filters {
	my ($par) = @_;

	my %encoded = map { $par->{$_} =~ s/'/&#39;/g; $_ => $par->{$_}  } 
			keys %{$par};
	
	return \%encoded;
}

sub _process
{
	my ($self) = @_;
	
	my $logs = EBox::Global->modInstance('logs');


	my $selected = $self->param('selected');

	if (defined($selected)) {
	    $self->_searchLogs($logs, $selected);
	} 
	else {
		$selected = 'none';
	}

	my @masonParameters;
	push(@masonParameters, 'logdomains' => $logs->getLogDomains());
	push(@masonParameters, 'selected' => $selected);

	$self->addToMasonParameters(@masonParameters);
}



1;
