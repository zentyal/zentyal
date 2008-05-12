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

package EBox::CGI::Mail::VDomains;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Mail;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Virtual domains'),
				      'template' => 'mail/vdomains.mas',
				      @_);
	$self->{domain} = 'ebox-mail';
	bless($self, $class);
	return $self;
}

sub _process($) {
	my $self = shift;
	$self->{title} = __('Virtual domains');
	my $mail        = EBox::Global->modInstance('mail');
	
	if ($mail->configured()) {
		my $masonParams = [];
		if ($mail->mdQuotaAvailable()) {
		  $masonParams = $self->_masonParamsWithMDQuota();
		}
		else {
		  $masonParams = $self->_masonParamsWoMDQuota();
		}


		$self->{params} = $masonParams;
	} else {
	        $self->setTemplate('/notConfigured.mas'); 
        	$self->{params} = ['module' => __('Mail')];
	}
}


sub _masonParamsWithMDQuota
{
  my ($self) = @_;

  my $mail = EBox::Global->modInstance('mail');
  
  my @array = ();
  
  my %vdomains = $mail->{vdomains}->vdandmaxsizes();
  
  push(@array, 'mdQuotaAvailable' => 1);
  push(@array, 'mdsize'           => $mail->getMDDefaultSize());
  push(@array,  'vdomains'        => [keys %vdomains]);
  push(@array, 'sizeByVDomain'	  => \%vdomains);

  return \@array;
}



sub _masonParamsWoMDQuota
{
  my ($self) = @_;

  my $mail = EBox::Global->modInstance('mail');
  
  my @array = ();
  
  my @vdomains = $mail->{vdomains}->vdomains();
  
  @array = (vdomains => \@vdomains);

  return \@array;  
}

1;
