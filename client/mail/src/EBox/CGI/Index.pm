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

package EBox::CGI::Mail::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Mail'),
				      'template' => 'mail/index.mas',
				      @_);
	$self->{domain} = 'ebox-mail';
	bless($self, $class);
	return $self;
}

sub _objectsToHash # (self, object)
{
   my ($self, $objects) = @_;
   my $objectobj = EBox::Global->modInstance('objects');
   my @ret = ();
   foreach my $obj (@{$objects}) {
      my $item = {};
      $item->{name} = $obj;
      $item->{description} = $objectobj->ObjectDescription($obj);
      push(@ret, $item);
   }
   return \@ret;
}

sub _inService {
	my ($self, $service) = @_;
	my $mail = EBox::Global->modInstance('mail');
	
	my $response = 'no';
	if ($mail->service($service)) {
		$response = 'yes';
	}

	return $response;
}

sub _process($) {
	my $self = shift;
	$self->{title} = __('Mail');
	my $mail = EBox::Global->modInstance('mail');
	my $objects = EBox::Global->modInstance('objects');
	my $menu = $self->param('menu');
	($menu) or $menu = 'services';
		
	my @array = ();
	
	my @deniedobjs = @{$mail->deniedObj};
	my @allowedobjs = @{$mail->allowedObj};
	
	push (@array, 'active'		=> $self->_inService('active'));
	push (@array, 'relay'		=> $mail->relay());
	push (@array, 'maxmsgsize'		=> $mail->getMaxMsgSize());
	push (@array, 'maxmdsize'		=> $mail->getMDDefaultSize());
	push (@array, 'deniedobjs'	=> $self->_objectsToHash(\@deniedobjs));
	push (@array, 'allowedobjs'=> $self->_objectsToHash(\@allowedobjs));
	push (@array, 'menu'		=> $menu);
	push (@array, 'popservice'		=> $self->_inService('pop'));
	push (@array, 'imapservice'		=> $self->_inService('imap'));
	push (@array, 'filterservice'		=> $self->_inService('filter'));
	push (@array, 'saslservice'		=> $self->_inService('sasl'));
	push (@array, 'smtptls'		=> $self->_inService('smtptls'));
	push (@array, 'popssl'		=> $self->_inService('popssl'));
	push (@array, 'imapssl'		=> $self->_inService('imapssl'));
	push (@array, 'fwport'		=> $mail->fwport());
	push (@array, 'ipfilter'		=> $mail->ipfilter());
	push (@array, 'portfilter'		=>  $mail->portfilter());

	$self->{params} = \@array;
}

1;
