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
#       Class to manage the eBox subscription to the eBox remote
#       services
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

use Archive::Tar;
use Cwd;
use Error qw(:try);
use File::Slurp;
use File::Temp;

# Constants
use constant {
    SERV_CONF_DIR => 'remoteservices',
    SERV_SUBDIR => 'remoteservices/subscription',
    SERV_CONF_FILE => '78remoteservices.conf',
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


    $self->_setQAUpdates($params);

    $self->_executeBundleScripts($params);

    $params->{new} = $new;
    return $params;

}


sub _setQAUpdates
{
    my ($self, $params) = @_;

    my @paramsNeeded = qw(QASources QAAptPubKey QAAptPreferences);
    foreach my $param (@paramsNeeded) {
        exists $params->{$param} or
            return;
    }

    
    $self->setQASources($params->{QASources});
    $self->setQAAptPubKey($params->{QAAptPubKey});
    $self->setQAAptPreferences($params->{QAAptPreferences});

    my $softwareMod = EBox::Global->modInstance('software');
    if ($softwareMod) {
        $softwareMod->setQAUpdates(1);
    } else {
        EBox::info('No software module installed QA updates should be doen by hand');
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
        } catch EBox::Exceptions::Command with {
            # ignore script errors
        };
    }
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

    my ($confFile, $keyFile, $certFile, $qaSources, $qaGpg, $qaPreferences);
    my @scripts;
    foreach my $filePath (@files) {
        $tar->extract_file($filePath)
          or throw EBox::Exceptions::Internal("Cannot extract file $filePath");
        if ( $filePath =~ m:\.conf$: ) {
            $confFile = $filePath;
        } elsif ( $filePath =~ m:$cn: ) {
            $keyFile = $filePath;
        } elsif ($filePath =~ /ebox-qa\.list$/) {
            $qaSources = $filePath;
        } elsif ($filePath =~ /ebox-qa\.pub$/) {
            $qaGpg = $filePath;
        } elsif ($filePath =~ /ebox-qa\.preferences$/) {
            $qaPreferences = $filePath;
        } elsif ($filePath =~ m{exec\-\d+\-}) {
            push @scripts, $filePath;
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
    


    if (@scripts) {
        # order by number
        @scripts = sort @scripts;
        @scripts = map { "$dirPath/$_" } @scripts;
        $bundle->{scripts}  = \@scripts;

    }


    return $bundle;
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


sub setQASources
{
    my ($self, $qaFile) = @_;
    my $destination = EBox::RemoteServices::Configuration::aptQASourcePath();
    EBox::Sudo::root("cp '$qaFile' '$destination'");
    my $ubuntuVersion = _ubuntuVersion();
    my $archive = 'ebox-qa-' . $ubuntuVersion;
    EBox::Sudo::root("sed -i 's/ebox-qa/$archive/' '$destination'");
}



sub _ubuntuVersion
{
    my @eboxInfo = `dpkg -s ebox`;
    foreach my $line (@eboxInfo) {
        if (not $line =~ m/Version:/) {
            next;
        }

        chomp $line;
        my ($header, $version) = split ':', $line;
        $version =~ /^\s*(\d+\.\d+)/;
        my $versionNumber = $1;
        if ($versionNumber >= 1.5) {
            return 'lucid';
        } else {
            return 'hardy';
        }
    }
    

    die 'hardy';
    return 'hardy';
}


sub setQAAptPubKey
{
    my ($self, $keyFile) = @_;
    my $destination = EBox::RemoteServices::Configuration::aptQASourcePath();
#    EBox::debug("apt-key add $keyFile");
    
    EBox::Sudo::root("apt-key add $keyFile");
}



sub setQAAptPreferences
{
    my ($self, $preferencesFile) = @_;

    my $exclusiveSource = EBox::Config::configkey('qa_updates_exclusive_source');
    if (lc($exclusiveSource) ne 'true') {
        return;
    }


    my $preferences = '/etc/apt/preferences';
    my $fromCCPreferences = $preferences . '.ebox.fromcc'; # file to store CC preferences
    my $bakFile = $preferences . '.ebox.bak';  # file to store 'old' prefrences
    if (not -e $bakFile) {
        if (-e $preferences) {
            EBox::Sudo::root("mv '$preferences' '$bakFile'");
        } else {
            EBox::Sudo::root("touch '$bakFile'"); # create a empty preferences
                                                  # file to make ebox-software
                                                  # easier to revert configuration 
        }
    }

    EBox::Sudo::root("cp '$preferencesFile' '$fromCCPreferences'");
    EBox::Sudo::root("cp '$preferencesFile' '$preferences'");
}

1;
