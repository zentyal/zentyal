# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::CA::Certificates;

use base qw(EBox::CA::Observer);

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::Internal;

use File::Temp qw(tempfile);

# Group: Public methods

# Constructor: new
#
#      Create the new CA Certificates model
#
# Returns:
#
#      <EBox::CA::Certificates> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = {};

    bless($self, $class);

    return $self;
}

# Method: genCerts
#
#      Generates all the certificates requested by all the services
#
sub genCerts
{
    my ($self) = @_;

    my @srvscerts = @{$self->srvsCerts()};
    foreach my $srvcert (@srvscerts) {
        $self->_genCert($srvcert);
    }
}

# Method: certificateRevoked
#
# Overrides:
#
#      <EBox::CA::Observer::certificateRevoked>
#
sub certificateRevoked
{
    my ($self, $commonName, $isCACert) = @_;

    my $ca = EBox::Global->modInstance('ca');
    my $model = $ca->model('Certificates');

    return $model->certUsedByService($commonName);
}

# Method: certificateRenewed
#
# Overrides:
#
#      <EBox::CA::Observer::certificateRenewed>
#
sub certificateRenewed
{
    my ($self) = @_;

    $self->genCerts(); #FIXME only regen renewed certs
}

# Method: certificateExpired
#
# Overrides:
#
#      <EBox::CA::Observer::certificateExpired>
#
sub certificateExpired
{
    my ($self, $commonName, $isCACert) = @_;

    my $ca = EBox::Global->modInstance('ca');
    my $model = $ca->model('Certificates');

    my @srvscerts = @{$self->srvsCerts()};
    foreach my $srvcert (@srvscerts) {
        my $serviceId = $srvcert->{'serviceId'};
        my $cn = $model->cnByService($serviceId);
        if ($cn eq $commonName) {
            $model->disableService($serviceId);
        }
    }
}

# Method: freeCertificate
#
# Overrides:
#
#      <EBox::CA::Observer::freeCertificate>
#
sub freeCertificate
{
    my ($self, $commonName) = @_;

    my $ca = EBox::Global->modInstance('ca');
    my $model = $ca->model('Certificates');

    my @srvscerts = @{$self->srvsCerts()};
    foreach my $srvcert (@srvscerts) {
        my $serviceId = $srvcert->{'serviceId'};
        my $cn = $model->cnByService($serviceId);
        if ($cn eq $commonName) {
            $model->disableService($serviceId);
        }
    }
}

# Method: srvsCerts
#
#      All services which request a certificate as provided
#      by EBox::Module::Service::certificates() plus the
#      module they are from.
#
# Returns:
#
#       A ref to array with all the services information
#
sub srvsCerts
{
    my ($self) = @_;

    my @srvscerts;
    my @mods = @{$self->_modsService()};
    for my $mod (@mods) {
        my @modsrvs = @{EBox::Global->modInstance($mod)->certificates()};
        next unless @modsrvs;
        for my $srv (@modsrvs) {
            $srv->{serviceId} or next;
            $srv->{module} = $mod;
            push(@srvscerts, $srv);
        }
    }
    return \@srvscerts;
}

# Group: Public methods

# Method: _genCert
#
#      Generates the certificate for a service
#
sub _genCert
{
    my ($self, $srvcert) = @_;

    my $ca = EBox::Global->modInstance('ca');
    my $model = $ca->model('Certificates');

    my $serviceId = $srvcert->{'serviceId'};
    return undef unless ($model->isEnabledService($serviceId));

    my $cn = $model->cnByService($serviceId);
    return undef unless (defined($cn));

    my $certMD = $ca->getCertificateMetadata(cn => $cn);
    if ((not defined($certMD)) or ($certMD->{state} ne 'V')) {
        # Check the expiration date
        my $caMD = $ca->getCACertificateMetadata();
        $ca->issueCertificate(
            commonName => $cn,
            endDate => $caMD->{expiryDate},
        );
    }

    my $cert = $ca->getCertificateMetadata(cn => $cn)->{'path'};
    my $privkey = $ca->getKeys($cn)->{'privateKey'};

    my ($tempfile_fh, $tempfile) = tempfile(EBox::Config::tmp . "/ca_certificates_XXXXXX") or
        throw EBox::Exceptions::Internal("Could not create temporal file.");

    open(my $CERT, $cert) or throw EBox::Exceptions::Internal('Could not open certificate file.');
    my @certdata = <$CERT>;
    close($CERT);
    open(my $KEY, $privkey) or throw EBox::Exceptions::Internal('Could not open certificate file.');
    my @privkeydata = <$KEY>;
    close($KEY);

    print $tempfile_fh @certdata;
    print $tempfile_fh @privkeydata;

    if ($srvcert->{includeCA}) {
        open(my $CA_CERT, $ca->CACERT) or throw EBox::Exceptions::Internal('Could not open CA certificate file.');

        my @caData = <$CA_CERT>;
        close $CA_CERT;

        print $tempfile_fh @caData;
    }

    close($tempfile_fh);

    my @commands;

    my $user = $srvcert->{'user'};
    my $group = $srvcert->{'group'};
    push (@commands, "/bin/chown $user:$group $tempfile");

    my $mode = $srvcert->{'mode'};
    push (@commands, "/bin/chmod $mode $tempfile");

    my $path = $srvcert->{'path'};
    push (@commands, "mkdir -p `dirname $path`");
    push (@commands, "mv -f $tempfile $path");

    EBox::Sudo::root(@commands);
}

# Method: _modsService
#
#      All configured service modules (EBox::Module::Service)
#      which could be implmenting the certificates method.
#
# Returns:
#
#       A ref to array with all the Module::Service names
#
sub _modsService
{
    my ($self) = @_;

    my @names = @{EBox::Global->modInstancesOfType('EBox::Module::Service')};

    my @mods;
    foreach my $name (@names) {
       $name->configured() or next;
       push (@mods, $name->name());
    }
    return \@mods;
}

1;
