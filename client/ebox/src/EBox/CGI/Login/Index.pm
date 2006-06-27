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

package EBox::CGI::Login::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';
use EBox::Gettext;
use Apache;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => '',
				      'template' => '/login/index.mas',
				      @_);
	bless($self, $class);
	return $self;
}

sub _print
{
	my $self = shift;
	print($self->cgi()->header(-charset=>'utf-8'));
	$self->_body;
}

sub _process
{
	my $self = shift;
	my $r = Apache->request;
	my $envre;
	my $authreason;
	
	if ($r->prev){
		$envre = $r->prev->subprocess_env("LoginReason");
		$authreason = $r->prev->subprocess_env('AuthCookieReason');
	}
	
	my $reason;
	if ((defined $authreason) and ($authreason  eq 'bad_credentials')){
		$reason = __('Password Incorrect');	
	}
	elsif ((defined $envre) and ($envre eq 'Expired')){
		$reason = __('For security reasons your session ' .
			     'has expired due to inactivity');
	}elsif ((defined $envre and $envre eq 'Already')){
		$reason = __('You have been logged out because ' . 
			     'a new session has been opened');
	}
	my @array = ();
	push (@array, 'reason' => $reason);
	$self->{params} = \@array;
}

sub _top
{
}

sub _loggedIn 
{
	return 1;
}

sub _menu 
{
	return;
}

1;
