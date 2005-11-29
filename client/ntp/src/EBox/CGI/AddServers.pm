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

package EBox::CGI::NTP::AddServers;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw( :all );

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'NTP', @_);
	$self->{redirect} = "NTP/Datetime";	
	$self->{domain} = "ebox-ntp";	
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	my $ntp= EBox::Global->modInstance('ntp');
	
	$self->_requireParam('server1', __('first ntp server'));

	my $s1 = $self->param('server1');
	checkDomainName($s1, __('Primary server'));
	
	my $s2 = $self->param('server2');
	my $s3 = $self->param('server3');
	
	if (defined($s2) and ($s2 ne "")) {
		checkDomainName($s2, __('Secondary server'));
	}
	
	if (defined($s3) and ($s3 ne "")) {
		checkDomainName($s3, __('Tertiary server'));
	}

	$ntp->setServers($s1, $s2, $s3);

}

1;
