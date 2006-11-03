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

package EBox::CGI::CA::IssueCertificate;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Global;

# Method: new
#
#       Constructor for IssueCertificate CGI
#
# Returns:
#
#       IssueCertificate - The object recently created

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

    my $issueCA = $self->param('caNeeded');
    $issueCA = 0 unless defined($issueCA);

    if ($issueCA) {
      $self->_requireParam('name', __('Organization Name') );
      $self->_requireParam('passphrase', __('Certification Authority Passphrase') );
    } else {
      $self->_requireParam('name', __('Common Name') );
      $self->_requireParam('passphrase', __('Key Pair Passphrase') );
      $self->_requireParam('CAPassphrase', __('Certification Authority Passphrase') );
    }
    # Common parameters
    $self->_requireParam('expiryDays', __('Days to expire') );
    $self->_requireParam('repassphrase', __('Re-type Passphrase') );

    my $name = $self->param('name');
    my $days = $self->param('expiryDays');
    my $passphrase = $self->param('passphrase');
    my $repassphrase = $self->param('repassphrase');
    my $caPassphrase = $self->param('CAPassphrase');

    if($passphrase ne $repassphrase) {
      throw EBox::Exceptions::External(__('Passphrases do NOT match'));
    }

    if (not $issueCA) {
      if ( length($passphrase) < 4 or length($caPassphrase) < 4) {
	throw EBox::Exceptions::External(__('Passphrases should be at ' 
					    . 'least 4 characters long'));
      }

    }

    if ( $days <= 0 ) {
      throw EBox::Exceptions::External(__('Days to expire MUST be a natural number'));
    }

    my $retValue;
    if ($issueCA) {
      $retValue = $ca->issueCACertificate( orgName       => $name,
					   days          => $days,
					   caKeyPassword => $passphrase,
					   genPair       => 1);
    } else {
      $retValue = $ca->issueCertificate( commonName    => $name,
					 days          => $days,
					 keyPassword   => $passphrase,
					 caKeyPassword => $caPassphrase);
    }

    my $msg = __("The certificate has been issued");
    $msg = __("The new CA certificate has been issued") if ($issueCA);
    $self->setMsg($msg);

  }

1;
