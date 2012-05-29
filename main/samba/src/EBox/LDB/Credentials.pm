# Copyright (C) 2012 eBox Technologies S.L.
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

package EBox::LDB::Credentials;

use strict;
use warnings;

use Encode;

sub encodeKerberosKeyData
{
    my ($key, $keyOffset) = @_;

    my $reserved1 = 0;
    my $reserved2 = 0;
    my $reserved3 = 0;
    my $keyType   = $key->{type};
    my $keyLength = length ($key->{value});

    my $blob = pack ('s s l L L l',
                     $reserved1, $reserved2, $reserved3,
                     $keyType, $keyLength, $keyOffset);

    return $blob;
}

sub encodeKerberosProperty
{
    my ($keys, $oldKeys) = @_;

    my $salt = @{$keys}[0]->{salt}; # FIXME
    $salt = encode('UTF16-LE', $salt);
    my $defaultSaltLength    = length ($salt);
    my $defaultSaltMaxLength = length ($salt);

    my $credentials    = [];
    my $oldCredentials = [];
    my $keyValues      = [];
    my $keyValueOffset = 16 + 20 + (scalar @{$keys} * 20) + $defaultSaltLength;

    foreach my $key (@{$keys}) {
        push ($credentials, encodeKerberosKeyData($key, $keyValueOffset));
        push ($keyValues, $key->{value});
        $keyValueOffset += 8;
    }
    foreach my $key (@{$oldKeys}) {
        push ($oldCredentials, encodeKerberosKeyData($key, $keyValueOffset));
        push ($keyValues, $key->{value});
        $keyValueOffset += 8;
    }

    my $revision = 3;
    my $flags = 0;
    my $credentialCount    = scalar @{$credentials};
    my $oldCredentialCount = scalar @{$oldCredentials};

    my $credentialsString = join ('', @{$credentials});
    my $oldCredentialsString = join ('', @{$oldCredentials});
    my $valuesString = join ('', @{$keyValues});
    my $defaultSaltOffset = 16 + 20 + length ($credentialsString) + length ($oldCredentialsString);

    my $blob = pack ('s s s s s s L a* x20 a* a* a*',
                     $revision, $flags,
                     $credentialCount, $oldCredentialCount,
                     $defaultSaltLength, $defaultSaltMaxLength,
                     $defaultSaltOffset,
                     $credentialsString,
                     $oldCredentialsString,
                     $salt, $valuesString);

    return $blob;
}

sub encodeWDigestProperty
{
    my ($sam, $principal, $netbios, $dns, $pwd) = @_;

    $sam       = encode("iso-8859-1", $sam);
    $principal = encode("iso-8859-1", $principal);
    $netbios   = encode("iso-8859-1", $netbios);
    $dns       = encode("iso-8859-1", $dns);
    $pwd       = encode("iso-8859-1", $pwd);

    my $reserved1 = 0;
    my $reserved2 = 0;
    my $version   = 1;
    my $numHashes = 29;

    my $hashes = [];
    push ($hashes, md5_hex($sam . $netbios . $pwd));           # 1
    push ($hashes, md5_hex(uc($sam) . uc($netbios) . $pwd));    # 2
    push ($hashes, md5_hex(lc($sam) . lc($netbios) . $pwd));    # 3
    push ($hashes, md5_hex($sam . uc($netbios) . $pwd));        # 4
    push ($hashes, md5_hex($sam . lc($netbios) . $pwd));        # 5
    push ($hashes, md5_hex(uc($sam) . lc($netbios) . $pwd));    # 6
    push ($hashes, md5_hex(lc($sam) . uc($netbios) . $pwd));    # 7
    push ($hashes, md5_hex($sam . $dns . $pwd));                # 8
    push ($hashes, md5_hex(uc($sam) . uc($dns) . $pwd));        # 9
    push ($hashes, md5_hex(lc($sam) . lc($dns) . $pwd));        # 10
    push ($hashes, md5_hex($sam . uc($dns) . $pwd));            # 11
    push ($hashes, md5_hex($sam . lc($dns) . $pwd));            # 12
    push ($hashes, md5_hex(uc($sam) . lc($dns) . $pwd));        # 13
    push ($hashes, md5_hex(lc($sam) . uc($dns) . $pwd));        # 14
    push ($hashes, md5_hex($principal . $pwd));                 # 15
    push ($hashes, md5_hex(uc($principal) . $pwd));             # 16
    push ($hashes, md5_hex(lc($principal) . $pwd));             # 17
    push ($hashes, md5_hex($netbios . '\\' . $sam . $pwd));     # 18
    push ($hashes, md5_hex(uc($netbios . '\\' . $sam) . $pwd)); # 19
    push ($hashes, md5_hex(lc($netbios . '\\' . $sam) . $pwd)); # 20
    push ($hashes, md5_hex($sam . 'Digest' . $pwd));            # 21
    push ($hashes, md5_hex(uc($sam) . 'DIGEST' . $pwd));        # 22
    push ($hashes, md5_hex(lc($sam) . 'digest' . $pwd));        # 23
    push ($hashes, md5_hex($principal . 'Digest' . $pwd));      # 24
    push ($hashes, md5_hex(uc($principal) . 'DIGEST' . $pwd));  # 25
    push ($hashes, md5_hex(lc($principal) . 'digest' . $pwd));  # 26
    push ($hashes, md5_hex($netbios . '\\' . $sam . 'Digest' . $pwd)); # 27
    push ($hashes, md5_hex(uc($netbios . '\\' . $sam) . 'DIGEST' . $pwd));  # 28
    push ($hashes, md5_hex(lc($netbios . '\\' . $sam) . 'digest' . $pwd));  # 29

    my $blob = pack ('W W W W x12 a*',
                     $reserved1, $reserved2,
                     $version, $numHashes,
                     join ('', @{$hashes}));
    return $blob;
}

sub encodeUserProperty
{
    my ($name, $value) = @_;

    my $propertyName  = encode('UTF16-LE', $name);
    my $propertyValue = uc(unpack ('H*', $value));
    my $nameLength    = length ($propertyName);
    my $valueLength   = length ($propertyValue);
    my $reserved      = 0;

    my $blob = pack ('s s s a* a*',
                     $nameLength, $valueLength, $reserved,
                     $propertyName, $propertyValue);

    return $blob;
}

sub encodeUserProperties
{
    my ($kerberosKeys, $digest) = @_;

    my @packages = ();
    my $userProperties = '';

    my $reserved1 = 0;
    my $reserved2 = 0;
    my $reserved3 = 0;
    my $reserved4 = '';
    my $reserved5 = 0;
    my $signature = 0x50;
    my $propertyCount = (defined $kerberosKeys) + (defined $digest) + 1;

    # Samba4 expects reserved4 to be an array of '0x2000'
    for (my $i=0; $i<48; $i++) {
        $reserved4 .= pack('H*', 2000);
    }

    if (defined $kerberosKeys) {
        my $kerberosProperty = encodeKerberosProperty($kerberosKeys);
        $userProperties .= encodeUserProperty('Primary:Kerberos', $kerberosProperty);
        push (@packages, encode('UTF16-LE', 'Kerberos'));
    }

    if (defined $digest) {
        my $wdigestProperty  = encodeWDigestProperty(
            $digest->{sam},
            $digest->{principal},
            $digest->{netbios},
            $digest->{dns},
            $digest->{pwd});
        $userProperties .= encodeUserProperty('Primary:WDigest', $wdigestProperty);
        push (@packages, encode('UTF16-LE', 'WDigest'));
    }

    my $packagesStr = join(encode('UTF16-LE', "\0"), @packages);
    $userProperties .= encodeUserProperty('Packages', $packagesStr);

    my $length = 4 + 96 + length ($userProperties);

    my $blobFormat = 'l L s s a* s s a* W';
    my $blob = pack ($blobFormat, $reserved1, $length,
                     $reserved2, $reserved3,
                     $reserved4,
                     $signature, $propertyCount,
                     $userProperties, $reserved5);

    return $blob;
}

sub encodeSambaCredentials
{
    my ($krbKeys) = @_;

    unless (defined $krbKeys) {
        throw EBox::Exceptions::MissingArgument('krbKeys');
    }

    my $credentials = {};

    # Remove the type 23 from keys because it is the unicodePwd attribute
    # and make sure type 3 is the first in the array, it must be the first
    # key or samba will fail to write the supplementalCredentials attribute
    my $newList = [];
    foreach my $key (@{$krbKeys}) {
        if ($key->{type} == 23) {
            $credentials->{unicodePwd} = $key->{value};
            next;
        } elsif ($key->{type} == 3) {
            @{$newList}[0] = $key;
            next;
        } elsif ($key->{type} == 1) {
            @{$newList}[1] = $key;
            next;
        }
    }

    if (scalar @{$krbKeys} >= 2) {
        $credentials->{supplementalCredentials} = encodeUserProperties($newList);
    }

    return $credentials;
}

1;
