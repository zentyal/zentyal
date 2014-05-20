# Copyright (C) 2014 Zentyal S.L.
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

# Class: EBox::DNS::Model::ZoneTable
#
#   TODO Write doc
#
package EBox::DNS::Model::ZoneTable;

use base 'EBox::Model::DataTable';

use EBox::Util::Random;
use Digest::HMAC_MD5;
use MIME::Base64;

# Method: generateSecret
#
#   Generate the secret TSIG key using HMAC-MD5 algorithm
#
# Returns:
#
#   string - The generated key encoded in base64
#
sub generateSecret
{
    my ($self) = @_;

    my $secret = EBox::Util::Random::generate(64);
    my $hasher = Digest::HMAC_MD5->new($secret);
    my $digest = $hasher->digest();
    my $b64digest = encode_base64($digest);
    chomp ($b64digest);

    return $b64digest;
}

1;
