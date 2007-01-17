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

package EBox::CA::Observer;

use strict;
use warnings;

use EBox::Gettext;

sub new
{
	my $class = shift;
	my $self = {};
	bless($self, $class);
	return $self;
}

# Method: certificateRevoked
#
#	Invoked when a certificate is gonna be revoked, this method
#	receives the common name which identifies the certificate and
#	if it is the CA certificate. Returning a true value means that
#	this module's configuration would become inconsistent if such
#	the revokation is made. In that case the CA module will
#	not make the change, but warn the user instead. You should
#	override this method if you need to.
#
# Parameters:
#
#	commonName - common name which identifies the certificate
#       isCACert   - is the CA certificate?
#
# Returns:
#
#	 true  - if module's configuration becomes inconsistent
#        false - otherwise
#
sub certificateRevoked # (commonName, isCACert)
{
        return undef;
}

# Method: certificateExpired
#
# 	Invoked when a certificate has expired or is about to do
# 	it. You should override this method if you need to. It cannot
# 	be prevented since time is time.
#
# Parameteres:
#
#       commonName - common name which identifies the certificate
#       isCACert   - is the CA certificate?
#

sub certificateExpired # (commonName, isCACert)
{
        return undef;
}

# Method: freeCertificate
#
# 	Tells this module that an certificate is going to be revoked or has expired,
#       so that it can remove it from its configuration.
#
# Parameters:
#
#       commonName - common name which identifies the certificate
#

sub freeCertificate # (commonName)
  {
    # default empty implementation. Subclasses should override this as
    # needed.
  }

1;
