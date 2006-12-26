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

use strict;
use warnings;

use EBox::TestStubs;
use Data::Dumper;
use EBox::Global;

# Activating eBox test stubs to fake a module
EBox::TestStubs::activateTestStubs();

# Fake a CA observer
EBox::TestStubs::fakeEBoxModule(name    => 'certuser',
				package => 'EBox::CA::CertUser',
				isa     => ['EBox::CA::Observer'],
				subs    => [ certificateRevoked => \&certificateRevoked,
					     certificateExpired => \&certificateExpired,
					     freeCertificate    => \&freeCertificate ]
			       );

EBox::TestStubs::fakeEBoxModule(name => 'foobaz');

# Loading package
# use EBox::CA::CertUser;
# Creating a module instance
my $anObject = EBox::Global->modInstance('certuser');
# Checking observers
my $global = EBox::Global->getInstance();
print Data::Dumper->Dump($global->modNames()) . $/;
print Data::Dumper->Dump($global->modInstancesOfType('EBox::CA::Observer')) . $/;


# Observer methods
sub certificateRevoked
  {

    my ($self, $commonName, $isCACert) = @_;

    EBox::debug("Certificate user now knows $commonName is gonna be revoked");

    if ($isCACert) {
      return 1;
    } else {
      return undef;
    }

  }

sub certificateExpired
  {

    my ($self, $commonName, $isCACert) = @_;

    EBox::debug("Certificate user now knows $commonName has expired");
    EBox::debug("Is a CA certificate: " . $isCACert );

    return;

  }

sub freeCertificate
  {

    my ($self, $commonName) = @_;

    EBox::debug("Certificate user now frees $commonName certificate");

    return;

  }

1;
