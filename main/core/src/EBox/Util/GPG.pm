# Copyright (C) 2011-2013 Zentyal S.L.
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
#

package EBox::Util::GPG;

use warnings;

use EBox::Sudo;
use TryCatch;

use constant GPGV_PROGRAM  => '/usr/bin/gpgv';
use constant KEYRING => '/usr/share/zentyal/keyring.gpg';

# Method: checkSignature
#
#   Checks GPG signature for the given file. It uses
#   zentyal defined keyring containing Zentyal public keys
#
# Parameters:
#   file - path of the file to check
#          (method will search for a .sig file with the same name)
sub checkSignature
{
    my ($file) = @_;

    my $command = GPGV_PROGRAM . ' --homedir /dev/null --keyring ' .
                  KEYRING . " $file.sig >/dev/null 2>&1";
    return not system($command);
}

1;
