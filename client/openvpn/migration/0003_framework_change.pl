#!/usr/bin/perl

#  Migration between gconf data version 1 and 2
#
#   gconf changes: now service is explitted in intrnalService and userService
#   files changes: now log files names have the name of the daemon instead of
#   the iface daemons change: now start and stop of daemons have a new method
#   depending in pid files
use strict;
use warnings;

package EBox::Migration;
use base 'EBox::MigrationBase';

use strict;
use warnings;

use EBox;
use EBox::Global;
use EBox::Config;
use EBox::Sudo;


sub runGConf
{
  my ($self) = @_;

  $self->_removeDeprecatedConfig();
  $self->_migrateServers();
  $self->_migrateClients();
}



sub _removeDeprecatedConfig
{
    my ($self) = @_;
    my $openvpn = $self->{gconfmodule};
    
    my @deprecatedKeys = qw(user group dh openvpn_bin interface_count conf_dir
                            userActive internalActive
                           );
    foreach my $key (@deprecatedKeys) {
        $openvpn->unset($key);
    }
    
}


sub _migrateServers
{
    my ($self) = @_;
    my $openvpn = $self->{gconfmodule};
    foreach my $name (@{ $openvpn->all_dirs_base('server') } ) {
        my $dir = "server/$name";

        # fetch all server config
        my $active = $openvpn->get_bool("$dir/active");
        my $internal  = $openvpn->get_bool("$dir/internal");   

        my $ifaceNumber = $openvpn->get_int("$dir/iface_number");

        # create server row
        my $servers = $openvpn->model('Servers');
        $servers->addRow(
                         name => $name,
                         service => 0,
                         interfaceType => 'tap',
                         interfaceNumber => $ifaceNumber,
                        );

        $self->_setServerConf($name, $dir);
        $self->_setAdvertisedNetworks($name, $dir);
 
        if ($active) {
            # we have the server confiugred so we can change the service value
            my $row = $servers->findRow(name => $name);
            my $service = $row->elementByName('service');
            $service->setValue(1);
            $row->store();
        }

        # done! we delete the server directory
        $openvpn->delete_dir($dir);
    }
}


sub _setServerConf
{
    my ($self, $name, $dir)  =@_;

    my $openvpn = $self->{gconfmodule};

    # fetch configuration attributes
    my $proto       = $openvpn->get_string("$dir/proto");
    my $port = $openvpn->get_int("$dir/port");
    my $portAndProtocol = "$port/$proto";

    my $vpnNet  = $openvpn->get_string("$dir/vpn_net");
    my $vpnNetmask  = $openvpn->get_string("$dir/vpn_netmask");
    my $mask = EBox::NetWrappers::bits_from_mask($vpnNetmask);
    my $vpn = "$vpnNet/$mask";
    
    my $serverCertificate  = $openvpn->get_string("$dir/server_certificate");
    my $tlsRemote          = $openvpn->get_string("$dir/tls_remote");
    defined $tlsRemote or $tlsRemote = 0;
    
    my $pullRoutes  = $openvpn->get_bool("$dir/pull_routes");
    my $ripPasswd   = $openvpn->get_string("$dir/ripPasswd");
    

    my $masquerade  = $openvpn->get_bool("$dir/masquerade");
    my $clientToClient  = $openvpn->get_bool("$dir/client_to_client");

    my $local = $openvpn->get_string("$dir/local");
    if (not $local) {
        $local = '_ALL';
    }

    my $servers = $openvpn->model('Servers');
    my $serverRow = $servers->findRow(name => $name);
    my $configuration    = $serverRow->subModel('configuration');
    # set server configuration model

    my %confToSet   = (
                           portAndProtocol => $portAndProtocol,
                           vpn => $vpn,

                           certificate => $serverCertificate,
                           tlsRemote => $tlsRemote,

                           pullRoutes => $pullRoutes,

                           ripPasswd => $ripPasswd,

                           masquerade => $masquerade,
                           clientToClient => $clientToClient,

                           local          => $local,
                          );


    my $row = $configuration->row();
    while (my ($attr, $value) = each %confToSet) {
        $row->elementByName($attr)->setValue($value);
    }

    $row->store();
}


sub _setAdvertisedNetworks
{
    my ($self, $name, $dir)  =@_;

    my $openvpn = $self->{gconfmodule};


    # fetch advertised networks
    my %advertised = %{ $openvpn->hash_from_dir("$dir/advertised_nets")  };

    my $servers = $openvpn->model('Servers');
    my $row = $servers->findRow(name => $name);
    my $advertisedNetworks = $row->subModel('advertisedNetworks');
    # set server advertised networks
    
    while (my ($net, $mask) = each %advertised) {
        $mask = EBox::NetWrappers::bits_from_mask($mask);
        $advertisedNetworks->addRow(network => "$net/$mask" );
    }
}

sub _migrateClients
{
    my ($self) = @_;
    my $openvpn = $self->{gconfmodule};

    foreach my $name (@{ $openvpn->all_dirs_base('client') } ) {
        my $dir = "client/$name";

        # fetch all client config
        my $active = $openvpn->get_bool("$dir/active");
        my $internal  = $openvpn->get_bool("$dir/internal");   

        my $ifaceNumber = $openvpn->get_int("$dir/iface_number");

        # create client row
        my $clients = $openvpn->model('Clients');
        $clients->addRow(
                         name => $name,
                         service => 0,
                         internal  => $internal,
                         interfaceType => 'tap',
                         interfaceNumber => $ifaceNumber,
                        );

        my $confOk = $self->_setClientConf($name, $dir);
 
        if ($active) {
            if ($confOk) {
                # we have the client configured so we can change the service value
                my $row = $clients->findRow(name => $name);
                my $service = $row->elementByName('service');
                $service->setValue(1);
                $row->store();
            }
            else {
                print "We cannot activate client $name because is not fully configured\n";
            }
        }

        # done! we delete the client directory
        $openvpn->delete_dir($dir);
    }
}


sub _setClientConf
{
    my ($self, $name, $dir)  =@_;

    my $openvpn = $self->{gconfmodule};

    my $confOk = 1;

    # althought this data structure was prepared to store more than one
    # server/port pairs we never user more than one
    my ($server, $port) = each %{ $openvpn->hash_from_dir("$dir/servers")  };

    my $proto = $openvpn->get_string("$dir/proto");

    my $portAndProtocol = "$port/$proto";

    my $ripPasswd = $openvpn->get_string("$dir/ripPasswd");
    # we ignore the caCertificate certificate nand certificate keys values bz
    # they were always set to privateDriectory + type file and we haven't
    # changed that

    # however we have to put the files in the place which will be looked upon
    # from the file field bz if we fail to do sowe will launch a validation
    # certificate request against non existnt files
    my @files = qw(caCertificate certificate certificateKey );
    foreach my $f (@files) {
        # the destination must be the same than the vlaue obtained with tmpPath
        # in the EBox::Type::File field!!!
        my $orig =  "/etc/openvpn/$name.conf.d/$f";
        my $dest =  EBox::Config::tmp() . $f . '_path';
        EBox::Sudo::root ("cp -p $orig $dest");
    }

    my $clients = $openvpn->model('Clients');
    my $clientRow = $clients->findRow(name => $name);
    my $configuration    = $clientRow->subModel('configuration');
    # set client configuration model

    my %confToSet   = (
                         server    => $server,
                         serverPortAndProtocol => $portAndProtocol,
                         ripPasswd => $ripPasswd,
                      );

    if (length $ripPasswd < 6) {
        print "Previous RIP password not valid because it has less than 6 characters. A tmeporally password will be set. You will need to vhange it finish the configuration of the client $name manually\n";
        $confToSet{ripPasswd} = '123456';
        $confOk = 0;
    }


    my $row = $configuration->row();

    while (my ($attr, $value) = each %confToSet) {
        $row->elementByName($attr)->setValue($value);
    }

    $row->store();

    return $confOk;
}


EBox::init();
my $openvpn = EBox::Global->modInstance('openvpn');
my $migration = new EBox::Migration( 
                                     'gconfmodule' => $openvpn,
                                     'version' => 3,
                                    );
$migration->execute();                               


1;
