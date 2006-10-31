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

package EBox::CGI::CA::RenewCertificate;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Method: new
#
#       Constructor for RenewCertificate CGI
#
# Returns:
#
#       RenewCertificate - The object recently created

sub new
  {

    my $class = shift;

    my $self = $class->SUPER::new('title' => __('Certification Authority Management'),
				  @_);

    $self->{domain} = "ebox-ca";
    $self->{redirect} = "CA/Index";
    bless($self, $class);

    return $self;

  }

# Process the HTTP query

sub _process
  {

    my $self = shift;

    my $ca = EBox::Global->modInstance('ca');

    $self->_requireParam('isCACert', __('Boolean indicating Certification Authority Certificate') );
    $self->_requireParam('expireDays', __('Days to expire') );
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
    my $expireDays = $self->param('expireDays');
    my $caPassphrase = $self->param('CAPassphrase');

    my $retValue;
    if ( $isCACert ) {
      $retValue = $ca->renewCACertificate( days          => $expireDays,
					   caKeyPassword => $caPassphrase);
    } else {
      $retValue = $ca->renewCertificate( commonName    => $commonName,
					  days          => $expireDays,
					  caKeyPassword => $caPassphrase);
    }

    if (not defined($retValue) ) {
      throw EBox::Exceptions::External(__('The certificate CANNOT be renewed'));
    } else {
      my $msg = __("The certificate has been renewed");
      $msg = __("The new CA certificate has been renewed") if ($isCACert);
      $self->setMsg($msg);
    }

  }

1;
