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

package EBox::CGI::MailFilter::RemoveSenderACL;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::CGI::MailFilter::AddSenderACL;

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
  return ['vdomain'];
}


sub actuate {
  my ($self) = @_;
  my $sender = $self->param('sender');
  my $type   = $self->param('type');

  my $vdomain = $self->param('vdomain');
  if ($vdomain) {
    $self->setRedirect("/Mail/EditVDomain?vdomain=$vdomain&menu=1");
  }

  my $mailfilter= EBox::Global->modInstance('mailfilter');

  my @acl = @{ $self->_getACL($mailfilter, $vdomain, $type) };
  my @aclWithoutSender = grep {  $_ ne $sender } @acl;

  if (@aclWithoutSender == @acl) {
    throw EBox::Exceptions::External(
				    __('The specified sender is not in the ACL')
				    );
  }


  $self->_setACL($mailfilter, $vdomain, $type, \@aclWithoutSender);
}


sub _getACL
{
  return EBox::CGI::MailFilter::AddSenderACL::_getACL(@_);
}


sub _setACL
{
  return EBox::CGI::MailFilter::AddSenderACL::_setACL(@_);
}

1;
