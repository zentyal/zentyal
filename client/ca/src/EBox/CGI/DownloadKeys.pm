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

package EBox::CGI::CA::DownloadKeys;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Method: new
#
#       Constructor for DownloadKeys CGI
#
# Returns:
#
#       DownloadKeys - The object recently created

sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title'    => __('Certification Authority Management'),
				  @_);

    $self->{domain} = "ebox-ca";
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

    my $metaDataCert = $self->{ca}->listCertificates( cn => $self->{cn})->[0];
    if (not defined($metaDataCert) ) {
      throw EBox::Exceptions::External(__x("Common name: {cn} does NOT exist in database"
					   , cn => $self->{cn}));
    }

    my $keys = {};
    # If it is the CA certificate, only possibility to download Public Key
    if ($metaDataCert->{"isCACert"}) {
      $keys->{publicKey} = $self->{ca}->CAPublicKey();
    } else {
      $keys = $self->{ca}->getKeys($self->{cn});
    }

    my $zipfile = EBox::Config->tmp() . "keys.tar.gz"
      if ( defined($keys->{privateKey}) );

    if ($zipfile) {
      my $linkPrivate = EBox::Config->tmp() . "private-". $self->{cn} . ".pem";
      my $linkPublic = EBox::Config->tmp() . "public-" . $self->{cn} . ".pem";
      link($keys->{privateKey}, $linkPrivate);
      link($keys->{publicKey}, $linkPublic);
      # -h to dump what links point to
      my $ret = system("cd " . EBox::Config->tmp() . "; tar cvzhf $zipfile private-" .
		       $self->{cn} . ".pem public-" . $self->{cn} . ".pem");
      unlink($linkPrivate);
      unlink($linkPublic);
      if ($ret != 0) {
	throw EBox::Exceptions::External(__("Error creating file") . ": $!");
      }
      $self->{downfile} = $zipfile;
      $self->{downfilename} = "keys-" . $self->{cn} . ".tar.gz";
    } else {
      $self->{downfile} = $keys->{publicKey};
      $self->{downfilename} = "public-" . $self->{cn} . ".pem";
    }

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

    $self->_removePrivKey();


  }

# Delete the private key from user after sending it
sub _removePrivKey
  {

    my ($self) = @_;

    # Remove the private key after download the private key
    $self->{ca}->removePrivateKey($self->{cn});

  }

1;
