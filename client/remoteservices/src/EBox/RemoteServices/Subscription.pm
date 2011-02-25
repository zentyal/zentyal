# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::RemoteServices::Subscription;

# Class: EBox::RemoteServices::Subscription
#
#       Class to manage the Zentyal subscription to Zentyal Cloud
#

use base 'EBox::RemoteServices::Base';

use strict;
use warnings;

use EBox::Config;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Configuration;
use EBox::Sudo;
use EBox::RemoteServices::Nmap;

use AptPkg::Cache;
use Archive::Tar;
use Cwd;
use Error qw(:try);
use File::Slurp;
use File::Temp;
use HTML::Mason;
use Net::Ping;

# Constants
use constant {
    SERV_CONF_DIR => 'remoteservices',
    SERV_SUBDIR => 'remoteservices/subscription',
    SERV_CONF_FILE => '78remoteservices.conf',
    PROF_PKG       => 'ebox-cloud-prof',
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

# Method: subscribeEBox
#
#      Given a name trying to subscribe an eBox for that user using
#      that name. If it is already registered, the process will
#      fail. If the process works nicely, a bundle is got which is
#      used to set the parameters to connect to the eBox remote
#      infrastructure including the required certificates.
#
# Parameters:
#
#      name - String the name which the user uses to describe this
#      eBox
#
# Returns:
#
#      hash ref - containing the following keys and values:
#
#        ca - the CA certificate path
#        cert - the certificate path for this eBox
#        key - the private key path for this eBox
#
#        confFile - the configuration file to be used to connect to
#        the infrastructure
#
#        new - Boolean indicating if the subscription was done or just
#        the file getting
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if the compulsory
#      argument is missing
#
sub subscribeEBox
{
    my ($self, $cn) = @_;

    $cn or throw EBox::Exceptions::MissingArgument('cn');

    # Ensure firewall rules are opened
    $self->_openHTTPSConnection();

    # Check the WS is reachable
    $self->_checkWSConnectivity();

    my $vpnSettings;
    try {
        $vpnSettings = $self->soapCall('vpnSettings');
    } catch EBox::Exceptions::Base with { };
    unless ( defined($vpnSettings) ) {
        throw EBox::Exceptions::External(
            __x(
                'Cannot retrieve VPN settings needed for subscription. Check your {openurl}{brand} profile{closeurl} to check your VPN server settings.',
                brand    => 'Zentyal Cloud',
                openurl  => q{<a href='https://cloud.zentyal.com/services/profile/'>},
                closeurl => q{</a>}
               )
           );
    }

    # Check the selected VPN server is reachable
    $self->_checkVPNConnectivity(
                                 $vpnSettings->{ipAddr},
                                 $vpnSettings->{protocol},
                                 $vpnSettings->{port},
                                );


    my $bundleRawData;
    my $new = 0;
    try {
        $bundleRawData = $self->soapCall('subscribeEBox', canonicalName => $cn);
        $new = 1;
    } catch EBox::Exceptions::DataExists with {
        $bundleRawData = $self->soapCall('eBoxBundle', canonicalName => $cn);
        $new = 0;
    };

    my $params = $self->extractBundle($cn, $bundleRawData);

    my $confKeys = EBox::Config::configKeysFromFile($params->{confFile});
    $self->_openVPNConnection(
        $confKeys->{vpnServer},
        $confKeys->{vpnPort},
        $confKeys->{vpnProtocol},
       );


    $self->executeBundle($params, $confKeys);

    $params->{new} = $new;
    return $params;
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
#          QASources - String path to the QA source list mason template
#          QAAptPubKey - String path to the QA apt repository public key
#          QAAptPreferences - String path to the QA preferences file
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

    my $dirPath = EBox::Config::conf() . SERV_CONF_DIR;
    unless ( -d $dirPath ) {
        mkdir($dirPath);
    }
    $dirPath = EBox::Config::conf() . SERV_SUBDIR;
    unless (chdir($dirPath)) {
        mkdir($dirPath);
        chdir($dirPath);
    }
    $dirPath .= "/$cn";
    unless (chdir($dirPath)) {
        mkdir($dirPath);
        chdir($dirPath);
    }

    my ($confFile, $keyFile, $certFile, $qaSources, $qaGpg, $qaPreferences, $installCloudProf);
    my @scripts;
    foreach my $filePath (@files) {
        $tar->extract_file($filePath)
          or throw EBox::Exceptions::Internal("Cannot extract file $filePath");
        if ( $filePath =~ m:\.conf$: ) {
            $confFile = $filePath;
        } elsif ( $filePath =~ m:$cn: ) {
            $keyFile = $filePath;
        } elsif ($filePath =~ /ebox-qa\.list\.mas$/) {
            $qaSources = $filePath;
        } elsif ($filePath =~ /ebox-qa\.pub$/) {
            $qaGpg = $filePath;
        } elsif ($filePath =~ /ebox-qa\.preferences$/) {
            $qaPreferences = $filePath;
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


    if (defined $qaSources) {
        $bundle->{QASources} = "$dirPath/$qaSources";
    }
    if (defined $qaGpg) {
        $bundle->{QAAptPubKey} = "$dirPath/$qaGpg";
    }
    if (defined $qaPreferences) {
        $bundle->{QAAptPreferences} = "$dirPath/$qaPreferences";
    }
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
#        - Create John home directory (Security audit)
#        - Set QA updates (QA repository and its preferences)
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

    $self->_setUpAuditEnvironment();
    $self->_setQAUpdates($params, $confKeys);
    $self->_installCloudProf($params, $confKeys);
    $self->_executeBundleScripts($params, $confKeys);
}

# Method: deleteData
#
#      Delete the data stored when a subscription is done
#      correctly. That is, the certificates and configuration files
#      are deleted.
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

    my $dirPath = EBox::Config::conf() . SERV_SUBDIR . "/$cn";

    unless ( -d $dirPath ) {
        return 0;
    }

    opendir(my $dir, $dirPath);
    while(my $filePath = readdir($dir)) {
        next unless -f "$dirPath/$filePath";
        unlink("$dirPath/$filePath");
    }
    closedir($dir);
    rmdir($dirPath);

    # Remove QA updates configuration
    $self->_removeQAUpdates();
    # Remove alert autoconfiguration
    # FIXME: Do by alertAutoconfiguration script?
    my $events = EBox::Global->modInstance('events');
    $events->unset('alert_autoconfiguration');
    # TODO: Remove ebox-cloud-prof package

    # Remove subscription levels and disaster recovery if any
    my $rs = EBox::Global->modInstance('remoteservices');
    $rs->st_delete_dir('subscription');
    $rs->st_delete_dir('disaster_recovery');

}

# Checks whether the installed modules allows to be unsubscribed for cloud
sub checkUnsubscribeIsAllowed
{
    my $modList = EBox::Global->modInstances();
    foreach my $mod (@{  $modList }) {
        my $method = 'canUnsubscribeFromCloud';
        if ($mod->can($method)) {
            $mod->$method();
        }
    }
}

# Group: Private methods

# Open up the HTTPS connections
sub _openHTTPSConnection
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('firewall') ) {
        my $fw = $gl->modInstance('firewall');
        if ( $fw->isEnabled() ) {
            eval "use EBox::Iptables";
            my $mirrorCount = EBox::RemoteServices::Configuration::eBoxServicesMirrorCount();
            my $output = EBox::Sudo::root(EBox::Iptables::pf('-L ointernal'));
            my $matches = scalar(grep { $_ =~ m/dpt:https/g } @{$output});
            if ( $matches < $mirrorCount ) {
                foreach my $no ( 1 .. $mirrorCount ) {
                    my $site = EBox::RemoteServices::Configuration::PublicWebServer();
                    $site =~ s:\.:$no.:;
                    try {
                        EBox::Sudo::root(
                            EBox::Iptables::pf(
                                "-A ointernal -p tcp -d $site --dport 443 -j ACCEPT"
                               )
                             );
                    } catch EBox::Exceptions::Sudo::Command with {
                        throw EBox::Exceptions::External(
                            __x('Cannot contact to {host}. Check your connection to the Internet',
                                host => $site));
                    };
                }
                my $dnsServer = EBox::RemoteServices::Configuration::DNSServer();
                EBox::Sudo::root(
                    EBox::Iptables::pf(
                        "-A ointernal -p udp -d $dnsServer --dport 53 -j ACCEPT"
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
        if ( $fw->isEnabled() ) {
            eval "use EBox::Iptables";
            # Comment out to allow connections
#             my $output = EBox::Iptables::pf('-L ointernal');
#             my $mirrorCount = EBox::RemoteServices::Configuration::eBoxServicesMirrorCount();
#             my $matches = scalar(grep { $_ =~ m/dpt:https/g } @{$output});
#             if ( $matches >= $mirrorCount ) {
#                 foreach my $no ( 1 .. $mirrorCount ) {
#                     my $site = EBox::RemoteServices::Configuration::PublicWebServer();
#                     $site =~ s:\.:$no.:;
#                     EBox::Iptables::pf(
#                         "-D ointernal -p tcp -d $site --dport 443 -j ACCEPT"
#                        );
#                 }
#                 my $dnsServer = EBox::RemoteServices::Configuration::DNSServer();
#                 EBox::Iptables::pf(
#                     "-D ointernal -p udp -d $dnsServer --dport 53 -j ACCEPT"
#                    );
#             }
            EBox::Sudo::root(
                EBox::Iptables::pf(
                    "-A ointernal -p $protocol -d $ipAddr --dport $port -j ACCEPT"
                   )
               );
        }
    }
}

sub _setUpAuditEnvironment
{
    my $johnDir = EBox::RemoteServices::Configuration::JohnHomeDirPath();
    unless ( -d $johnDir ) {
        mkdir($johnDir);
    }
}

sub _setQAUpdates
{
    my ($self, $params, $confKeys) = @_;

    my @paramsNeeded = qw(QASources QAAptPubKey QAAptPreferences);
    foreach my $param (@paramsNeeded) {
        exists $params->{$param} or
            return;
    }

    $self->_setQASources($params->{QASources}, $confKeys);
    $self->_setQAAptPubKey($params->{QAAptPubKey});
    $self->_setQAAptPreferences($params->{QAAptPreferences});

    my $softwareMod = EBox::Global->modInstance('software');
    if ($softwareMod) {
        if ( $softwareMod->can('setQAUpdates') ) {
            $softwareMod->setQAUpdates(1);
        }
    } else {
        EBox::info('No software module installed QA updates should be done by hand');
    }

}

# Install ebox-cloud-prof package in a hour to avoid problems with dpkg
sub _installCloudProf
{
    my ($self, $params, $confKeys) = @_;

    return unless ( exists $params->{installCloudProf} );

    return if ( $self->_cloudProfInstalled() );

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    $fh->unlink_on_destroy(0);
    print $fh "exec " . $params->{installCloudProf} . " \n";
    close($fh);

    try {
        EBox::Sudo::command("chmod a+x '" . $params->{installCloudProf} . "'");
        # Delay the ebox-cloud-prof installation for an hour
        EBox::Sudo::root('at -f "' . $fh->filename() . '" now+1hour');
    } catch EBox::Exceptions::Command with {
        # Ignore installation errors
    };

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
        } catch EBox::Exceptions::Command with {
            # ignore script errors
        };
    }
}

# Set the QA source list
sub _setQASources
{
    my ($self, $qaFile, $confKeys) = @_;

    my $ubuntuVersion = _ubuntuVersion();
    my $archive = 'ebox-qa-' . $ubuntuVersion;
    my $repositoryAddr = $self->_repositoryAddr($confKeys);

    # Perform the mason template manually since it is not stored in stubs directory
    my $output;
    my $interp = new HTML::Mason::Interp(out_method => \$output);
    my $comp   = $interp->make_component(comp_file  => $qaFile);
    $interp->exec($comp, ( (repositoryIPAddr => $repositoryAddr),
                           (archive          => $archive)) );

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    my $tmpFile = $fh->filename();
    File::Slurp::write_file($tmpFile, $output);
    my $destination = EBox::RemoteServices::Configuration::aptQASourcePath();
    EBox::Sudo::root("cp '$tmpFile' '$destination'");
    EBox::Sudo::root("chmod 0644 '$destination'");

}

# Get the ubuntu version
sub _ubuntuVersion
{
    my @releaseInfo = File::Slurp::read_file('/etc/lsb-release');
    foreach my $line (@releaseInfo) {
        next unless ($line =~ m/^DISTRIB_CODENAME=/ );
        chomp $line;
        my ($key, $version) = split '=', $line;
        return $version;
    }

}

# Set the QA apt repository public key
sub _setQAAptPubKey
{
    my ($self, $keyFile) = @_;
    my $destination = EBox::RemoteServices::Configuration::aptQASourcePath();
#    EBox::debug("apt-key add $keyFile");

    EBox::Sudo::root("apt-key add $keyFile");
}



sub _setQAAptPreferences
{
    my ($self, $preferencesFile) = @_;

    my $preferences = '/etc/apt/preferences';
    my $fromCCPreferences = $preferences . '.ebox.fromcc'; # file to store CC preferences
    EBox::Sudo::root("cp '$preferencesFile' '$fromCCPreferences'");

    my $exclusiveSource = EBox::Config::configkey('qa_updates_exclusive_source');
    if (lc($exclusiveSource) ne 'true') {
        return;
    }

    # LUCID version
    my $preferencesDirFile = '/etc/apt/preferences.d/01ebox';
    EBox::Sudo::root("cp '$fromCCPreferences' '$preferencesDirFile'");



# HARDY version
#     my $bakFile = $preferences . '.ebox.bak';  # file to store 'old' prefrences
#     if (not -e $bakFile) {
#         if (-e $preferences) {
#             EBox::Sudo::root("mv '$preferences' '$bakFile'");
#         } else {
#             EBox::Sudo::root("touch '$bakFile'"); # create a empty preferences
#                                                   # file to make ebox-software
#                                                   # easier to revert configuration
#         }
#     }


#     EBox::Sudo::root("cp '$preferencesFile' '$preferences'");
}

# Get the repository IP address
sub _repositoryAddr
{
    my ($self, $confKeys) = @_;

    my $retVal = '';
    my $rs = EBox::Global->modInstance('remoteservices');
    if ( $rs->isConnected() ) {
        $retVal = $self->_queryServicesNameserver($confKeys->{repositoryHost},
                                                  [$confKeys->{'dnsServer'}]);
    } else {
        $retVal = $confKeys->{repositoryAddress};
    }

    return $retVal;
}

# Remove QA updates
sub _removeQAUpdates
{
    my ($self) = @_;

    $self->_removeAptQASources();
    $self->_removeAptPubKey();
    $self->_removeAptQAPreferences();

    my $softwareMod = EBox::Global->modInstance('software');
    if ($softwareMod) {
        if ( $softwareMod->can('setQAUpdates') ) {
            $softwareMod->setQAUpdates(0);
        }
    }
}

sub _removeAptQASources
{
    my $path = EBox::RemoteServices::Configuration::aptQASourcePath();
    EBox::Sudo::root("rm -f '$path'");
}

sub _removeAptPubKey
{
    my $id = 'ebox-qa';
    try {
        EBox::Sudo::root("apt-key del $id");
    } otherwise {
        EBox::error("Removal of apt-key $id failed. Check it and if it exists remove it manually");
    }

}

sub _removeAptQAPreferences
{
    my $path = '/etc/apt/preferences';
    my $back = $path . 'ebox.bak';
    EBox::Sudo::root("rm -f '$path'");
    if (-e $back) {
        EBox::Sudo::root("mv '$back' '$path'");
    }
}

# Check if the ebox-cloud-prof is already installed
sub _cloudProfInstalled
{
    my $installed = 0;
    my $cache = new AptPkg::Cache();
    if ( $cache->exists(PROF_PKG) ) {
        my $pkg = $cache->get(PROF_PKG);
        $installed = ( $pkg->{SelectedState} == AptPkg::State::Install
                       and $pkg->{InstState} == AptPkg::State::Ok
                       and $pkg->{CurrentState} == AptPkg::State::Installed );
    }
    return $installed;
}

# Check the Web Services connectivity
sub _checkWSConnectivity
{

    my $host = EBox::RemoteServices::Configuration::PublicWebServer();
    $host or throw EBox::Exceptions::External('WS key not found');

    my $counter = EBox::RemoteServices::Configuration::eBoxServicesMirrorCount();
    $counter or throw EBox::Exceptions::Internal('Mirror count not found');

    my $proto = 'tcp';
    my $port = 443;

    my $ok;
    foreach my $no ( 1 .. $counter ) {
        my $site = $host;
        $site =~ s:\.:$no.:;
        try {
            $ok = _checkHostPort($host, $proto, $port);
        } catch EBox::Exceptions::External with {
            $ok = 0;
        };
        last if ($ok);
    }

    if (not $ok) {
        throw EBox::Exceptions::External(
            __x(
                'Could not connect to WS server "{addr}:{port}/{proto}". '
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

    my $ok = 0;
    if ( $proto eq 'tcp' ) {
        $ok = _checkHostPort($host, $proto, $port);
    } else {
        # UDP nmap is not working with routing in default table
        # instead of main table so we use Net::Ping
        $ok = $self->_checkUDPService($host, $proto, $port);
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

# Check given host and port is reachable using nmap tool
sub _checkHostPort
{
    my ($host, $proto, $port) = @_;
    my $res = EBox::RemoteServices::Nmap::singlePortScan(
                                                         host => $host,
                                                         protocol => $proto,
                                                         port => $port,
                                                        );
    if ($res eq 'open') {
        return 1;
    }

    if ($res eq 'open/filtered') {
        # in UDP packets this could be open or not. We treat this as open to
        # avoid false negatives (but we will have false positives)
        return 1;
    }
    return 0;
}

# Check UDP service using Net::Ping
sub _checkUDPService
{
    my ($self, $host, $proto, $port) = @_;

    my $p = new Net::Ping($proto, 3);
    $p->port_number($port);
    $p->service_check(1);
    my @result = $p->ping($host);

    # Timeout reaches, if the service was down, then the
    # timeout is zero. If the host is available and this check
    # is done before this one
    return ( $result[1] == 3 );

}

1;
