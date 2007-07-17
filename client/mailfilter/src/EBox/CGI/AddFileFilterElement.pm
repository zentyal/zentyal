# Copyright (C) 2007 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::MailFilter::AddFileFilterElement;

use strict;
use warnings;

use base 'EBox::CGI::MailFilter::FileFilterBase';

use EBox::Global;
use EBox::Gettext;

sub new 
{
  my $class = shift;
  my $self = $class->SUPER::new('title'    => __('Mail filter'),
				@_);

  $self->{domain} = 'ebox-mailfilter';

  $self->setRedirect("MailFilter/Index");

  bless($self, $class);
  return $self;
}

sub requiredParameters
{
  return ['name', 'deny', 'type'];
}


sub optionalParameters
{
  return ['add'];
}


sub actuate 
{
  my ($self) = @_;

  my $name  = $self->param('name');
  my $allow = not ($self->param('deny'));
  my $type  = $self->param('type');

  $self->_setChain($type);

  my $acl = $self->_acl($type);

  if (exists $acl->{$name}) {
     $self->setError(
	__x("{name} is already registered", name => $name)
				    );
     return;
  }


  $self->_setAclElement($type, $name, $allow);

  my $msg = __x('{name} added', name => $name);
  $self->setMsg($msg);
}




1;
