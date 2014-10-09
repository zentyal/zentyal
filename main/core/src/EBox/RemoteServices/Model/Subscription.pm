# Copyright (C) 2014 Zentyal S. L.
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

package EBox::RemoteServices::Model::Subscription;

# Class: EBox::RemoteServices::Model::Subscription
#
#     Model to perform all operations related to subscription
#

use base 'EBox::Model::Template';

use Sys::Hostname;

# Group: Public methods

# Method: templateName
#
# Overrides:
#
#     <EBox::Model::Template::templateName>
#
sub templateName
{
    return '/remoteservices/index.mas';
}

# Method: templateContext
#
# Overrides:
#
#     <EBox::Model::Template::templateContext>
#
sub templateContext
{
    my ($self) = @_;

    my $rs = $self->parentModule();

    my $hostname = $rs->eBoxCommonName();
    unless (defined($hostname)) {
        $hostname = Sys::Hostname::hostname();
        ($hostname) = split( /\./, $hostname); # Remove the latest part of
                                               # the hostname to make it a
                                               # valid subdomain name
        $hostname =~ s/_//g; # Remove underscores as they are not valid
                             # subdomain values although they are valid hostnames
    }

    return {
        username         => $rs->username(),
        subscriptionInfo => $rs->subscriptionInfo(),
        serverName       => $hostname,
       };
}

1;
