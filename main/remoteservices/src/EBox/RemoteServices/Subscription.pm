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

package EBox::RemoteServices::Subscription;

# Class: EBox::RemoteServices::Subscription
#
#       Class to manage the Zentyal subscription to Zentyal Cloud
#

use base 'EBox::RemoteServices::Base';

use strict;
use warnings;

use feature qw(switch);

use EBox::Config;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Configuration;
use EBox::RemoteServices::RESTClient;
use EBox::RemoteServices::Subscription::Check;
use EBox::Sudo;
use EBox::Util::Nmap;

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
    SERV_CONF_FILE => 'remoteservices.conf',
    PROF_PKG       => 'zentyal-cloud-prof',
    SEC_UPD_PKG    => 'zentyal-security-updates',
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

  # Avoid IP resolution to make it more flexible (Workaround)
  $conn->proxy('https://' . $self->serviceHostName() . '/soap' . $self->_urlSuffix() );

  return $conn->$method(
                        user      => $self->{user},
                        password  => $self->{password},
                        @params
                       );
}

# Method: subscribeEBox
#
#      Given a name trying to subscribe a server for that user using
#      that name. If it is already registered, the process will
#      fail. If the process works nicely, a bundle is got which is
#      used to set the parameters to connect to the Zentyal Cloud
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
#        availableEditions - Array ref containing the available options
#                            to subscribe your server, if this value is set
#                            then we do not have subscribed yet
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if the compulsory
#      argument is missing
#
sub subscribeEBox
{
    my ($self, $cn, $option) = @_;

    $cn or throw EBox::Exceptions::MissingArgument('cn');

    # Ensure firewall rules are opened
    $self->_openHTTPSConnection();

    # Check the WS is reachable
    $self->_checkWSConnectivity();

    $option = undef if ( $option eq 'reload' );

    if (not $option) {
        my $availables = $self->_getAvailable($cn);

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

    my $vpnSettings;
    try {
        $vpnSettings = $self->soapCall('vpnSettings',
                                       option => $option);
    } catch EBox::Exceptions::DataNotFound with { };
    unless ( defined($vpnSettings) ) {
        throw EBox::Exceptions::External(
            __x(
                'Cannot retrieve VPN settings needed for subscription. Check your {openurl}{brand} profile{closeurl} to check your VPN server settings.',
                brand    => 'Zentyal Cloud',
                openurl  => q{<a href='https://remote.zentyal.com/services/profile/'>},
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
    my $rs = EBox::Global->modInstance('remoteservices');
    try {
        $bundleRawData = $self->soapCall('subscribeEBox',
                                         canonicalName => $cn,
                                         rsVersion     => $rs->version(),
                                         option        => $option);
        $new = 1;
    } catch EBox::Exceptions::DataExists with {
        $bundleRawData = $self->soapCall('eBoxBundle',
                                         canonicalName => $cn,
                                         rsVersion     => $rs->version(),
                                         option        => $option);
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
        } elsif ($filePath =~ /ebox-qa\.preferences/) {
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
#        - Downgrade, if necessary
#        - Create John home directory (Security audit)
#        - Set QA updates (QA repository and its preferences)
#        - Autoconfigure DynamicDNS service
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

    # Downgrade, if necessary
    $self->_downgrade($params);
    $self->_setUpAuditEnvironment();
    $self->_setQAUpdates($params, $confKeys);
    $self->_setDDNSConf();
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

    # Remove subscription levels and disaster recovery if any
    my $rs = EBox::Global->modInstance('remoteservices');
    $rs->st_unset('admin_port');
    $rs->st_delete_dir('subscription');
    $rs->st_delete_dir('disaster_recovery');

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
        return unless (exists $params->{$param});
    }

    $self->_setQASources($params->{QASources}, $confKeys);
    $self->_setQAAptPubKey($params->{QAAptPubKey});
    $self->_setQAAptPreferences($params->{QAAptPreferences});
    $self->_setQARepoConf($confKeys);

    my $softwareMod = EBox::Global->modInstance('software');
    if ($softwareMod) {
        if ( $softwareMod->can('setQAUpdates') ) {
            $softwareMod->setQAUpdates(1);
        }
    } else {
        EBox::info('No software module installed QA updates should be done by hand');
    }

}

# Set the Dynamic DNS configuration only if the service was not
# enabled before and using other method
sub _setDDNSConf
{
    my ($self) = @_;

    my $networkMod = EBox::Global->modInstance('network');
    unless ( $networkMod->isDDNSEnabled() ) {
        my $ddnsModel = $networkMod->model('DynDNS');
        $ddnsModel->set(enableDDNS => 1,
                        service    => 'cloud');
    } else {
        EBox::info('DynDNS is already in used, so not using Zentyal Cloud service');
    }
}

# Install zentyal-cloud-prof package in a hour to avoid problems with dpkg
sub _installCloudProf
{
    my ($self, $params, $confKeys) = @_;

    return unless ( exists $params->{installCloudProf} );

    if ( $self->_pkgInstalled(PROF_PKG) ) {
        # Remove any at command from user to avoid removing pkg using at
        my $user = EBox::Config::user();
        my $queuedJobs = EBox::Sudo::rootWithoutException("atq | grep $user");
        if (@{$queuedJobs} > 0) {
            # Delete them
            my @jobIds = map { m/^([0-9]+)\s/ } @{$queuedJobs};
            EBox::Sudo::root('atrm ' . join(' ', @jobIds));
        }
        return;
    }

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    $fh->unlink_on_destroy(0);
    print $fh "exec " . $params->{installCloudProf} . " \n";
    close($fh);

    try {
        EBox::Sudo::command("chmod a+x '" . $params->{installCloudProf} . "'");
        # Delay the ebox-cloud-prof installation for an hour
        EBox::Sudo::command('at -f "' . $fh->filename() . '" now+1hour');
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
    my $archive = $self->_archive($ubuntuVersion);
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
    EBox::Sudo::root("install -m 0644 '$tmpFile' '$destination'");
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

# Get the QA archive to look
sub _archive
{
    my ($self, $ubuntuVersion) = @_;

    return "zentyal-qa-$ubuntuVersion";

}

# Get the suite of archives to set preferences
sub _suite
{
    return 'zentyal-qa';
}

# Set the QA apt repository public key
sub _setQAAptPubKey
{
    my ($self, $keyFile) = @_;
    EBox::Sudo::root("apt-key add $keyFile");
}

sub _setQAAptPreferences
{
    my ($self, $preferencesTmpl) = @_;

    my $preferences = '/etc/apt/preferences';
    my $fromCCPreferences = $preferences . '.zentyal.fromzc'; # file to store CC preferences

    # Perform the mason template manually since it is not stored in stubs directory
    my $output;
    my $interp = new HTML::Mason::Interp(out_method => \$output);
    my $comp   = $interp->make_component(comp_file  => $preferencesTmpl);
    $interp->exec($comp, ( (archive => $self->_suite() )));

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    my $tmpFile = $fh->filename();
    File::Slurp::write_file($tmpFile, $output);

    EBox::Sudo::root("cp '$tmpFile' '$fromCCPreferences'");

    my $exclusiveSource = EBox::Config::configkey('qa_updates_exclusive_source');
    if (lc($exclusiveSource) ne 'true') {
        return;
    }

    my $preferencesDirFile = EBox::RemoteServices::Configuration::aptQAPreferencesPath();
    EBox::Sudo::root("install -m 0644 '$fromCCPreferences' '$preferencesDirFile'");
}

# Set not to use HTTP proxy for QA repository
sub _setQARepoConf
{
    my ($self, $confKeys) = @_;

    my $repoAddr = $self->_repositoryAddr($confKeys);
    EBox::Module::Base::writeConfFileNoCheck(EBox::RemoteServices::Configuration::aptQAConfPath(),
                                             '/remoteservices/qa-conf.mas',
                                             [ repoAddr => $repoAddr ]);
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
    $self->_removeAptQAConf();

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
    };
}

sub _removeAptQAPreferences
{
    my $path = '/etc/apt/preferences.zentyal.fromzc';
    EBox::Sudo::root("rm -f '$path'");
    $path = EBox::RemoteServices::Configuration::aptQAPreferencesPath();
    EBox::Sudo::root("rm -f '$path'");
}

sub _removeAptQAConf
{
    my $path = EBox::RemoteServices::Configuration::aptQAConfPath();
    EBox::Sudo::root("rm -f '$path'");
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

    my $host = EBox::RemoteServices::Configuration::PublicWebServer();
    $host or throw EBox::Exceptions::External('WS key not found');

    my $counter = EBox::RemoteServices::Configuration::eBoxServicesMirrorCount();
    $counter or
        throw EBox::Exceptions::Internal('Mirror count not found');

    # TODO: Use the network module API
    my $network    = EBox::Global->modInstance('network');
    my $proxyModel = $network->model('Proxy');
    my $proxy      = $proxyModel->serverValue();
    my $proxyPort  = $proxyModel->portValue();
    my $proxyUser  = $proxyModel->usernameValue();
    my $proxyPass  = $proxyModel->passwordValue();

    my $proto = 'tcp';
    my $port = 443;

    my $ok;
    foreach my $no (1 .. $counter) {
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
            my $output = EBox::Sudo::root($cmd);
            foreach my $line (@{ $output }) {
                if ($line =~ m/A prudent question is one-half of wisdom/) {
                    $ok =1;
                    last;
                }
            }
        } catch EBox::Exceptions::External with {
            $ok = 0;
        };
        last if ($ok);
    }

    unless ($ok) {
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
    my $skip = EBox::Config::configkey('subscription_skip_vpn_scan');
    if ($skip eq 'true') {
        return;
    }

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

# Check UDP echo service using Net::Ping
sub _checkUDPEchoService
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

# Downgrade current subscription, if necessary
# Things to be done:
#   * Remove QA updates configuration
#   * Uninstall zentyal-cloud-prof and zentyal-security-updates packages
#
sub _downgrade
{
    my ($self, $params) = @_;

    my @paramsNeeded = qw(QASources QAAptPubKey QAAptPreferences);
    my $nParamsNeeded = grep { exists $params->{$_} } @paramsNeeded;
    if ( $nParamsNeeded < scalar(@paramsNeeded) ) {
        if ( -f EBox::RemoteServices::Configuration::aptQASourcePath()
            or -f EBox::RemoteServices::Configuration::aptQAPreferencesPath() ) {
            # Requires to downgrade
            $self->_removeQAUpdates();
        }
        $self->_removePkgs();
    }
}

# Remove private packages
sub _removePkgs
{
    my ($self) = @_;

    # Remove pkgs using at to avoid problems when doing so from Zentyal UI
    my @pkgs = (PROF_PKG, SEC_UPD_PKG);
    @pkgs = grep { $self->_pkgInstalled($_) } @pkgs;

    return unless ( @pkgs > 0 );

    my $fh = new File::Temp(DIR => EBox::Config::tmp());
    $fh->unlink_on_destroy(0);
    print $fh 'exec ' . REMOVE_PKG_SCRIPT . ' ' . join(' ', @pkgs) . "\n";
    close($fh);

    try {
        EBox::Sudo::command('at -f "' . $fh->filename() . '" now+1hour');
    } catch EBox::Exceptions::Command with {
        my ($exc) = @_;
        EBox::debug($exc->stringify());
    };
}

# Get available editions for this user/pass
sub _getAvailable
{
    my ($self, $server) = @_;

    my $client = new EBox::RemoteServices::RESTClient(
        credentials => { username => $self->{user},
                         password => $self->{password}});

    my $response = $client->GET("/v1/bundle/available/$server/");
    return $response->data();

}


1;
