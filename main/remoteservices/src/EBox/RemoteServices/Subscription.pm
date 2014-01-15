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

# Class: EBox::RemoteServices::Subscription
#
#       Class to manage the Zentyal subscription to Zentyal Cloud
#
package EBox::RemoteServices::Subscription;

use base 'EBox::RemoteServices::Base';

use feature qw(switch);

use EBox::Config;
use EBox::Exceptions::Command;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Configuration;
use EBox::RemoteServices::Connection;
use EBox::RemoteServices::RESTClient;
use EBox::RemoteServices::Subscription::Check;
use EBox::Sudo;
use EBox::Util::Nmap;

use AptPkg::Cache;
use Archive::Tar;
use Cwd;
use TryCatch::Lite;
use File::Copy::Recursive;
use File::Slurp;
use File::Temp;
use JSON::XS;
use HTML::Mason;

# Constants
use constant {
    SERV_CONF_DIR => 'remoteservices',
    SERV_CONF_FILE => 'remoteservices.conf',
    PROF_PKG       => 'zentyal-cloud-prof',
    SEC_UPD_PKG    => 'zentyal-security-updates',
    SYNC_PKG       => 'zfilesync',
    REMOVE_PKG_SCRIPT => EBox::Config::scripts('remoteservices') . 'remove-pkgs',
};

# Group: Public methods

# Constructor: new
#
#     Create the subscription client object
#
# Parameters:
#
#     user - String the username for auth proposes
#     password - String the password used for authenticating the user
#
#     - Named parameters
#
sub new
{
    my ($class, %params) = @_;

    exists $params{user} or
      throw EBox::Exceptions::MissingArgument('user');
    exists $params{password} or
      throw EBox::Exceptions::MissingArgument('password');

    my $self = $class->SUPER::new();

    $self->{user} = $params{user};
    $self->{password} = $params{password};

    # Set the REST client
    $self->{restClient} = new EBox::RemoteServices::RESTClient(
        credentials => { username => $params{user},
                         password => $params{password} });

    bless $self, $class;
    return $self;
}

# Method: serviceUrn
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceUrn>
#
sub serviceUrn
{
    my ($self) = @_;

    return 'EBox/Services/RegisteredEBoxList';
}

# Method: serviceHostName
#
# Overrides:
#
#    <EBox::RemoteServices::Base::serviceHostName>
#
sub serviceHostName
{
    my $host = EBox::Config::configkeyFromFile('ebox_services_www',
                                               EBox::Config::etc() . SERV_CONF_FILE );
    $host or
      throw EBox::Exceptions::External(
          __('Key for web subscription service not found')
         );

    return $host;
}

# Method: soapCall
#
# Overrides:
#
#    <EBox::RemoteServices::Base::soapCall>
#
sub soapCall
{
  my ($self, $method, @params) = @_;

  my $conn = $self->connection();

  return $conn->$method(
                        user      => $self->{user},
                        password  => $self->{password},
                        @params
                       );
}

# Method: subscribeServer
#
#      Given a name trying to subscribe a server for that user using
#      that name. If it is already registered, the process will reset
#      the server password. If the process works nicely, a set of
#      basic parameters are stored. In order to get the full
#      functionality, it is required to get the bundle in a separated
#      process to set the parameters to connect to the Zentyal Cloud
#      infrastructure including the required certificates.
#
# Parameters:
#
#      name - String the name which the user uses to describe this
#             server
#
#      option - String the selected option if available
#               (Optional) : if not given, then it will try with one
#                            of the available ones
#
# Returns:
#
#      hash ref - containing the following keys and values:
#
#        confFile - the configuration file to be used to connect to
#        the infrastructure
#
#        new - Boolean indicating if the subscription was done or just
#        the file getting
#
#        availableEditions - Array ref containing the available options
#                            to subscribe your server, if this value is set
#                            then we do not have subscribed yet
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if the compulsory
#      argument is missing
#
sub subscribeServer
{
    my ($self, $name, $option) = @_;

    $name or throw EBox::Exceptions::MissingArgument('name');

    # Ensure firewall rules are opened
    $self->_openHTTPSConnection();

    # Check the WS is reachable
    $self->_checkWSConnectivity();

    $option = undef if ( defined($option) and ( $option eq 'reload' ));

    if (not $option) {
        my $availables = $self->_getAvailable($name);

        my $checker = new EBox::RemoteServices::Subscription::Check();
        # Check the available editions are suitable for this server
        my @availables = grep { $checker->check($_) } @{$availables};

        given ( scalar(@availables) ) {
            when (0) {
                if (@{$availables} > 0) {
                    # There were some available options but the server is not suitable
                    # for the available options
                    throw EBox::RemoteServices::Exceptions::NotCapable(
                        __('None of the available bundles are valid for this server')
                        . '. ' . __x('Reason: {reason}', reason => $checker->lastError())
                       );
                }
            }
            when ( 1 ) {
                # Just one is purchased
                $option = $availables[0]->{id};
            }
            when ($_ > 1 ) {
                return { 'availableEditions' => \@availables };
            }
        }
    }

    # my $vpnSettings;
    # try {
    #     $vpnSettings = $self->soapCall('vpnSettings',
    #                                    option => $option);
    # } catch (EBox::Exceptions::DataNotFound $e) { };
    # unless ( defined($vpnSettings) ) {
    #     throw EBox::Exceptions::External(
    #         __x(
    #             'Cannot retrieve VPN settings needed for subscription. Check your {openurl}{brand} profile{closeurl} to check your VPN server settings.',
    #             brand    => 'Zentyal Cloud',
    #             openurl  => q{<a href='https://cloud.zentyal.com/services/profile/'>},
    #             closeurl => q{</a>}
    #            )
    #        );
    # }

    # # Check the selected VPN server is reachable
    # $self->_checkVPNConnectivity(
    #                              $vpnSettings->{ipAddr},
    #                              $vpnSettings->{protocol},
    #                              $vpnSettings->{port},
    #                             );

    # my $conf;
    my $response = $self->{restClient}->POST("/v1/servers/",
                                             query => { 'name' => $name, 'bundle' => $option} );
    my $serverInfoRaw = $response->as_string();
    my $serverInfo = $response->data();

    # Write this info to a file only readable by Zentyal
    $self->_writeCredentials($name, $serverInfoRaw);

    return { 'new' => $serverInfo->{created} };

    # my $new = 0;
    # my $rs = EBox::Global->modInstance('remoteservices');
    # try {
    #     $ = $self->soapCall('subscribeEBox',
    #                                      canonicalName => $name,
    #                                      rsVersion     => $rs->version(),
    #                                      option        => $option);
    #     $new = 1;
    # } catch (EBox::Exceptions::DataExists $e) {
    #     $bundleRawData = $self->soapCall('eBoxBundle',
    #                                      canonicalName => $name,
    #                                      rsVersion     => $rs->version(),
    #                                      option        => $option);
    #     $new = 0;
    # };

    # my $params = $self->extractBundle($name, $bundleRawData);

    # my $confKeys = EBox::Config::configKeysFromFile($params->{confFile});
    # $self->_openVPNConnection(
    #     $confKeys->{vpnServer},
    #     $confKeys->{vpnPort},
    #     $confKeys->{vpnProtocol},
    #    );

    # $self->executeBundle($params, $confKeys);

    # $params->{new} = $new;
    # return $params;
}

# Method: serversList
#
#      Return the list of registered Zentyal servers for this user
#
# Returns:
#
#      Array ref - the Zentyal server common names
#
sub serversList
{
    my ($self) = @_;

    my $list = $self->soapCall('showList');

    return $list;
}

# Method: availableEdition
#
#      Return the possible available editions for this user if he
#      subscribes a new server
#
# Returns:
#
#      Array ref - the possible available editions
#
sub availableEdition
{
    my ($self) = @_;

    my $list = $self->soapCall('availableEdition');

    return $list;

}

# Class Method: extractBundle
#
#      Given the bundle as string data, extract the files to the
#      proper locations
#
# Parameters:
#
#      bundleContent - String the bundle data to extract
#
# Returns:
#
#      hash ref - containing the following keys:
#
#          ca - String the CA certificate path
#          cert - String the certificate path
#          key - String the private key path
#          confFile - String the configuration file path
#          installCloudProf - String the install script for Professional add-ons
#          scripts - Array ref containing the scripts to run after extracting the bundle
#
sub extractBundle
{
    my ($class, $cn, $bundleContent) = @_;

    my $tmp = new File::Temp(TEMPLATE => 'servicesXXXX',
                             DIR      => EBox::Config::tmp(),
                             SUFFIX   => '.tar.gz');

    File::Slurp::write_file($tmp->filename(), $bundleContent);

    # debug!!
 #   EBox::Sudo::root('cp ' . $tmp->filename . ' /tmp/bundle.tar');
#    EBox::Sudo::root('cp /tmp/input.tar ' . $tmp->filename );

    my $tar = new Archive::Tar($tmp->filename(), 1);
    my @files = $tar->list_files();
    my $cwd = Cwd::getcwd();

    my $dirPath = $class->_createSubscriptionDir($cn);
    chdir($dirPath);

    my ($confFile, $keyFile, $certFile, $installCloudProf);
    my @scripts;
    foreach my $filePath (@files) {
        $tar->extract_file($filePath)
          or throw EBox::Exceptions::Internal("Cannot extract file $filePath");
        if ( $filePath =~ m:\.conf$: ) {
            $confFile = $filePath;
        } elsif ( $filePath =~ m:$cn: ) {
            $keyFile = $filePath;
        } elsif ($filePath =~ m{exec\-\d+\-}) {
            push(@scripts, $filePath);
        } elsif ( $filePath =~ /install-cloud-prof\.pl$/) {
            $installCloudProf = $filePath;
        } elsif ( $filePath ne 'cacert.pem' ) {
            $certFile = $filePath;
        }
    }

    # Remove everything we created before
    unlink($tmp->filename());

    my $bundle =  {
        ca => "$dirPath/cacert.pem",
        cert => "$dirPath/$certFile",
        key => "$dirPath/$keyFile",
        confFile => "$dirPath/$confFile",
    };

    if (defined $installCloudProf) {
        $bundle->{installCloudProf} = "$dirPath/$installCloudProf";
    }

    if (@scripts) {
        # order by number
        @scripts = sort @scripts;
        @scripts = map { "$dirPath/$_" } @scripts;
        $bundle->{scripts}  = \@scripts;

    }

    return $bundle;
}

# Method: executeBundle
#
#     Perform actions after extracting the bundle
#
#     Current actions:
#
#        - Restart remoteservices, firewall and web admin modules
#        - Downgrade if necessary
#        - Install cloud-prof package
#        - Execute bundle scripts (Alert autoconfiguration)
#
# Parameters:
#
#     params - Hash ref What is returned from <extractBundle> procedure
#     confKeys - Hash ref the configuration keys stored in client configuration
#
sub executeBundle
{
    my ($self, $params, $confKeys) =  @_;

    # Set to have the bundle
    my $rs = EBox::Global->getInstance()->modInstance('remoteservices');
    $rs->st_set_bool('has_bundle', 1);

    $self->_restartRS();
    # Downgrade, if necessary
    $self->_downgrade();
    $self->_installCloudProf($params, $confKeys);
    $self->_executeBundleScripts($params, $confKeys);
}

# Method: deleteData
#
#      Delete the data stored when a subscription is done
#      correctly. That is, the certificates and configuration files
#      are deleted.
#
#      It also performs every action required to unsubscribe
#
# Parameters:
#
#      cn - String the common name from where to delete data
#
# Returns:
#
#      1 - if the deletion works nicely
#
#      0 - if it was nothing to delete
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if the compulsory
#      argument is missing
#
sub deleteData
{
    my ($self, $cn) = @_;

    $cn or throw EBox::Exceptions::MissingArgument('cn');

    my $rs = EBox::Global->modInstance('remoteservices');
    if ( $rs->hasBundle() ) {
        # Remove VPN client, if exists
        EBox::RemoteServices::Connection->new()->disconnectAndRemove();
    }

    my $dirPath = $self->_subscriptionDirPath($cn);

    unless ( -d $dirPath ) {
        return 0;
    }

    # Remove subscription dir
    opendir(my $dir, $dirPath);
    while(my $filePath = readdir($dir)) {
        if ( -d "$dirPath/$filePath" ) {
            File::Copy::Recursive::pathrmdir( "$dirPath/$filePath" );
        }
        next unless -f "$dirPath/$filePath";
        unlink("$dirPath/$filePath");
    }
    closedir($dir);
    rmdir($dirPath);

    if ( $rs->hasBundle() ) {
        # Remove DDNS autoconfiguration
        $self->_removeDDNSConf();
        # Remove alert autoconfiguration
        # FIXME: Do by alertAutoconfiguration script?
        my $events = EBox::Global->modInstance('events');
        $events->unset('alert_autoconfiguration');
        # TODO: Remove zentyal-cloud-prof package

        # Remove jobs
        my $cronPrefix = EBox::RemoteServices::Configuration::CronJobPrefix();
        $dirPath = EBox::Config::conf() . SERV_CONF_DIR . '/jobs';
        if ( -d $dirPath ) {
            opendir($dir, $dirPath);
            while(my $filePath = readdir($dir)) {
                next unless -d "$dirPath/$filePath";
                if ($filePath =~ m/^[0-9]+$/g or $filePath =~ m/^$cronPrefix/g) {
                    EBox::Sudo::command("rm -rf '$dirPath/$filePath'");
                } elsif ( $filePath =~ m/incoming|outcoming/g ) {
                    # Remove any left incoming/outcoming job
                    EBox::Sudo::command("rm -f '$dirPath/$filePath/*'");
                }
            }
            closedir($dir);
        }
    }

    # Remove subscription cached info and disaster recovery if any
    my $state = $rs->get_state();
    foreach my $key (qw(admin_port has_bundle subscription disaster_recovery)) {
        delete $state->{$key};
    }
    $rs->set_state($state);
}

# Group: Private methods

# Open up the HTTPS connections
sub _openHTTPSConnection
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('firewall') ) {
        my $fw = $gl->modInstance('firewall');
        if ( $fw->isEnabled() and not $fw->needsSaveAfterConfig()) {
            eval "use EBox::Iptables";
            my $output = EBox::Sudo::root(EBox::Iptables::pf('-L ointernal'));
            my $matches = scalar(grep { $_ =~ m/dpt:https/g } @{$output});
            if ( $matches < 1 ) {
                my $site = EBox::RemoteServices::Configuration::APIEndPoint();
                try {
                    EBox::Sudo::root(
                        EBox::Iptables::pf(
                            "-A ointernal -p tcp -d $site --dport 443 -j oaccept"
                           )
                         );
                } catch (EBox::Exceptions::Sudo::Command $e) {
                    throw EBox::Exceptions::External(
                        __x('Cannot contact to {host}. Check your connection to the Internet',
                            host => $site));
                }
                my $dnsServer = EBox::RemoteServices::Configuration::DNSServer();
                EBox::Sudo::root(
                    EBox::Iptables::pf(
                        "-A ointernal -p udp -d $dnsServer --dport 53 -j oaccept"
                       )
                    );
            }
        }
    }

}

# Close down HTTPS connections and open up VPN one
sub _openVPNConnection #(ipaddr, port, protocol)
{
    my ($self, $ipAddr, $port, $protocol) = @_;

    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('firewall') ) {
        my $fw = $gl->modInstance('firewall');
        if ( $fw->isEnabled() and not $fw->needsSaveAfterConfig()) {
            eval "use EBox::Iptables";
            EBox::Sudo::root(
                EBox::Iptables::pf(
                    "-A ointernal -p $protocol -d $ipAddr --dport $port -j oaccept"
                   )
                 );
        }
    }
}

# Try to install zentyal-cloud-prof package 10 times during 50 minutes
# if any problem happened with dpkg
sub _installCloudProf
{
    my ($self, $params, $confKeys) = @_;

    return unless ( exists $params->{installCloudProf} );

    if ( $self->_pkgInstalled(PROF_PKG) ) {
        return;
    }

    my $installCloudProf = $params->{installCloudProf};

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    $fh->unlink_on_destroy(0);
    my $tmpFilename = $fh->filename();
    my $try = <<END;
#!/bin/bash
for try in {1..10}
do
   $installCloudProf
   if dpkg -l | grep cloud-prof | grep ^ii; then
      break
   fi
   sleep 300
done
rm -f $tmpFilename
END
    print $fh $try;
    close($fh);

    try {
        EBox::Sudo::command("chmod a+x '$installCloudProf'");
        EBox::Sudo::command("bash '$tmpFilename'");
    } catch (EBox::Exceptions::Command $e) {
        EBox::error($e);
    }
}

sub _executeBundleScripts
{
    my ($self, $params) = @_;

    if (not exists $params->{scripts}) {
        return;
    }

    foreach my $script (@{  $params->{scripts} }) {
        try {
            EBox::Sudo::root("chmod u+x '$script'");
            EBox::Sudo::root($script);
        } catch (EBox::Exceptions::Command $e) {
            # ignore script errors
        }
    }
}

# Remove the Dynamic DNS configuration only if the service is using
# cloud service
sub _removeDDNSConf
{
    my ($self) = @_;

    my $networkMod = EBox::Global->modInstance('network');
    if ( $networkMod->DDNSUsingCloud() ) {
        my $ddnsModel = $networkMod->model('DynDNS');
        $ddnsModel->set(enableDDNS => 0);
    } else {
        EBox::info('DynDNS is using other service, not modifying');
    }
}

# Check if the zentyal-cloud-prof is already installed
sub _pkgInstalled
{
    my ($self, $pkg) = @_;

    my $installed = 0;
    my $cache = new AptPkg::Cache();
    if ( $cache->exists($pkg) ) {
        my $pkg = $cache->get($pkg);
        $installed = ( $pkg->{SelectedState} == AptPkg::State::Install
                       and $pkg->{InstState} == AptPkg::State::Ok
                       and $pkg->{CurrentState} == AptPkg::State::Installed );
    }
    return $installed;
}

# Check the Web Services connectivity
sub _checkWSConnectivity
{
    my ($self) = @_;

    my $host = EBox::RemoteServices::Configuration::APIEndPoint();
    $host or throw EBox::Exceptions::External('rs_api key not found in remoteservices.conf file');

    my $network       = EBox::Global->modInstance('network');
    my $proxySettings = $network->proxySettings();
    my $proxy      = $proxySettings->{server};
    my $proxyPort  = $proxySettings->{port};
    my $proxyUser  = $proxySettings->{username};
    my $proxyPass  = $proxySettings->{password};

    my $proto = 'tcp';
    my $port = 443;

    my $ok;
    my $url = 'https://' . $host . '/check';
    my $cmd = "curl --insecure ";
    if ($proxy) {
        $cmd .= "--proxy $proxy:$proxyPort ";
        if ($proxyUser) {
            $cmd .= " --proxy-user $proxyUser:$proxyPass ";
        }
    }
    $cmd .= $url;

    try {
        my $output = EBox::Sudo::command($cmd);
        foreach my $line (@{ $output }) {
            if ($line =~ m/A prudent question is one-half of wisdom/) {
                $ok = 1;
                last;
            }
        }
    } catch (EBox::Exceptions::Command $e) {
        $ok = 0;
    }

    unless ($ok) {
        throw EBox::Exceptions::External(
            __x(
                'Could not connect to API server "{addr}:{port}/{proto}". '
                . 'Check your name resolution and firewall in your network',
                addr => $host,
                port => $port,
                proto => $proto,
               )
           );
    }
}

# Check the VPN server is reachable
sub _checkVPNConnectivity
{
    my ($self, $host, $proto, $port) = @_;

    return if EBox::Config::boolean('subscription_skip_vpn_scan');

    my $ok = 0;
    if ( $proto eq 'tcp' ) {
        $ok = $self->_checkHostPort($host, $proto, $port);
    } else {
        # we use echo service to make sure no firewall stands on our way
         $ok = $self->_checkUDPEchoService($host, $proto, $port);
    }

    if (not $ok) {
        throw EBox::Exceptions::External(
            __x(
                'Could not connect to VPN server "{addr}:{port}/{proto}". '
                . 'Check your network firewall',
                addr => $host,
                port => $port,
                proto => $proto,
               )
           );
    }
}

# Restart RS once the bundle is reloaded
sub _restartRS
{
    my ($self) = @_;

    # This code must be locked and it is critical
    my $global = EBox::Global->getInstance();
    my $rs = $global->modInstance('remoteservices');
    $rs->save();
    # Required to set the proper iptables rules to ensure connection to Cloud
    my $fw = $global->modInstance('firewall');
    $fw->save();
    # Required to set the CA correctly
    my $webAdmin = $global->modInstance('webadmin');
    $webAdmin->save();
}

# Downgrade current subscription, if necessary
# Things to be done:
#   * Uninstall zentyal-cloud-prof and zentyal-security-updates packages
#
sub _downgrade
{
    my ($self) = @_;

    my $rs = EBox::Global->modInstance('remoteservices');
    # Remove packages if basic subscription or no subscription at all
    if ($rs->subscriptionLevel(1) <= 0) {
        $self->_removePkgs();
    }
}

# Remove private packages
sub _removePkgs
{
    my ($self) = @_;

    # Remove pkgs using at to avoid problems when doing so from Zentyal UI
    my @pkgs = (PROF_PKG, SEC_UPD_PKG, SYNC_PKG);
    @pkgs = grep { $self->_pkgInstalled($_) } @pkgs;

    return unless ( @pkgs > 0 );

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    $fh->unlink_on_destroy(0);
    print $fh 'exec ' . REMOVE_PKG_SCRIPT . ' ' . join(' ', @pkgs) . "\n";
    close($fh);

    try {
        EBox::Sudo::command('at -f "' . $fh->filename() . '" now+1hour');
    } catch (EBox::Exceptions::Command $e) {
        EBox::debug($e->stringify());
    }
}

# Get available editions for this user/pass
sub _getAvailable
{
    my ($self, $server) = @_;

    my $response = $self->{restClient}->GET("/v1/bundle/available/$server/");
    return $response->data();
}

# Write received credentials into the proper directory and set proper permissions
sub _writeCredentials
{
    my ($self, $name, $serverInfoRaw) = @_;

    $self->_createSubscriptionDir($name);

    my $credentialsFilePath = $self->_credentialsFilePath($name);

    try {
        File::Slurp::write_file($credentialsFilePath, $serverInfoRaw);
    } catch ($e) {
        throw EBox::Exceptions::External(__x("Probably lack of free space: {exc}", exc => $e));
    }
    chmod(0600, $credentialsFilePath);
}

# Create the subscription directory structure based on the given name
# Return the newly created directory
sub _createSubscriptionDir
{
    my ($self, $name) = @_;

    my $dirPath = $self->_subscriptionDirPath($name);
    unless ( -d $dirPath ) {
        my @dirs;
        my @path = split(/\//, $dirPath);
        foreach my $dir (@path) {
            push(@dirs, $dir);
            mkdir(join('/', @dirs));
        }
    }
    return $dirPath;
}

1;
