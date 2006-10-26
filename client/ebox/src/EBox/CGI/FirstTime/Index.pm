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

package EBox::CGI::FirstTime::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::FirstTime;
use EBox::Global;

sub new # (error=?, msg=?, cgi=?)
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => __('Welcome to eBox'),
				      'template' => 'firstTime/index.mas',
				      @_);
	bless($self, $class);
	return $self;
}


sub optionalParameters
{
  return ['skipAll', 'msg'];
}

sub actuate
{
  my ($self) = @_;

  if ($self->param('msg')) {
    $self->setMsg($self->param('msg'));
  }


  if ($self->param('skipAll')) {
    $self->finishConfiguration();
  }
  elsif (EBox::FirstTime::isFirstTime()) {

    my @tasks = EBox::FirstTime::tasks();

    my $uncompletedTasks = grep { ! $_->{completed} } @tasks;
    if ($uncompletedTasks == 0) {
      $self->finishConfiguration();
    }
    else {
	$self->{tasks} = \@tasks;
    }
  }
  else {
    $self->{error} = __('EBox was already initialized');
    $self->{redirect} = "Summary/Index";
  }

}


sub masonParameters
{
    my ($self) = @_;

    return [] if exists $self->{redirect};
    return  [tasks =>  $self->{tasks}];    
}


sub finishConfiguration
{
  my ($self) = @_;

  EBox::FirstTime::removeFirstTimeMark();

  my $global = EBox::Global->getInstance();
  $global->saveAllModules();

  $self->{redirect} = "Summary/Index";
}

1;
