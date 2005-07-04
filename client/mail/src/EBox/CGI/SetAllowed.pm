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

package EBox::CGI::Mail::SetAllowed;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Mail;
use EBox::Gettext;


sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title' => 'Mail',
				      @_);
	$self->{redirect} = "Mail/Index?menu=settings";
	$self->{domain} = 'ebox-mail';
	bless($self, $class);
	return $self;
}

sub trimArray() # (@array)
{
	my $self = shift;
	my @array = @_;
	my @ret = ();
	foreach my $elmnt (@array) {
		defined ($elmnt) or next;
		($elmnt ne '') or next;
		push(@ret, $elmnt);
	}
	return @ret;
}


sub _process($) {
	my $self = shift;
	my $mail = EBox::Global->modInstance('mail');

   my @allowed = @{$mail->allowedObj};
   
	if (defined($self->param('allowedToDenied'))) {	
		my @remove = $self->trimArray($self->param('allowed'));
		(@remove < 1) and return;
		my @newallowed = ();
		foreach my $obj (@allowed) {
			unless (grep(/^$obj$/, @remove)) {
				push(@newallowed, $obj)
			}
		}
		$mail->setAllowedObj(\@newallowed);
	} elsif (defined($self->param('deniedToAllowed'))) {
		my @add = $self->trimArray($self->param('denied'));
      (@add < 1) and return;
      push(@allowed, @add);
      $mail->setAllowedObj(\@allowed);
	}

}


1;
