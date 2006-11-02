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

package EBox::CGI::CA::RevokeCertificate;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Method: new
#
#       Constructor for RevokeCertificate CGI
#
# Returns:
#
#       RevokeCertificate - The object recently created

sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title' => __('Certification Authority Management'),
				  @_);

    $self->{domain} = "ebox-ca";
    $self->{chain} = "CA/Index";
    bless($self, $class);

    return $self;

  }

# Process the HTTP query

sub _process
  {

    my $self = shift;

    my $ca = EBox::Global->modInstance('ca');

    $self->_requireParam('isCACert', __('Boolean indicating Certification Authority Certificate') );
    $self->_requireParam('reason', __('Reason') );
    $self->_requireParam('CAPassphrase', __('Certification Authority Passphrase') );

    my $commonName = $self->unsafeParam('commonName');
    # We have to check it manually
    if ( not defined($commonName) or $commonName eq "" ) {
      throw EBox::Exceptions::DataMissing(data => __('Common Name'));
    }

    # Transform %40 in @ 
    $commonName =~ s/%40/@/g;
    # Transform %20 in space
    $commonName =~ s/%20/ /g;

    my $isCACert = $self->param('isCACert');
    my $reason = $self->param('reason');
    my $caPassphrase = $self->param('CAPassphrase');
    my @array = ();

    my $retValue;
    if ( $isCACert ) {
      $retValue = $ca->revokeCACertificate( reason => $reason,
					    caKeyPassword => $caPassphrase);
    } else {
      $retValue = $ca->revokeCertificate( commonName    => $commonName,
					  reason        => $reason,
					  caKeyPassword => $caPassphrase);
    }

    my $msg = __("The certificate has been revoked");
    $msg = __("The CA certificate has been revoked") if ($isCACert);
    $self->setMsg($msg);

  }

1;
