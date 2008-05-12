# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::ProgressIndicator::Dummy;
use base 'EBox::ProgressIndicator';

# class: EBox::ProgressIndicator::Dummy 
#
#  dummy progress indicator class. Useful
#  when we want to have a method where the progress indicator is optional, in
#  this case if there isn't progress indicator supplied we can use this

use strict;
use warnings;

sub create
{
  my ($class, %params) = @_;
  my $started = delete $params{started};
  defined $started or $started = 1;

  exists $params{executable} or $params{executable} = '/bin/true';
  exists $params{totalTicks} or $params{totalTicks} = 10000;

  my $self = $class->SUPER::create(%params);
  bless $self, $class;

  if ($started) {
    $self->_setAsStarted();
  }


  return $self;
}


sub runExecutable
{
  my ($self) = @_;
  $self->_setAsStarted();
}

1;
