package EBox::OpenVPN::Client;

# Description: Class for modelling each of the OpenVPN servers
use strict;
use warnings;

use base qw(EBox::OpenVPN::Daemon);

use EBox::Validate qw(checkPort checkAbsoluteFilePath checkHost);
use EBox::NetWrappers;
use EBox::Sudo;
use EBox::FileSystem;
use EBox::Gettext;
use EBox::OpenVPN::Client::ValidateCertificate;
use EBox::OpenVPN::Server::ClientBundleGenerator::EBoxToEBox;

use Params::Validate qw(validate_pos SCALAR);
use Error qw(:try);

sub new
{
    my ($class, $row) = @_;

    my $self = $class->SUPER::new($row);
    bless $self, $class;

    return $self;
}

sub type
{
    return 'client';
}

# Method: proto
#
#  Returns:
#    the protocol used by the server
#
sub proto
{
    my ($self) = @_;

    my $config = $self->{row}->subModel('configuration');

    my $portAndProtocol =  $config->serverPortAndProtocolType();
    return $portAndProtocol->protocol();
}

sub _filePath
{
    my ($self, $name) = @_;

    my $conf = $self->{row}->subModel('configuration');
    my $fileFieldAccessor = $name . 'Type';

    my $fileField = $conf->$fileFieldAccessor();
    return $fileField->path();
}

# Method: caCertificate
#
# Returns:
#  returns the path to the CA certificate
sub caCertificate
{
    my ($self) = @_;
    return $self->_filePath('caCertificate');
}

# Method: certificate
#
# Returns:
#  returns the path to the certificate
sub certificate
{
    my ($self) = @_;
    return $self->_filePath('certificate');
}

# Method: certificateKey
#
# Returns:
#  returns the path to the private key
sub certificateKey
{
    my ($self) = @_;
    return $self->_filePath('certificateKey');
}

# Method: privateDir
#
#  gets the private dir used by the client ot store his certificates
#   and keys if it does not exists it will be created
#
# Returns:
#  returns the client's protocol
sub privateDir
{
    my ($self) = @_;
    my $name = $self->name;
    return __PACKAGE__->privateDirForName($name);
}

sub privateDirForName
{
    my ($class, $name) = @_;

    my $openVPNConfDir = $class->_openvpnModule->confDir();
    my $dir = $class->confFileForName($name, $openVPNConfDir) . '.d';

    if (not EBox::Sudo::fileTest('-d', $dir)) {
        if  ( EBox::Sudo::fileTest('-e', $dir) ) {
            throw EBox::Exceptions::Internal(
                                          "$dir exists but is not a directory");
        }

        # create dir if it does not exist
        EBox::Sudo::root("mkdir --mode 0700  $dir");
    }

    return $dir;
}

sub _setPrivateFile
{
    my ($self, $type, $path) = @_;

    if (not EBox::Sudo::fileTest('-r', $path)) {
        throw EBox::Exceptions::Internal('Cannot read private file source');
    }

    my $privateDir = $self->privateDir();

    my $newPath = "$privateDir/$type";

    try {
        EBox::Sudo::root("cp '$path' '$newPath'");
        EBox::Sudo::root("chmod 0400 '$newPath'");
        EBox::Sudo::root("chown 0.0 '$newPath'");
    }
    otherwise {
        EBox::Sudo::root("rm -f '$newPath'");
    };

    $self->setConfString($type, $newPath);

}

# Method: internal
#
#   tell wether the client must been internal for users in the UI or nodaemon
#   is a internal daemon used and created by other EBox services
#
# Returns:
#  returns the daemon's internal state
sub internal
{
    my ($self) = @_;
    return $self->_rowAttr('internal');
}

# Method: daemonFiles
# Override <EBox::OpenVPN::Daemon::daemonFiles> method
sub daemonFiles
{
    my ($class, $name) = @_;

    my @files = $class->SUPER::daemonFiles($name);
    push @files, $class->privateDirForName($name);

    return @files;
}

sub confFileTemplate
{
    my ($self) = @_;
    return "openvpn/openvpn-client.conf.mas";
}

sub confFileParams
{
    my ($self) = @_;
    my @templateParams;

    push @templateParams, (dev => $self->iface);

    my @paramsNeeded =
      qw(name caCertificate certificate certificateKey  user group proto );
    foreach my $param (@paramsNeeded) {
        my $accessor_r = $self->can($param);
        defined $accessor_r or die "Cannot found accessor for param $param";
        my $value = $accessor_r->($self);
        defined $value or next;
        push @templateParams, ($param => $value);
    }

    push @templateParams, (servers =>  $self->servers() );

    return \@templateParams;
}

# Method: servers
#
# gets the servers to which the client will try to connecet
#
# Returns:
#  a reference to the list of server. Each item in the list of
#  servers is a reference to a list which contains the IP address
#  and port of one server
sub servers
{
    my ($self) = @_;

    my $config = $self->{row}->subModel('configuration');

    my $server = $config->server();

    my $portAndProtocol =  $config->serverPortAndProtocolType();
    my $port = $portAndProtocol->port();

    my @servers = ([ $server => $port ]);
    return \@servers;
}

sub ripDaemon
{
    my ($self) = @_;

    # internal client don't need to push routes to the server
    (not $self->internal)
      or return undef;

    $self->service()
      or return undef;

    my $iface = $self->ifaceWithRipPasswd();
    return { iface => $iface, redistribute => 1 };
}

sub ifaceMethodChanged
{
    my ($self, $iface, $oldmethod, $newmethod) = @_;
    if ($newmethod eq 'nonset') {
        return 1 if $self->_availableIfaces() == 1;
    }

    return undef;
}

sub vifaceDelete
{
    my ($self, $iface, $viface) = @_;

    return 1 if $self->_availableIfaces() == 1;
    return undef;
}

sub freeIface
{
    my ($self, $iface) = @_;
    my $ifaces = $self->_availableIfaces();
    if ($ifaces == 1) {
        $self->{row}->elementByName('service')->setValue(0);
        $self->stop() if $self->running();

        EBox::warn("OpenVPN client "
            . $self->name
            . " was deactivated because there is not any network interfaces available"
        );
    }
}

sub freeViface
{
    my ($self, $iface, $viface) = @_;
    $self->freeIface($viface);
}

sub changeIfaceExternalProperty # (iface, external)
{
    my ($self, $iface, $external) = @_;

   # no effect for openvpn clients. Except that the server may not be reacheable
   # anymore but we don't check this in any moment..
    return;
}

sub _availableIfaces
{
    my ($self) = @_;

    my $network = EBox::Global->modInstance('network');
    my @ifaces = @{ $network->ExternalIfaces };

    # XXX it should care of internal ifaces only until we close #391
    push @ifaces, @{ $network->InternalIfaces };

    return scalar @ifaces;
}

sub summary
{
    my ($self) = @_;

    if ($self->internal) { # no summary for internal clients
        return ();
    }

    my @summary;
    push @summary, __x('Client {name}', name => $self->name);

    my $service = $self->service ? __('Enabled') : __('Disabled');
    push @summary,__('Service'), $service;

    my $running = $self->running ? __('Running') : __('Stopped');
    push @summary,__('Daemon status'), $running;

    my $proto   = $self->proto();
    my @servers = @{  $self->servers  };

    # XXX only one server supported now!
    my ($addr, $port) = @{ $servers[0]  };
    my $server = "$addr $port/\U$proto";
    push @summary,__('Connection target'), $server;

    my $ifAddr = $self->ifaceAddress();
    if ($ifAddr) {
        push @summary, (__('VPN interface address'), $ifAddr);
    }else {
        push @summary, (__('VPN interface address'), __('No active'));
    }

    return @summary;
}

sub backupCertificates
{
    my ($self, $dir) = @_;

    my $d = "$dir/" . $self->name;
    EBox::FileSystem::makePrivateDir($d);

    EBox::Sudo::root('cp ' . $self->caCertificate . " $d/caCertificate" );
    EBox::Sudo::root('cp ' . $self->certificate   . " $d/certificate" );
    EBox::Sudo::root('cp ' . $self->certificateKey    . " $d/certificateKey" );
    EBox::Sudo::root("chown ebox.ebox $d/*");
}

sub restoreCertificates
{
    my ($self, $dir) = @_;

    my $d = "$dir/" . $self->name;
    if (not -d $d) {

        # XXX we don't abort to mantain compability with previous bakcup version
        EBox::error(
               'No directory found with saved certificates for client '
              .$self->name
              .'. Current certificates will be left untouched'

        );
        next;

    }

    # before copyng and overwritting files, check if all needed files are valid
    # why? if there is a error is a little less probable we left a
    # unusable state
    my @files = ("$d/caCertificate", "$d/certificate", "$d/certificateKey" );
    EBox::OpenVPN::Client::ValidateCertificate::check("$d/caCertificate",
                                          "$d/certificate","$d/certificateKey");

    # set the files from the backup in the client
    try {
        $self->setCertificateFiles("$d/caCertificate","$d/certificate",
                                   "$d/certificateKey");
    }
    otherwise {
        my $e = shift;
        EBox::error(  'Error restoring certifcates for client '
                    . $self->name
                    .'. Probably the certificates will be  inconsistents');
        $e->throw();
    };

}

sub usesPort
{
    my ($self, $proto, $port, $iface) = @_;

    # openvpn client doesn't listen in any port
    return 0;
}

1;
