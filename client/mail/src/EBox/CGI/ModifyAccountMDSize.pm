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

package EBox::CGI::Mail::ModifyAccountMDSize;

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
	my ($self, $mdsize, $username) = @_;

	$self->{template} = 'mail/warnusermdsize.mas';
	$self->{redirect} = undef;

	my @array = ();
	push(@array, 'username' => $username);
	push(@array, 'mdsize' => $mdsize);
	$self->{params} = \@array;

	return 1;
}

sub _process($) {
	my $self = shift;
	my $mail = EBox::Global->modInstance('mail');
 
	$self->_requireParam('username', __('username'));
	my $username = $self->param('username');
	$self->{redirect} = "UsersAndGroups/User?username=$username";
	
	$self->_requireParam('mdsize', __('mdsize'));
	my $mdsize = $self->param('mdsize');
	my $oldmdsize = ($mail->{musers}->getUserLdapValue($username,
		'userMaildirSize')) / $mail->BYTES;
	my $modify = undef;

	if ($mdsize < $oldmdsize) {
		if($self->param('cancel')) {
			$self->{redirect} = "UsersAndGroups/User?username=$username";
		} elsif ($self->param('force')) {
			$modify = 1;
		} else {
			$modify = not $self->_warn($mdsize, $username);
		}
	} else {
		$modify = 1;
	}
	
	$self->keepParam('username');
	
	if ($modify) {
		$mail->{musers}->setMDSize($username, $mdsize);
	}
}

1;
