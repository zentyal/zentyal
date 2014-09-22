# Copyright (C) 2010-2014 Zentyal S.L.
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

package EBox::RemoteServices::Subscription::Validate;

# Class: EBox::RemoteServices::Subscription::Validate
#
#      Validate the data input by the user required by subscription
#

use EBox::Gettext;
use EBox::Validate;
use EBox::Exceptions::InvalidData;

# Constants
use constant {
    MAX_LENGTH => 32,
};

# Function: validateServerName
#
#     Validate the given server name is valid.
#
#     Checks:
#
#       - this does not contain underscores neither dots
#       - the server name length is lower than 32
#
# Parameters:
#
#     serverName - String the server name to validate
#
# Returns:
#
#     Boolean - true if it passes the validation
#
# Exceptions:
#
#     <EBox::Exceptions::InvalidData> - thrown if the validation does
#     not pass, including the advice in the exception
#
sub validateServerName
{
    my ($serverName) = @_;

    my $advice = '';
    # Check if this does not contain underscores neither dots
    if ($serverName !~ m/^[A-Za-z0-9\-]+$/) {
        $advice = __('It must be a valid subdomain name. '
                     . 'It can only contain alphanumeric and - characters');
    } elsif ( length($serverName) >= MAX_LENGTH ) {
        $advice = __x('It cannot be greater than {n} characters',
                      n => MAX_LENGTH);
    } elsif (not EBox::Validate::checkDomainName($serverName)) {
        $advice = __x('It must be a valid domain name');
    }

    if ($advice) {
        throw EBox::Exceptions::InvalidData(data   => __('server name'),
                                            value  => $serverName,
                                            advice => $advice);
    }

}

1;
