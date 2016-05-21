# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::Exceptions::Protocol;

use base 'EBox::Exceptions::Base';

# Class: EBox::Exceptions::Protocol
#
#     An exception launched when the TCP/IP protocol has failed in
#     some way. For instance, a connection cannot be made.
#

use EBox::Gettext;

# Group: Public methods

# Constructor: new
#
#      Create <EBox::Exceptions::Protocol> exception object
#
# Parameters:
#
#      statusCode - Integer the status code given
#      text - String the text given by the protocol
#
sub new # (statusCode, text)
  {

      my ($class, $statusCode, $text) = @_;

      local $Error::Depth = defined $Error::Depth ? $Error::Depth + 1 : 1;
      local $Error::Debug = 1;

      $self = $class->SUPER::new(("$statusCode $text"));
      bless ($self, $class);

      $Log::Log4perl::caller_depth++;
      $self->log;
      $Log::Log4perl::caller_depth--;

      return $self;

  }

1;

