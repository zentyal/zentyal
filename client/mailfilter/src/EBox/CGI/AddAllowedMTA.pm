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

package EBox::CGI::MailFilter::AddAllowedMTA;

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
  
  $self->setChain("MailFilter/Index");	
  $self->{domain} = "ebox-mailfilter";	
  
  bless($self, $class);
  
  return $self;
}


sub requiredParameters
{
  return ['mta'];
}


sub optionalParameters
{
  return ['add'];
}


sub actuate {
  my ($self) = @_;
  my $mailfilter= EBox::Global->modInstance('mailfilter');
  
  my $mta  = $self->param('mta');

  $mailfilter->addAllowedExternalMTA( $mta );
  
  $self->setMsg(__x(
		    'External mail server {mta} allowed.' . 
		    ' Remember to add his mail domains to the external mail domains list',
		    mta => $mta,
		   )
	       );
}

1;
