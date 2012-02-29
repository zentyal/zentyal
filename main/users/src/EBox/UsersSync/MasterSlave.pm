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

# Class: EBox::UsersSync::MasterSlave
#
#   User synchronized from Zentyal to Zentyal, both master and
#   slave
#
package EBox::UsersSync::MasterSlave;

use strict;
use warnings;

use base 'EBox::UsersSync::Base';

# File containing password for master's web service (to register a new slave)
use constant MASTER_PASSWORDS_FILE => EBox::Config::conf() . 'users/master.htaccess';

# Dir containing certificates for this master
use constant SSL_DIR => EBox::Config::conf() . 'ssl/';

# Certificate of the authorized master
use constant MASTER_CERT => '/var/lib/zentyal/conf/users/master.cert';

use EBox::Exceptions::External;
use EBox::Util::Random;
use EBox::Sudo;
use EBox::SOAPClient;
use URI::Escape;
use File::Slurp;
use Error qw(:try);

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(name => 'zentyal');
    bless($self, $class);
    return $self;
}

# Method: confSOAPService
#
#   Configure SOAP service to allow Master and Slave queries
#
sub confSOAPService
{
    my ($self) = @_;

    my $confFile = EBox::Config::conf() . 'users/soap.conf';

    my @params;
    push (@params, passwords_file => MASTER_PASSWORDS_FILE);
    push (@params, cert_file => MASTER_CERT);

    EBox::Module::Base::writeConfFileNoCheck($confFile, 'users/soap.mas', \@params);

    my $apache = EBox::Global->modInstance('apache');
    $apache->addInclude($confFile);
}


# MASTER METHODS


# Method: getCertificate
#
#   Return Master certificate (to be used when connecting to the slave's SOAP)
#
sub getCertificate()
{
    my ($self) = @_;

    return read_file(SSL_DIR . 'ssl.cert');
}

# Method: setupMaster
#
#   Setup master server to allow new slaves connections
#
sub setupMaster
{
    my ($self) = @_;

    my $pass = EBox::Util::Random::generate(15);
    EBox::Sudo::root(
        'rm -f ' . MASTER_PASSWORDS_FILE,
        'htpasswd -bc ' . MASTER_PASSWORDS_FILE . ' slave ' . $pass,
    );

    EBox::debug("$pass");
}


# Method: addSlave
#
#   Register a new slave in this master
#
#
sub addSlave
{
    my ($self, $host, $port) = @_;

    my $users = EBox::Global->modInstance('users');
    my $table = $users->model('Slaves');

    $table->addRow(host => $host, port => $port);
}


sub soapClient
{
    my ($self, $slave) = @_;

    my $hostname = $slave->{'hostname'};
    my $port = $slave->{'port'};

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

# SLAVE METHODS

# Method: checkMaster
#
#   Checks connection to a given master's SOAP
#
# Parameters:
#
#   host - master hostname or ip
#   port - master administration port
#   password - password for slave connection
#
# Returns 1 if could connect and SOAP replied, 0 otherwise
#
sub checkMaster
{
    my ($self, $host, $port, $password) = @_;

    my $apache = EBox::Global->modInstance('apache');
    $password = uri_escape($password);
    local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
    my $master = EBox::SOAPClient->instance(
        name  => 'urn:Users/Master',
        proxy => "https://slave:$password\@$host:$port/master",
    );

    $master->getCertificate();
    return 0;
}


# Method: isSlave
#
#   Return 1 if already configured as slave
#
sub isSlave
{
    my ($self) = @_;

    return (-f MASTER_CERT);
}

# Method: setupSlave
#
#   Configure users module as slave of a given master host
#
sub setupSlave
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    my $master = $users->model('Master');

    if ($master->enabledValue()) {
        # return if already configured
        return if ($self->isSlave());

        my $host = $master->hostValue();
        my $port = $master->portValue();
        my $password = $master->passwordValue();

        my $apache = EBox::Global->modInstance('apache');
        $password = uri_escape($password);
        local $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
        my $client = EBox::SOAPClient->instance(
                name  => 'urn:Users/Master',
                proxy => "https://slave:$password\@$host:$port/master",
                );

        # get master's certificate
        my $cert = $client->getCertificate();
        write_file(MASTER_CERT, $cert);


        try {
        # XXX 1 is dummy to fight SOAPClient's problem with even parameter list size
            $client->registerSlave('localhost', $apache->port, 1);
        } otherwise {
            my $ex = shift;
            EBox::debug($ex->text());
            throw EBox::Exceptions::External(__("Couldn't configure Zentyal as slave: ") . $ex->text());
        }
    }
    else {
        # return if already disabled
        return unless ($self->isSlave());

        # disable master access
        unlink (MASTER_CERT);
    }
}


1;
