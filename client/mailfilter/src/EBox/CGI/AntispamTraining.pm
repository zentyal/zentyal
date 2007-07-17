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

package EBox::CGI::MailFilter::AntispamTraining;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;




## arguments:
## 	title [required]
sub new 
{
  my $class = shift;
  my $self = $class->SUPER::new('title' => 'Mail filter', @_);
  

  $self->{domain} = "ebox-mailfilter";	
  
  bless($self, $class);
  
  return $self;
}



sub requiredParameters
{
  return [qw(mailbox mailboxType)];
}

sub optionalParameters
{
  return ['train'];
}


sub actuate {
  my ($self) = @_;

  $self->setChain("MailFilter/Index?menu=antispam");	
  $self->cgi->param('menu' => 'antispam');
  $self->keepParam('menu');

  my $mailboxFile = $self->upload('mailbox');
  my $mailboxType = $self->param('mailboxType');

  my $mailfilter= EBox::Global->modInstance('mailfilter');
  my $antispam  = $mailfilter->antispam;
 

  my $isSpam;
  if ($mailboxType eq 'spam') {
    $isSpam = 1;
  }
  elsif ($mailboxType eq 'ham') {
    $isSpam = 0;
  }
  else {
    throw EBox::Exceptions::External( __x(
					  'Invalid mailbox type: {type}',
					  type => $mailboxType,
					)
				    );
  }


  $antispam->learn(
		   isSpam => $isSpam,
		   format => 'mbox',
		   input  => $mailboxFile,
		  );

  $self->setMsg(__('Learned from mailbox file'));
}

1;
