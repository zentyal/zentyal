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

package EBox::CGI::Mail::ModifyVDomain;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Mail;

## arguments:
## 	title [required]
sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Mail', @_);
	$self->{domain} = "ebox-mail";	
	bless($self, $class);
	return $self;
}

sub _warn {
	my ($self, $mdsize, $vdomain, $forceold, @users) = @_;

	$self->{template} = 'mail/warnvdmdsize.mas';
	$self->{redirect} = undef;
	
	my @array = ();
	push(@array, 'vdomain' => $vdomain);
	push(@array, 'mdsize' => $mdsize);
	push(@array, 'forceold' => $forceold);
	push(@array, 'users' => \@users);
	$self->{params} = \@array;

	return 1;
}

sub _process($) {
	my $self = shift;
	my $mail = EBox::Global->modInstance('mail');
 
	$self->_requireParam('vdomain', __('vdomain'));
	$self->_requireParam('mdsize', __('mdsize'));
	
	$self->{redirect} = "Mail/VDomains";	

	my $vdomain = $self->param('vdomain');
	my $mdsize = $self->param('mdsize');
	my $oldmdsize = $mail->{vdomains}->getMDSize($vdomain);
	my $forceold = $self->param('forceold');
	my $modify = undef;

	my @users = @{$mail->{musers}->checkUserMDSize($vdomain, $mdsize)};
	foreach (@users) {
	}
	if ((@users > 0) and ($forceold)) {
		if($self->param('cancel')) {
			$self->{redirect} = "Mail/VDomains";	
		} elsif ($self->param('force')) {
			$modify = 1;
		} else {
			$modify = not $self->_warn($mdsize, $vdomain, $forceold, @users);
		}
	} else {
		$modify = 1;
	}

	if($modify) {
		$mail->{vdomains}->setMDSize($vdomain, $mdsize);
		if ($forceold) {
			$mail->{vdomains}->updateMDSizes($vdomain, $mdsize);
		}
	}
}

1;
