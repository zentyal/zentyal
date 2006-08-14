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

package EBox::CGI::FirstTime::Passwd;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Auth;
use EBox::FirstTime;

use constant {
  DEFAULT_PASSWD => 'ebox',
};



sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Set password'),
				      'template' => '/firstTime/passwd.mas',
				      @_);
	bless($self, $class);
	return $self;
}


sub requiredParameters
{
  my ($self) = @_;

  if ($self->param('changePasswd')) {
    return ['changePasswd', 'newpwd1', 'newpwd2'];
  } 
  else {
    return [];
  }
}

sub actuate
{
  my ($self) = @_;

  if (EBox::Auth::checkPassword(DEFAULT_PASSWD)) {
    $self->{error} = __('Default password was already changed');
    $self->{errorchain} = 'FirstTime/Index';
  }
  elsif (EBox::FirstTime::isFirstTime()) {
    if ($self->param('changePasswd')) {
      $self->_changePasswd();
    }
  }
  else {
    $self->{error} = __('EBox was already initialized');
    $self->{errorchain} = 'Summary/Index';
  }


}


sub _changePasswd
{
  my ($self) = @_;
  my $newpwd1 = $self->param('newpwd1');
  my $newpwd2 = $self->param('newpwd2');


    if ($newpwd1 ne $newpwd2) {
      $self->{error} = __('New passwords do not match');
    } 
    else {
      EBox::Auth->setPassword($newpwd1);
      $self->{msg} = __('The password was changed successfully.');
      $self->{redirect} = 'FirstTime/Index';
    }

}

1;
