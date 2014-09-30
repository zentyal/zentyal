# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::RemoteServices::RESTResource::Auth;
use base 'EBox::RemoteServices::RESTResource';

use EBox::Exceptions::Command;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use TryCatch::Lite;

# Group: Public methods

# Constructor: new
#
#     Create the subscription client object
#
# Parameters:
#
#     - remoteservices (named)
#
sub new
{
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params, requireUserPassword => 1);
    bless $self, $class;
    return $self;
}

# Method: auth
#
#      Check if we are authorised
#
# Returns:
#
#      Hash ref - containing the following keys:
#
#        username - String the username
#        email    - String the email address
#        name     - String the full name
#
#        company - Hash ref containing the following keys: uuid, name
#        and description. (Optional)
#
sub auth
{
    my ($self) = @_;
    my $res = $self->restClientWithUserCredentials()->GET('/v2/auth/');
    return $res->data();
}

1;
