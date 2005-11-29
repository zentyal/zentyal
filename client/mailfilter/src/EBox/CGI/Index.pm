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

sub _accounts() {
	my ($self, $list) = @_;

	my $mail = EBox::Global->modInstance('mail');
	my $mfilter = EBox::Global->modInstance('mailfilter');
	my @domain = $mail->{'vdomains'}->vdomains();
	
	my %accounts;
	if (@domain) {
		%accounts = %{$mail->{'musers'}->allAccountsFromVDomain($domain[0])};
	}
	
	my @allacc = values(%accounts);
	my @bypacc = @{$mfilter->accountsBypassList($list)};
	my %tmp = ();
	my @diff = ();

	foreach my $elmt (@bypacc) { $tmp{$elmt} = 1 }

	foreach my $elmt (@allacc) {
		unless ($tmp{$elmt}) { 
			push (@diff, $elmt);
		}
	}

	return \@diff;
}

sub _process($) {
	my $self = shift;
	$self->{title} = __('Mail filter');
	my $mfilter = EBox::Global->modInstance('mailfilter');
	my $mail = EBox::Global->modInstance('mail');
		
	my @array = ();
	
	my $menu = $self->param('menu');
	($menu) or $menu = 'general';

	my $vdnumber = scalar($mail->{'vdomains'}->vdomains());
	my $mode = 'bydomain';
	print STDERR "Numero de dominios = $vdnumber\n";
	if (($mfilter->moduleMode()) or ($vdnumber == 1)){
		$mode = 'global';
	}

	my $autospamvalue = '';
	if ($mfilter->autolearn()) {
		$autospamvalue =  $mfilter->hitsToProbability($mfilter->autoSpamHits());
	} else {
		$autospamvalue = 'dnota';
	}

	my %general = (
		'active' => ($mfilter->service() ? 'yes' : 'no'),
		'modulemode' =>  ($mfilter->moduleMode() ? 'yes' : 'no'),
		'bayes' => ($mfilter->bayes() ? 'yes' : 'no'),
		'autospamhits' => $autospamvalue,
		'subjectmod' => ($mfilter->subjectModification() ? 'yes' : 'no'),
		'subjectstr' => $mfilter->subjectString(),
		'hitspolicy' => $mfilter->hitsToProbability($mfilter->hitsThrowPolicy()),
	);

	my %policy = (
		'viruspolicy' => $mfilter->filterPolicy('virus'),
		'spampolicy' => $mfilter->filterPolicy('spam'),
		'bheadpolicy' => $mfilter->filterPolicy('bhead'),
		'bannedpolicy' => $mfilter->filterPolicy('banned'),
	);
	
	my $list;
	if ($self->param('tlist')) {
		$list = $self->param('tlist');
	} else {
		$list = 'virus';
	}

	my $dom = 'no';
	if ($self->param('domainCheckBox')) {
		$dom = 'yes';
	} else {
		my @l = @{$mfilter->accountsBypassList($list)};
		if (grep(/^@.*/, $l[0])) {
			$dom = 'yes';
		}
	}

	my %restrict = (
		'tlist' => $list,
		'alldomain' => $dom,
		'vlistnr' => $self->_accounts('virus'),
		'vlistr' => $mfilter->accountsBypassList('virus'),
		'slistnr' => $self->_accounts('spam'),
		'slistr' => $mfilter->accountsBypassList('spam'),
		'hlistnr' => $self->_accounts('bhead'),
		'hlistr' => $mfilter->accountsBypassList('bhead'),
		'blistnr' => $self->_accounts('banned'),
		'blistr' => $mfilter->accountsBypassList('banned'),
	);

	my %lists = (
		'whitelist' => $mfilter->whitelist(),
		'blacklist' => $mfilter->blacklist(),
	);
	
	push (@array, 'menu' => $menu);
	push (@array, 'mode' => $mode);
	push (@array, 'general' => \%general);
	push (@array, 'policy' => \%policy);
	push (@array, 'restrict' => \%restrict);
	push (@array, 'lists' => \%lists);

	$self->{params} = \@array;
}

1;
