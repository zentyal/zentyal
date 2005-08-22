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

package EBox::CGI::Mail::DelVDomain;

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
	$self->{redirect} = "Mail/VDomains";	
	bless($self, $class);
	return $self;
}

sub _warn {
	my ($self, $vdomain) = @_;

	$self->{template} = 'mail/warnvd.mas';
	$self->{redirect} = undef;

	my $str = 'Remove a virtual domain will cause that all mail accounts and'.
'mail alias accounts that belong to the virtual domain will also be removed.';

	my @array = ();
	push(@array, 'vdomain' => $vdomain);
	push(@array, 'data' => $str);
	$self->{params} = \@array;

   my $mail = EBox::Global->modInstance('mail');
   my $warns = $mail->{'vdomains'}->allWarnings($vdomain);

   if (@{$warns}) { # If any module wants to warn
       $self->{template} = 'mail/warnvd.mas';
       $self->{redirect} = undef;
       my @array = ();
       push(@array, 'vdomain'   => $vdomain);
       push(@array, 'data'   => $warns);
       $self->{params} = \@array;
   }

	return 1;
}

sub _process($) {
	my $self = shift;
	my $mail = EBox::Global->modInstance('mail');
	my $delvd;
 
	$self->_requireParam('vdomain', __('vdomain'));
	
	my $vdomain = $self->param('vdomain');

	if($self->param('cancel')) {
		$self->{redirect} = "Mail/VDomains";
	} elsif ($self->param('delvdforce')) {
		$delvd = 1;
	} else {
		$delvd = not $self->_warn($vdomain);
	}

	if ($delvd) {
		$mail->{vdomains}->delVDomain($vdomain);
	}
}

1;
