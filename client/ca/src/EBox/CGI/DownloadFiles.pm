# Copyright (C) 2006 Warp Networks S.L.
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

package EBox::CGI::CA::DownloadFiles;

# CGI to download key pair and certificates from a specific user or
# to download public key and certificate from Certification Authority

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

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

    my $self = $class->SUPER::new('title'    => __('Certification Authority Management'),
				  @_);

    $self->{domain} = "ebox-ca";
    # To download something, we need errorchain
    $self->{errorchain} = "CA/Index";
    bless($self, $class);

    return $self;

  }

# Process the HTTP query

sub _process
  {

    my $self = shift;

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
    }

    my $zipfile;
    if ( $metaDataCert->{"isCACert"} ) {
      $zipfile = EBox::Config->tmp() . "CA-key-and-cert.tar.gz";
    } else {
      $zipfile = EBox::Config->tmp() . "keys-and-cert-" . $self->{cn} . ".tar.gz";
    }

    unlink($zipfile);
    # We make symbolic links in order to make dir-plained tar file
    my ($linkPrivate, $linkPublic, $linkCert);
    if ( $metaDataCert->{"isCACert"} ) {
      $linkPublic = "ca-public-key.pem";
      $linkCert = "ca-cert.pem";
    } else {
      $linkPrivate = $self->{cn} . "-private-key.pem";
      $linkPublic  = $self->{cn} . "-public-key.pem";
      $linkCert    = $self->{cn} . "-cert.pem";
    }

    link($files->{privateKey}, EBox::Config->tmp() . $linkPrivate)
      if (EBox::Config->tmp() . $linkPrivate);
    link($files->{publicKey}, EBox::Config->tmp() . $linkPublic);
    link($files->{certificate}, EBox::Config->tmp() . $linkCert);

    my $tarArgs = qq{'$zipfile' };
    $tarArgs .= qq{'$linkPrivate' } if ( $linkPrivate );
    $tarArgs .= qq{'$linkPublic' '$linkCert'};
    # -h to dump what links point to
    my $ret = system("cd " . EBox::Config->tmp() . '; tar cvzhf ' . $tarArgs);

    unlink(EBox::Config->tmp() . $linkPrivate) if ($linkPrivate);
    unlink(EBox::Config->tmp() . $linkPublic);
    unlink(EBox::Config->tmp() . $linkCert);
    if ($ret != 0) {
      throw EBox::Exceptions::External(__("Error creating file") . ": $!");
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
    my $self = shift;

    if ($self->{error} or not defined($self->{downfile})) {
      $self->SUPER::_print;
      return;
    }

    open( my $keyFile, $self->{downfile} )
      or throw EBox::Exceptions::Internal("Could NOT open key file.");

    print($self->cgi()->header(-type => 'application/octet-stream',
			       -attachment => $self->{downfilename}));

    while(<$keyFile>) {
      print $_;
    }

    close($keyFile);


  }

1;
