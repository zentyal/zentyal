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

package EBox::CGI::MailFilter::AddSenderACL;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

use Perl6::Junction qw(any);

## arguments:
## 	title [required]
sub new 
{
  my $class = shift;
  my $self = $class->SUPER::new('title' => 'Mail filter', @_);
  
  $self->setRedirect("MailFilter/Index?menu=antispam");	
  $self->{domain} = "ebox-mailfilter";	
  
  bless($self, $class);
  
  return $self;
}


sub requiredParameters
{
  return ['sender', 'type'];
}


sub optionalParameters
{
  return ['vdomain', 'add'];
}


sub actuate {
  my ($self) = @_;
  my $vdomain = $self->param('vdomain');
  my $sender = $self->param('sender');
  my $type   = $self->param('type');

  if ($vdomain) {
    $self->setRedirect("/Mail/EditVDomain?vdomain=$vdomain&menu=1");
  }


  my $mailfilter= EBox::Global->modInstance('mailfilter');
 

  my @acl = @{ $self->_getACL($mailfilter, $vdomain, $type) };

  if ($sender eq any @acl) {
    throw EBox::Exceptions::External('Sender is already in the ACL');
  }

  push @acl, $sender;


  $self->_setACL($mailfilter, $vdomain, $type, \@acl);
}


sub _getACL
{
  my ($self, $mailfilter, $vdomain, $type) = @_;
  my $antispam  = $mailfilter->antispam;
  my $aclGetter;

  if ($vdomain) {
    $aclGetter  ="vdomain\u$type";
    return $antispam->$aclGetter($vdomain);
  }
  else {
    $aclGetter  = $type;

    return $antispam->$aclGetter();
  }
}


sub _setACL
{
  my ($self, $mailfilter, $vdomain, $type, $acl) = @_;
  my $antispam  = $mailfilter->antispam;
  my $aclSetter;

  if ($vdomain) {
    $aclSetter = "setVDomain" . ucfirst $type;
    return $antispam->$aclSetter($vdomain, $acl);
  }
  else {
    $aclSetter = "set" . ucfirst $type;
    return $antispam->$aclSetter($acl);
  }
  
}


1;
