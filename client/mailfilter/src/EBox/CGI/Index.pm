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

package EBox::CGI::MailFilter::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Mail filter'),
				      'template' => 'mailfilter/index.mas',
				      @_);
	$self->{domain} = 'ebox-mailfilter';
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	$self->{title} = __('Mail filter');
	my $mfilter = EBox::Global->modInstance('mailfilter');
		
	my @array = ();
	
	my $menu = $self->param('menu');
	($menu) or $menu = 'general';

	my %general = (
		'active' => ($mfilter->service() ? 'yes' : 'no'),
		'modulemode' =>  ($mfilter->moduleMode() ? 'yes' : 'no'),
		'bayes' => ($mfilter->bayes() ? 'yes' : 'no'),
		'autolearn' => ($mfilter->autolearn() ? 'yes' : 'no'),
		'autospamhits' => $mfilter->autoSpamHits(),
		'autohamhits' => $mfilter->autoHamHits(),
		'subjectmod' => ($mfilter->subjectModification() ? 'yes' : 'no'),
		'subjectstr' => $mfilter->subjectString(),
		'updatevirus' => ($mfilter->updateVirus() ? 'yes' : 'no'),
	);

	my %policy = (
		'viruspolicy' => $mfilter->filterPolicy('virus'),
		'spampolicy' => $mfilter->filterPolicy('spam'),
		'bheadpolicy' => $mfilter->filterPolicy('bhead'),
		'bannedpolicy' => $mfilter->filterPolicy('banned'),
		'hitspolicy' => $mfilter->hitsThrowPolicy(),
	);
	
	push (@array, 'menu' => $menu);
	push (@array, 'general' => \%general);
	push (@array, 'policy' => \%policy);

	$self->{params} = \@array;
}

1;
