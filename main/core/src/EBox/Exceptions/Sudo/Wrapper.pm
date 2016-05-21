# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::Exceptions::Sudo::Wrapper;

use base 'EBox::Exceptions::Sudo::Base';

# package:
#   this class exists to notify any sudo error which does not relates to the exceutiomn of the actual command (sudoers error, bad command, etc..)

sub new
{
  my $class = shift @_;

  local $Error::Depth = $Error::Depth + 1;
  local $Error::Debug = 1;

  $Log::Log4perl::caller_depth += 1;
  my $self = $class->SUPER::new(@_);
  $Log::Log4perl::caller_depth -= 1;

  bless ($self, $class);

  return $self;
}

1;
