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

package EBox::CA::CGI::DownloadFiles;

use base 'EBox::CGI::ClientBase';
# CGI to download key pair and certificates from a specific user or
# to download public key and certificate from Certification Authority

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;

# Method: new
#
#       Constructor for DownloadFiles CGI
#
# Returns:
#
#       DownloadFiles - The object recently created
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new('title' => __('Certification Authority'),
                                  @_);

    # To download something, we need errorchain
    $self->{errorchain} = 'CA/Index';
    bless($self, $class);

    return $self;
}

# Process the HTTP query

sub _process
{
    my ($self) = @_;

    $self->{ca} = EBox::Global->modInstance('ca');

    # Check if the CA infrastructure has been created
    my @array = ();

    $self->{cn} = $self->unsafeParam('cn');
    # We have to check it manually if it exists
    if ( not defined($self->{cn}) or ($self->{cn} eq "") ) {
        throw EBox::Exceptions::DataMissing(data => __('Common Name'));
    }

    # Transform %40 in @
    $self->{cn} =~ s/%40/@/g;
    # Transform %20 in space
    $self->{cn} =~ s/%20/ /g;

    my $metaDataCert = $self->{ca}->getCertificateMetadata( cn => $self->{cn});
    if (not defined($metaDataCert) ) {
        throw EBox::Exceptions::External(__x("Common name: {cn} does NOT exist in database"
                    , cn => $self->{cn}));
    }

    my $files = {};
    # If it is the CA certificate, only possibility to download Public Key and certificate
    if ($metaDataCert->{"isCACert"}) {
        $files->{publicKey}   = $self->{ca}->CAPublicKey();
        $files->{certificate} = $self->{ca}->getCACertificateMetadata()->{path};
    } else {
        $files = $self->{ca}->getKeys($self->{cn});
        $files->{certificate} = $self->{ca}->getCertificateMetadata(cn => $self->{cn})->{path};
        $files->{p12}         = $self->{ca}->getP12KeyStore($self->{cn});
    }

    my $zipfile;
    if ( $metaDataCert->{"isCACert"} ) {
        $zipfile = EBox::Config->tmp() . "CA-key-and-cert.zip";
    } else {
        $zipfile = EBox::Config->tmp() . "keys-and-cert-" . $self->{cn} . ".zip";
    }

    unlink($zipfile);
    # We make symbolic links in order to make dir-plained tar file
    my ($linkPrivate, $linkPublic, $linkCert, $linkP12);
    if ( $metaDataCert->{"isCACert"} ) {
        $linkPublic = "ca-public-key.pem";
        $linkCert = "ca-cert.crt";
    } else {
        $linkPrivate = $self->{cn} . "-private-key.pem";
        $linkPublic  = $self->{cn} . "-public-key.pem";
        $linkCert    = $self->{cn} . "-cert.crt";
        $linkP12     = $self->{cn} . ".p12";
    }

    link($files->{privateKey}, EBox::Config->tmp() . $linkPrivate)
        if ($linkPrivate);
    link($files->{publicKey}, EBox::Config->tmp() . $linkPublic);
    link($files->{certificate}, EBox::Config->tmp() . $linkCert);
    link($files->{p12}, EBox::Config->tmp() . $linkP12)
        if ($linkP12);

    my $zipArgs = qq{'$zipfile'};
    my @toRemove;
    foreach my $file ($linkPrivate, $linkPublic, $linkCert, $linkP12) {
        if (not $file) {
            next;
        }
        my $path =  EBox::Config::tmp() . $file;
        push @toRemove, $path;
        $zipArgs .= qq{ '$path'};
    }

    my $cmd = "/usr/bin/zip -j $zipArgs";
    my $ret = system($cmd);
    my $perror = $!;
    unlink @toRemove;

    if ($ret != 0) {
        throw EBox::Exceptions::External(
            __x("Error creating archive file for  certificates: {err}", err => $perror)
           );
    }

    # Setting the file
    $self->{downfile} = $zipfile;
    # Remove trailing slashes, only name
    $zipfile =~ s/^.+\///;
    $self->{downfilename} = $zipfile;
}

# Overwrite the _print method to send the file
sub _print
{
    my ($self) = @_;

    if ($self->{error} or not defined($self->{downfile})) {
        $self->SUPER::_print;
        return;
    }

    open (my $fh, "<:raw", $self->{downfile}) or
        throw EBox::Exceptions::Internal('Could NOT open key file.');
    Plack::Util::set_io_path($fh, Cwd::realpath($self->{downfile}));

    my $response = $self->response();
    $response->status(200);
    $response->content_type('application/octet-stream');
    $response->header('Content-Disposition' => 'attachment; filename="' . $self->{downfilename} . '"');
    $response->body($fh);
}

1;
