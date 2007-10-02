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


# package EBox::CGI::ProgressBase
#
#  This class is to used to show the progress of a long operation 
#
#  This CGI is not intended to be caled directly, any CGI whom wants to switch
#   to a porgress view must inherit from ProgressClient and call to the method showProgress
package EBox::CGI::Progress;

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
  my $self = $class->SUPER::new( 'template' => '/progress.mas',
				 @_);
  
  bless($self, $class);
  return $self;
}



sub _process
{
  my ($self) = @_;

  my @params = ();
  push @params, (progressId     => $self->_progressId);

  my $title = $self->param('title');
  if ($title) {
    $self->{title} = $title;
  }

  my @paramsNames = qw( text currentItemCaption itemsLeftMessage endNote reloadInterval currentItemUrl);
  foreach my $name (@paramsNames) {
    my $value = $self->param($name);
    $value or
      next;

    push @params, ($name => $value);
  }

  $self->{params} = \@params;
}


sub _progressId
{
  my ($self) = @_;
  my $pi = $self->param('progress');

  $pi or
    throw EBox::Exceptions::Internal('No progress indicator id supplied');
  return $pi;
}

1;


