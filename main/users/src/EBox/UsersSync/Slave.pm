# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::UsersSync::Slave;

use strict;
use warnings;


use base 'EBox::UsersAndGroups::Slave';

# Dir containing certificates for this master
use constant SSL_DIR => EBox::Config::conf() . 'ssl/';

use EBox::Exceptions::External;
use EBox::Util::Random;
use EBox::Sudo;
use EBox::SOAPClient;
use EBox::Gettext;
use URI::Escape;
use File::Slurp;
use Error qw(:try);

sub new
{
    my ($class, $host, $port) = @_;
    my $self = $class->SUPER::new(name => "users-$host-$port");
    $self->{host} = $host;
    $self->{port} = $port;
    bless($self, $class);
    return $self;
}


sub _addUser
{
    my ($self, $user, $pass) = @_;
    $self->soapClient->addUser($user, $pass);
    return 0;
}

sub _delUser
{
    my ($self, $user) = @_;
    $self->soapClient->delUser($user->dn());
    return 0;
}

sub _modifyUser
{

}

sub _addGroup
{

}

sub _modifyGroup
{

}

sub _delGroup
{

}



# CLIENT METHODS

sub soapClient
{
    my ($self) = @_;

    my $hostname = $self->{host};
    my $port = $self->{port};

    my $client = EBox::SOAPClient->instance(
        name  => 'urn:Users/Slave',
        proxy => "https://$hostname:$port/slave",
        certs => {
            cert => SSL_DIR . 'ssl.pem',
            private => SSL_DIR . 'ssl.key'
        }
    );
    return $client;
}


1;
