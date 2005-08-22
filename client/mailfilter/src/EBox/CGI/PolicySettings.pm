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

package EBox::CGI::MailFilter::PolicySettings;

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
	$self->{redirect} = "MailFilter/Index?menu=policy";
	$self->{domain} = "ebox-mailfilter";	
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $mfilter = EBox::Global->modInstance('mailfilter');

	$self->_requireParam('viruspolicy', __('viruspolicy'));
	my $viruspolicy = $self->param('viruspolicy');
	$self->_requireParam('spampolicy', __('spampolicy'));
	my $spampolicy = $self->param('spampolicy');
	$self->_requireParam('bheadpolicy', __('bheadpolicy'));
	my $bheadpolicy = $self->param('bheadpolicy');
	$self->_requireParam('bannedpolicy', __('bannedpolicy'));
	my $bannedpolicy = $self->param('bannedpolicy');

	$mfilter->setFilterPolicy('virus', $viruspolicy);
	$mfilter->setFilterPolicy('spam', $spampolicy);
	$mfilter->setFilterPolicy('bhead', $bheadpolicy);
	$mfilter->setFilterPolicy('banned', $bannedpolicy);
	
}

1;
