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

package EBox::CA::TestStub;

# Description: Test stub for CA module used by OpenVPN
use strict;
use warnings;

use EBox::CA;
use Test::MockObject;

sub fake
  {
    Test::MockObject->fake_module('EBox::CA',
				  isCreated           => \&isCreated,
				  createCA            => \&createCA,
				  revokeCACertificate => \&revokeCACertificate,
				  issueCACertificate  => \&issueCACertificate,
				  renewCACertificate  => \&renewCACertificate,
				  issueCertificate    => \&issueCertificate,
				  revokeCertificate   => \&revokeCertificate,
				  listCertificates    => \&listCertificates,
				  getKeys             => \&getKeys,
				  renewCertificate    => \&renewCertificate,
				  currentCACertificateState => \&currentCACertificateState,
				  getCACertificate    => \&getCACertificate,
				  getCertificates     => \&getCertificates
				  setInitialState     => \&setInitialState
				  );
  }

sub unfake
{
  delete $INC{'EBox/CA.pm'};
  eval 'use EBox::CA';
  $@ and die "Error reloading EBox::CA :  $@";
}

1;
