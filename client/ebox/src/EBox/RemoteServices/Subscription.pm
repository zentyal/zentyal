# Copyright (C) 2008 Warp Networks S.L.
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
use EBox::Exceptions::Internal;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Configuration;

use Archive::Tar;
use Cwd;
use Error qw(:try);
use File::Slurp;
use File::Temp;

# Constants
use constant {
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

    my $bundleContent;
    my $new = 0;
    try {
        $bundleContent = $self->soapCall('subscribeEBox', canonicalName => $cn);
        $new = 1;
    } catch EBox::Exceptions::DataExists with {
        $bundleContent = $self->soapCall('eBoxBundle', canonicalName => $cn);
        $new = 0;
    };

    my $tmp = new File::Temp(TEMPLATE => 'servicesXXXX',
                             DIR      => EBox::Config::tmp(),
                             SUFFIX   => '.tar.gz');

    File::Slurp::write_file($tmp->filename(), $bundleContent);

    my $tar = new Archive::Tar($tmp->filename(), 1);
    my @files = $tar->list_files();
    my $cwd = Cwd::getcwd();

    my $dirPath = EBox::Config::conf() . SERV_SUBDIR;
    unless (chdir($dirPath)) {
        mkdir($dirPath);
        chdir($dirPath);
    }
    $dirPath .= "/$cn";
    unless (chdir($dirPath)) {
        mkdir($dirPath);
        chdir($dirPath);
    }
    my ($confFile, $keyFile, $certFile);
    foreach my $filePath (@files) {
        $tar->extract_file($filePath)
          or throw EBox::Exceptions::Internal("Cannot extract file $filePath");
        if ( $filePath =~ m:\.conf$: ) {
            $confFile = $filePath;
        } elsif ( $filePath =~ m:$cn: ) {
            $keyFile = $filePath;
        } elsif ( $filePath ne 'cacert.pem' ) {
            $certFile = $filePath;
        }
    }

    my $confKeys = EBox::Config::configKeysFromFile("$dirPath/$confFile");
    $self->_openVPNandCloseHTTPSConnection(
        $confKeys->{vpnIPAddr},
        $confKeys->{vpnPort},
       );

    # Remove everything we created before
    unlink($tmp->filename());

    return {
        ca => "$dirPath/cacert.pem",
        cert => "$dirPath/$certFile",
        key => "$dirPath/$keyFile",
        confFile => "$dirPath/$confFile",
        new => $new,
    };

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
            my $output = EBox::Iptables::pf('-L ointernal');
            my $matches = scalar(grep { $_ =~ m/dpt:https/g } @{$output});
            if ( $matches < $mirrorCount ) {
                foreach my $no ( 1 .. $mirrorCount ) {
                    my $site = EBox::RemoteServices::Configuration::PublicWebServer();
                    $site =~ s:\.:$no.:;
                    EBox::Iptables::pf(
                        "-A ointernal -p tcp -d $site --dport 443 -j ACCEPT"
                       );
                }
                my $dnsServer = EBox::RemoteServices::Configuration::DNSServer();
                EBox::Iptables::pf(
                    "-A ointernal -p udp -d $dnsServer --dport 53 -j ACCEPT"
                   );
            }
        }
    }

}

# Close down HTTPS connections and open up VPN one
sub _openVPNandCloseHTTPSConnection #(ipaddr, port)
{
    my ($self, $ipAddr, $port) = @_;

    my $gl = EBox::Global->getInstance();
    if ( $gl->modExists('firewall') ) {
        my $fw = $gl->modInstance('firewall');
        if ( $fw->isEnabled() ) {
            eval "use EBox::Iptables";
            my $output = EBox::Iptables::pf('-L ointernal');
            my $mirrorCount = EBox::RemoteServices::Configuration::eBoxServicesMirrorCount();
            my $matches = scalar(grep { $_ =~ m/dpt:https/g } @{$output});
            if ( $matches >= $mirrorCount ) {
                foreach my $no ( 1 .. $mirrorCount ) {
                    my $site = EBox::RemoteServices::Configuration::PublicWebServer();
                    $site =~ s:\.:$no.:;
                    EBox::Iptables::pf(
                        "-D ointernal -p tcp -d $site --dport 443 -j ACCEPT"
                       );
                }
                my $dnsServer = EBox::RemoteServices::Configuration::DNSServer();
                EBox::Iptables::pf(
                    "-D ointernal -p udp -d $dnsServer --dport 53 -j ACCEPT"
                   );
            }
            # We assume UDP
            EBox::Iptables::pf(
                "-A ointernal -p udp -d $ipAddr --dport $port -j ACCEPT"
               );
        }
    }
}


1;
