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

use strict;
use warnings;

# Class: EBox::UsersAndGroups::Model::Master
#
#   From to configure a Zentyal master to provide users to this server

package EBox::UsersAndGroups::Model::Master;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Host;
use EBox::Types::Port;
use EBox::Types::Boolean;
use EBox::Types::Password;
use EBox::Exceptions::DataInUse;
use EBox::View::Customizer;

use Net::DNS;

use constant VIEW_CUSTOMIZER => {
    none     => { hide => [ 'host', 'port', 'password' ] },
    zentyal  => { show => [ 'host', 'port', 'password' ] },
    cloud    => { hide => [ 'host', 'port', 'password' ] },
};

# Group: Public methods

# Constructor: new
#
#      Create a data form
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless( $self, $class );

    return $self;
}

# Method: _table
#
#	Overrides <EBox::Model::DataForm::_table to change its name
#
sub _table
{

    my ($self) = @_;

    # TODO make all this elements non-editable after change
    # (add a destroy button, to unregister from the master)


    my $master_options = [
        { value => 'none', printableValue => __('None') },
        { value => 'zentyal', printableValue => __('Other Zentyal Server') },

    ];

    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        if ($rs->usersSyncAvailable()) {
            push ($master_options,
                { value => 'cloud', printableValue  => __('Zentyal Cloud') }
            );
        }
    }

    my @tableDesc = (
        new EBox::Types::Select (
            fieldName => 'master',
            printableName => __('Sync users from'),
            options => $master_options,
            help => __('Sync users from the chosen source'),
            editable => 1,
        ),
        new EBox::Types::Host (
            fieldName => 'host',
            printableName => __('Master host'),
            editable => \&_unlocked,
            help => __('Hostname or IP of the master'),
        ),
        new EBox::Types::Port (
            fieldName => 'port',
            printableName => __('Master port'),
            defaultValue => 443,
            editable => \&_unlocked,
            help => __('Master port for Zentyal Administration (default: 443)'),
        ),
        new EBox::Types::Password (
            fieldName => 'password',
            printableName => __('Slave password'),
            editable => \&_unlocked,
            hidden => \&_locked,
            help => __('Password for new slave connection'),
        ),
    );

    my $dataForm = {
        tableName           => 'Master',
        printableTableName  => __('Sync users from a master server'),
        defaultActions      => [ 'editField', 'changeView' ],
        tableDescription    => \@tableDesc,
        modelDomain         => 'Users',
        help                => __('Configure this parameters to synchronize users from a master server'),
    };

    return $dataForm;
}

# Method: viewCustomizer
#
#    Hide/show master options if Zentyal as master is configured
#
# Overrides:
#
#    <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);
    $customizer->setOnChangeActions( { master => VIEW_CUSTOMIZER } );
    return $customizer;
}



sub _locked
{
    my $users = EBox::Global->modInstance('users');
    my $master = $users->get_hash('Master/keys/form');
    return (defined($master) and $master->{master} eq 'zentyal');
}

sub _unlocked
{
    return (not _locked());
}

sub validateTypedRow
{
    my ($self, $action, $changedParams, $allParams, $force) = @_;


    my $master = exists $allParams->{master} ?
                        $allParams->{master}->value() :
                        $changedParams->{master}->value();

    my $enabled = ($master ne 'none');

    # do not check if disabled
    return unless ($enabled);

    my $users = EBox::Global->modInstance('users');

    # will the operation destroy current users?
    my $destroy = 1;

    if ($master eq 'zentyal') {
        # Check master is accesible
        my $host = exists $allParams->{host} ?
                          $allParams->{host}->value() :
                          $changedParams->{host}->value();

        my $port = exists $allParams->{port} ?
                          $allParams->{port}->value() :
                          $changedParams->{port}->value();

        my $password = exists $allParams->{password} ?
                              $allParams->{password}->value() :
                              $changedParams->{password}->value();

        $users->masterConf->checkMaster($host, $port, $password);

        # If the user has entered an IP address, check that we can reverse
        # resolve it to a name to point the kerberos-master and kpasswd
        # DNS records to it
        my $krbDomain = undef;
        my $krbMaster = undef;
        if (EBox::Validate::checkIP($host)) {
            my $resolver = new Net::DNS::Resolver();
            my $targetIP = join ('.', reverse split (/\./, $host)) . '.in-addr.arpa';
            my $query = $resolver->query($targetIP, 'PTR');
            if ($query) {
                foreach my $rr ($query->answer()) {
                    next unless $rr->type() eq 'PTR';
                    if (defined $krbMaster) {
                        throw EBox::Exceptions::External(
                            __x('Zentyal has tried to reverse resolve the {x} IP address and ' .
                                'multiple host names have been found. Please correct your DNS ' .
                                'setup before proceed.', x => $host));
                    }
                    $krbMaster = $rr->rdatastr();
                    $krbMaster =~ s/\.$//;
                }
            }
        } else {
            $krbMaster = $host;
        }
        unless (defined $krbMaster) {
            throw EBox::Exceptions::External(
                    __x('Could not determine master host FQDN from its IP address ({x}). ' .
                        'This is necessary because the kerberos DNS records must point to ' .
                        'the master on a slave server. Please correct your DNS setup before ' .
                        'proceed.', x => $host));
        }
        ($krbMaster, $krbDomain) = split (/\./, $krbMaster, 2);
        unless (defined $krbDomain) {
            throw EBox::Exceptions::External(
                    __x('Could not determine the master host domain name from the name {x}. ' .
                        'This is necessary because the kerberos DNS records must point to ' .
                        'the master on a slave server. Please check the specified master host ' .
                        'and your DNS setup before proceed.', x => $krbMaster));
        }

        # Check local DNS setup
        $self->checkLocalDNS($krbMaster, $krbDomain);
    }

    if ($master eq 'cloud') {
        my $rs = new EBox::Global->modInstance('remoteservices');
        my $rest = $rs->REST();
        my $res = $rest->GET("/v1/users/realm/")->data();
        my $realm = $res->{realm};

        # If cloud is already provisoned destroy local users before sync
        $destroy = 0 if (not $realm);

        if ($realm and ($users->kerberosRealm() ne $realm)) {
            throw EBox::Exceptions::External(__x('Master server has a different REALM, check hostnames. Master is {master} and this server {slave}.',
                master => $realm,
                slave => $users->kerberosRealm()
            ));
        }
    }

    unless ($force) {
        my $nUsers = scalar @{$users->users()};
        if ($nUsers > 0 and $destroy) {
            throw EBox::Exceptions::DataInUse(__('CAUTION: this will delete all defined users and import master ones.'));
        }
    }

    # set apache as changed
    my $apache = EBox::Global->modInstance('apache');
    $apache->setAsChanged();
}

# Method: checkLocalDNS
#
#   This method checks that the local DNS module has the master hostname
#   and all its IP addresses present
#
sub checkLocalDNS
{
    my ($self, $krbMaster, $krbDomain) = @_;

    my $masterFQDN = "$krbMaster.$krbDomain";
    my @masterIpAddresses;

    # First, retrieve the all IPs of the master host
    my $resolver = new Net::DNS::Resolver();
    my $query = $resolver->search($masterFQDN);
    if ($query) {
        foreach my $rr ($query->answer()) {
            next unless $rr->type() eq 'A';
            push (@masterIpAddresses, $rr->address());
        }
    }
    unless (scalar @masterIpAddresses > 0) {
        throw EBox::Exceptions::External(
            __x('Could not resolve the name {x} to its IP addresses. Check your ' .
                'DNS setup before proceed.', x => $masterFQDN));
    }

    my $dnsModule = EBox::Global->modInstance('dns');
    my $domainModel = $dnsModule->model('DomainTable');
    my $domainRow = $domainModel->find(domain => $krbDomain);
    unless (defined $domainRow) {
        throw EBox::Exceptions::External(
            __x('The determined master host domain {x} could not be found in the ' .
                'local DNS module. Check your local DNS setup before proceed.', x => $krbDomain));
    }
    my $hostModel = $domainRow->subModel('hostnames');
    my $hostRow = $hostModel->find(hostname => $krbMaster);
    unless (defined $hostRow) {
        throw EBox::Exceptions::External(
            __x('The host name {x} specified as the master host could not be found ' .
                'in the DNS domain {y}. Please add it together with its ' .
                'IP addresses ({z}) before proceed.', x => $krbMaster, y => $krbDomain,
                z => join (',', @masterIpAddresses)));
    }

    my $ipModel = $hostRow->subModel('ipAddresses');
    my @addedIpAddresses;
    foreach my $ip (@masterIpAddresses) {
        my $row = $ipModel->find(ip => $ip);
        unless (defined $row) {
            throw EBox::Exceptions::External(
                __x('The master host IP address {x} is not assigned in the DNS module. ' .
                    'Ensure all master host IP addresses ({y}) are assigned before proceed. ',
                    x => $ip, y => join (',', @masterIpAddresses)));
        }
    }
}

1;
