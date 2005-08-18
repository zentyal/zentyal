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

package EBox::CGI::MailFilter::GeneralSettings;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'MailFilter', @_);
	$self->{redirect} = "MailFilter/Index";	
	$self->{domain} = "ebox-mailfilter";	
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $mfilter = EBox::Global->modInstance('mailfilter');

	$self->_requireParam('modulemode', __('module mode'));
	$self->_requireParam('bayes', __('bayesian filter status'));
	$self->_requireParam('subjectmod', __('subject rewrite state'));
	
	$self->_requireParam('autospamhits', __('autospamhits'));
	my $autospamhits = $self->param('autospamhits');
	my $subjectstr = $self->unsafeParam('subjectstr');

	$mfilter->setModuleMode(($self->param('modulemode') eq 'yes'));
	$mfilter->setBayes(($self->param('bayes') eq 'yes'));
	$mfilter->setSubjectModification(($self->param('subjectmod') eq 'yes'));

	if ($autospamhits eq 'dnota') {
		$mfilter->setAutolearn(0);
	} else {
		$mfilter->setAutolearn(1);
		$mfilter->setAutoSpamHits($mfilter->probabilityToHits($autospamhits));
	}
	$mfilter->setSubjectString($subjectstr);
	
}

1;
