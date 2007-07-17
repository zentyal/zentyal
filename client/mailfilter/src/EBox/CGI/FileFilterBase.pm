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

# package: EBox::CGI::MailFilter::FileFilterBase This package is intended not
#  to be used as CGI but as parent which will be contain some utility methods
package EBox::CGI::MailFilter::FileFilterBase;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;


sub new 
{
  my $class = shift;
  my $self = $class->SUPER::new('title'    => __('Mail filter'),
				@_);

  $self->{domain} = 'ebox-mailfilter';

  $self->setChain("MailFilter/Index");

  bless($self, $class);
  return $self;
}


sub _setChain
{
  my ($self, $type) = @_;


  my $menu = 'fileFilter' . ucfirst $type;
  my $url = 'MailFilter/Index';

  $self->cgi->param('menu', $menu);
  $self->keepParam('menu');

  $self->setChain($url);
  
}


sub _acl
{
  my ($self, $type) = @_;

  my $mailFilter = EBox::Global->modInstance('mailfilter');
  my $fileFilter = $mailFilter->fileFilter;

  my $getterMethod = $type . 's';
  return $fileFilter->$getterMethod;
}

# this only change values; doesn't add or remove elements
sub _setAclValues
{
  my ($self, $type, $acl_r) = @_;

  my %newAcl = %{ $acl_r };
  my %oldAcl = %{ $self->_acl($type)  };

  my $changes = 0;
  while (my ($name, $value) = each %newAcl) {
    if (not exists $oldAcl{$name}) {
      throw EBox::Exceptions::Internal(
	 "Trying to change an inexiste ACL value $name"
				      );
    }
    if ($value != $oldAcl{$name}) {
      $self->_setAclElement($type, $name, $value);
      $changes++;
    }
  }


  return $changes;
}



sub _setAclElement
{
  my ($self, $type, $name, $allow) = @_;

  my $mailFilter = EBox::Global->modInstance('mailfilter');
  my $fileFilter = $mailFilter->fileFilter;

  my $setterMethod = 'set'. ucfirst $type;
  return $fileFilter->$setterMethod($name, $allow);
}


sub _unsetAclElement
{
  my ($self, $type, $name) = @_;

  my $mailFilter = EBox::Global->modInstance('mailfilter');
  my $fileFilter = $mailFilter->fileFilter;

  my $unsetterMethod =  'unset' . ucfirst $type;
  return $fileFilter->$unsetterMethod($name);
}







1;
