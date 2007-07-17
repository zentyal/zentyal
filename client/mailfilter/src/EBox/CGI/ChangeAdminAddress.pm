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

package EBox::CGI::MailFilter::ChangeAdminAddress;

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
  
  $self->setRedirect("MailFilter/Index");	
  $self->{domain} = "ebox-mailfilter";	
  
  bless($self, $class);
  
  return $self;
}


sub requiredParameters
{
  my ($self) = @_;

  if ($self->param('adminAddressActive')) {
    return ['adminAddressActive', 'adminAddress'];  
  }
  else {
    return ['adminAddressActive'];
  }
}

sub optionalParameters
{
  return ['change'];
}

sub actuate {
  my ($self) = @_;

  my $adminAddressActive = $self->param('adminAddressActive');
  my $adminAddress       = $self->param('adminAddress');
 

  my $mfilter= EBox::Global->modInstance('mailfilter');
  my $actualAdminAddress = $mfilter->adminAddress();

  if ($adminAddressActive) {
    if ((not $actualAdminAddress) or ($adminAddress ne $actualAdminAddress)) {
      $mfilter->setAdminAddress($adminAddress);
    }
    
  }
  else {
    if ($actualAdminAddress) {
      $mfilter->setAdminAddress(undef);
    }
  }
  

}

1;
