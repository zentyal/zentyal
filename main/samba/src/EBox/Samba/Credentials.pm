# Copyright (C) 2012-2013 Zentyal S.L.
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

package EBox::Samba::Credentials;

use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::Internal;

use Encode;

sub new
{
    my ($class, %params) = @_;

    my $self = {};
    bless ($self, $class);

    unless ($params{krb5Keys} or $params{unicodePwd} or $params{supplementalCredentials}) {
        throw EBox::Exceptions::MissingArgument('krb5Keys or unicodePwd or supplementalCredentials');
    }

    if (exists $params{krb5Keys}) {
        my $encoded = $self->_encodeSambaCredentials($params{krb5Keys});
        $self->{krb5Keys} = $params{krb5Keys};
        $self->{unicodePwd} = $encoded->{unicodePwd};
        $self->{supplementalCredentials} = $encoded->{supplementalCredentials};
    } elsif (exists $params{unicodePwd} or exists $params{supplementalCredential}) {
        my $decoded = $self->_decodeSambaCredentials($params{supplementalCredentials}, $params{unicodePwd});
        $self->{unicodePwd} = $params{unicodePwd};
        $self->{supplementalCredentials} = $params{supplementalCredentials};
        $self->{krb5Keys} = $decoded->{kerberosKeys};
    }

    return $self;
}

sub kerberosKeys
{
    my ($self) = @_;

    return $self->{krb5Keys};
}

sub supplementalCredentials
{
    my ($self) = @_;

    return $self->{supplementalCredentials};
}

sub unicodePwd
{
    my ($self) = @_;

    return $self->{unicodePwd};
}

###########################################################
##              Encoding Section                         ##
###########################################################

sub _encodeKerberosKeyData
{
    my ($self, $key, $keyOffset) = @_;

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

sub _encodeKerberosProperty
{
    my ($self, $keys, $oldKeys) = @_;

    my $salt = @{$keys}[0]->{salt}; # FIXME
    $salt = encode('UTF16-LE', $salt);
    my $defaultSaltLength    = length ($salt);
    my $defaultSaltMaxLength = length ($salt);

    my $credentials    = [];
    my $oldCredentials = [];
    my $keyValues      = [];
    my $keyValueOffset = 16 + 20 + (scalar @{$keys} * 20) + $defaultSaltLength;

    foreach my $key (@{$keys}) {
        push (@{$credentials}, $self->_encodeKerberosKeyData($key, $keyValueOffset));
        push (@{$keyValues}, $key->{value});
        $keyValueOffset += 8;
    }
    foreach my $key (@{$oldKeys}) {
        push (@{$oldCredentials}, $self->_encodeKerberosKeyData($key, $keyValueOffset));
        push (@{$keyValues}, $key->{value});
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

sub _encodeWDigestProperty
{
    my ($self, $sam, $principal, $netbios, $dns, $pwd) = @_;

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
    push (@{$hashes}, md5_hex($sam . $netbios . $pwd));           # 1
    push (@{$hashes}, md5_hex(uc($sam) . uc($netbios) . $pwd));    # 2
    push (@{$hashes}, md5_hex(lc($sam) . lc($netbios) . $pwd));    # 3
    push (@{$hashes}, md5_hex($sam . uc($netbios) . $pwd));        # 4
    push (@{$hashes}, md5_hex($sam . lc($netbios) . $pwd));        # 5
    push (@{$hashes}, md5_hex(uc($sam) . lc($netbios) . $pwd));    # 6
    push (@{$hashes}, md5_hex(lc($sam) . uc($netbios) . $pwd));    # 7
    push (@{$hashes}, md5_hex($sam . $dns . $pwd));                # 8
    push (@{$hashes}, md5_hex(uc($sam) . uc($dns) . $pwd));        # 9
    push (@{$hashes}, md5_hex(lc($sam) . lc($dns) . $pwd));        # 10
    push (@{$hashes}, md5_hex($sam . uc($dns) . $pwd));            # 11
    push (@{$hashes}, md5_hex($sam . lc($dns) . $pwd));            # 12
    push (@{$hashes}, md5_hex(uc($sam) . lc($dns) . $pwd));        # 13
    push (@{$hashes}, md5_hex(lc($sam) . uc($dns) . $pwd));        # 14
    push (@{$hashes}, md5_hex($principal . $pwd));                 # 15
    push (@{$hashes}, md5_hex(uc($principal) . $pwd));             # 16
    push (@{$hashes}, md5_hex(lc($principal) . $pwd));             # 17
    push (@{$hashes}, md5_hex($netbios . '\\' . $sam . $pwd));     # 18
    push (@{$hashes}, md5_hex(uc($netbios . '\\' . $sam) . $pwd)); # 19
    push (@{$hashes}, md5_hex(lc($netbios . '\\' . $sam) . $pwd)); # 20
    push (@{$hashes}, md5_hex($sam . 'Digest' . $pwd));            # 21
    push (@{$hashes}, md5_hex(uc($sam) . 'DIGEST' . $pwd));        # 22
    push (@{$hashes}, md5_hex(lc($sam) . 'digest' . $pwd));        # 23
    push (@{$hashes}, md5_hex($principal . 'Digest' . $pwd));      # 24
    push (@{$hashes}, md5_hex(uc($principal) . 'DIGEST' . $pwd));  # 25
    push (@{$hashes}, md5_hex(lc($principal) . 'digest' . $pwd));  # 26
    push (@{$hashes}, md5_hex($netbios . '\\' . $sam . 'Digest' . $pwd)); # 27
    push (@{$hashes}, md5_hex(uc($netbios . '\\' . $sam) . 'DIGEST' . $pwd));  # 28
    push (@{$hashes}, md5_hex(lc($netbios . '\\' . $sam) . 'digest' . $pwd));  # 29

    my $blob = pack ('W W W W x12 a*',
                     $reserved1, $reserved2,
                     $version, $numHashes,
                     join ('', @{$hashes}));
    return $blob;
}

sub _encodeUserProperty
{
    my ($self, $name, $value) = @_;

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

sub _encodeUserProperties
{
    my ($self, $kerberosKeys, $digest) = @_;

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
        my $kerberosProperty = $self->_encodeKerberosProperty($kerberosKeys);
        $userProperties .= $self->_encodeUserProperty('Primary:Kerberos', $kerberosProperty);
        push (@packages, encode('UTF16-LE', 'Kerberos'));
    }

    if (defined $digest) {
        my $wdigestProperty  = $self->_encodeWDigestProperty(
            $digest->{sam},
            $digest->{principal},
            $digest->{netbios},
            $digest->{dns},
            $digest->{pwd});
        $userProperties .= $self->_encodeUserProperty('Primary:WDigest', $wdigestProperty);
        push (@packages, encode('UTF16-LE', 'WDigest'));
    }

    my $packagesStr = join(encode('UTF16-LE', "\0"), @packages);
    $userProperties .= $self->_encodeUserProperty('Packages', $packagesStr);

    my $length = 4 + 96 + length ($userProperties);

    my $blobFormat = 'l L s s a* s s a* W';
    my $blob = pack ($blobFormat, $reserved1, $length,
                     $reserved2, $reserved3,
                     $reserved4,
                     $signature, $propertyCount,
                     $userProperties, $reserved5);

    return $blob;
}

sub _encodeSambaCredentials
{
    my ($self, $krbKeys) = @_;

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
        $credentials->{supplementalCredentials} = $self->_encodeUserProperties($newList);
    }

    return $credentials;
}

###########################################################
##              Decoding Section                         ##
###########################################################

# Method: _decodeWDigest
#
#   Docode the WDIGEST_CREDENTIALS struct. This struct
#   contains 29 different hashes produced by combinations
#   of different elements including the sAMAccountName,
#   realm, host, etc. The format is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245502(v=prot.10).aspx
#   The list of included hashes is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245680(v=prot.10).aspx
#
# Returns:
#
#   An array reference containing the hashes
#
sub _decodeWDigest
{
    my ($self, $data) = @_;

    my $hashes = ();

    my $format = 'x4 a2 a2 x24 (a32)29';
    if (length ($data) == 960) {
        my ($version, $nHashes, @hashValues) = unpack($format, $data);
        $version = hex($version);
        $nHashes = hex($nHashes);
        if ($version == 1 and $nHashes == 29) {
            $hashes = \@hashValues;
        }
    }
    return $hashes;
}

# Method: _decodeKerberos
#
#   Decode the KERB_STORED_CREDENTIAL struct. This struct
#   contains the hashes of the kerberos keys. Its format
#   is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245503(v=prot.10).aspx
#
# Returns:
#
#   A hash reference with the kerberos keys
#
sub _decodeKerberos
{
    my ($self, $data) = @_;

    my $kerberosKeys = [];

    $data = pack('H*', $data); # from hex to binary
    my $format = 's x2 s s s s l a*';
    if (length ($data) > 16) {
        my ($revision, $nCredentials, $nOldCredentials, $saltLength, $maxSaltLength, $saltOffset) = unpack($format, $data);
        if ($revision == 3) {
            my ($saltValue) = unpack('@' . $saltOffset . 'a' . $maxSaltLength, $data);
            my $offset = 16;
            for (my $i=0; $i<$nCredentials; $i++) {
                my ($keyType, $keyLength, $keyOffset) = unpack('@' . $offset . 'x8 l l l', $data);
                # From MS-SAMR Security Account Manager (SAM) Remote Protocol Specification (Client-to-Server) (v20110610)
                # Section 2.2.10.8: When the current domain functional level is DS_BEHAVIOR_WIN2003 or
                # less, a Windows Server 2008 or Windows Server 2008 R2 DC includes a KeyType of -140 in each of
                # KERB_STORED_CREDENTIAL and KERB_STORED_CREDENTIAL_NEW, which is not needed and can
                # be ignored; it is a dummy type in the supplemental credentials that is not present when the domain
                # functional level is raised to DS_BEHAVIOR_WIN2008 or greater. The key data is the NT hash of the
                # password.
                my ($keyValue) = unpack('@' . $keyOffset . 'a' . $keyLength, $data);
                $offset += 20;
                my $key = {
                    type => $keyType,
                    value => $keyValue,
                    salt => decode ('UTF-16LE', $saltValue),
                };
                push (@{$kerberosKeys}, $key) if ($keyType != -140);
            }
        }
    }
    return $kerberosKeys;
}

sub _decodeKerberosNewerKeys
{
    my ($self, $data) = @_;

    my $kerberosKeys = [];

    $data = pack('H*', $data); # from hex to binary
    my $format = 's x2 s s s s s s l l a*';
    if (length ($data) > 24) {
        my ($revision, $nCredentials, $nServiceCredentials,
            $nOldCredentials, $nOlderCredentials,
            $saltLength, $maxSaltLength,
            $saltOffset, $defaultIterationCount) = unpack ($format, $data);
        if ($revision == 4) {
            my ($saltValue) = unpack('@' . $saltOffset . 'a' . $maxSaltLength, $data);
            my $offset = 24;
            for(my $i=0; $i<$nCredentials; $i++) {
                my ($keyType, $keyLength, $keyOffset) = unpack('@' . $offset . 'x12 l l l', $data);
                my ($keyValue) = unpack('@' . $keyOffset . 'a' . $keyLength, $data);
                $offset += 24;
                my $key = {
                    type => $keyType,
                    value => $keyValue,
                    salt => decode ('UTF-16LE', $saltValue),
                };
                push (@{$kerberosKeys}, $key) if ($keyType != -140);
            }
        }
    }
    return $kerberosKeys;
}

# Method: _decodeSupplementalCredentials
#
#   this struct is documented at:
#   http://msdn.microsoft.com/en-us/library/cc245500(v=prot.10).aspx
#   The USER_PROPERTIES contains various USER_PROPERTY structs,
#   documented at:
#   http://msdn.microsoft.com/en-us/library/cc245501(v=prot.10).aspx
#
# Returns:
#
#   A hash reference containing the different hashes
#   of the user credentials in different formats
#
sub _decodeSupplementalCredentials
{
    my ($self, $blob) = @_;

    my $credentials = {};
    my $blobFormat = 'x4 L< x2 x2 x96 S< S< a*';
    if (length ($blob) > 112) {
        my ($blobLength, $blobSignature, $nProperties, $properties) = unpack ($blobFormat, $blob);
        # Check the signature. Its value must be 0x50
        if ($blobSignature == 0x50) {
            my $offset = 112;
            for (my $i=0; $i<$nProperties; $i++) {
                my ($propertyNameLength) = unpack('@' . $offset . 'S<', $blob);
                $offset += 2;

                my ($propertyValueLength) = unpack('@' . $offset . 'S<', $blob);
                $offset += 4; # 2 bytes + 2 bytes reserved

                my ($propertyName) = unpack('@' . $offset . 'a' . $propertyNameLength, $blob);
                $offset += $propertyNameLength;

                my ($propertyValue) = unpack('@' . $offset . 'a' . $propertyValueLength, $blob);
                $offset += $propertyValueLength;

                if($propertyName eq encode('UTF-16LE', 'Primary:Kerberos')) {
                    $credentials->{'Primary:Kerberos'} = $self->_decodeKerberos($propertyValue);
                }
                elsif($propertyName eq encode('UTF-16LE', 'Primary:Kerberos-Newer-Keys')) {
                    $credentials->{'Primary:Kerberos-Newer-Keys'} = $self->_decodeKerberosNewerKeys($propertyValue);
                }
                elsif($propertyName eq encode('UTF-16LE', 'Primary:WDigest')) {
                    $credentials->{'Primary:WDigest'} = $self->_decodeWDigest($propertyValue);
                }
                elsif($propertyName eq encode('UTF-16LE', 'Primary:CLEARTEXT')) {
                    $credentials->{'Primary:CLEARTEXT'} = decode('UTF-16LE', pack ('H*', $propertyValue));
                }
            }
        } else {
            throw EBox::Exceptions::Internal("Corrupted supplementalCredentials");
        }
    } else {
        throw EBox::Exceptions::Internal("Truncated supplementalCredentials");
    }
    return $credentials;
}

# Method: _decodeSambaCredentials
#
#   This method gets all the credentials stored in the
#   LDB for the user
#
# Parameters:
#
#   supplementalCredentialsBlob
#   unicodePwdBlob
#
# Returns:
#
#   A hash reference containing all found credentials
#
sub _decodeSambaCredentials
{
    my ($self, $supplementalCredentialsBlob, $unicodePwdBlob) = @_;

    my $credentials = {};

    if (defined $supplementalCredentialsBlob) {
        my $properties = $self->_decodeSupplementalCredentials($supplementalCredentialsBlob);
        if (exists $properties->{'Primary:Kerberos-Newer-Keys'}) {
            $credentials->{kerberosKeys} = $properties->{'Primary:Kerberos-Newer-Keys'};
        } elsif (exists $properties->{'Primary:Kerberos'}) {
            $credentials->{kerberosKeys} = $properties->{'Primary:Kerberos'};
        }

        if (exists $properties->{'Primary:WDigest'}) {
            $credentials->{WDigest} = $properties->{'Primary:WDigest'};
        }

        if (exists $properties->{'Primary:CLEARTEXT'}) {
            $credentials->{clearText} = $properties->{'Primary:CLEARTEXT'};
        }
    }

    if (defined $unicodePwdBlob) {
        unless (exists $credentials->{kerberosKeys}) {
            $credentials->{kerberosKeys} = [];
        }
        if (scalar @{$credentials->{kerberosKeys}} > 0) {
            # Copy salt from previous krb keys
            my $key = {
                type => 23,
                salt => @{$credentials->{kerberosKeys}}[0]->{salt},
                value => $unicodePwdBlob,
            };
            push (@{$credentials->{kerberosKeys}}, $key);
        } else {
             my $key = {
                type => 23,
                value => $unicodePwdBlob,
            };
            push (@{$credentials->{kerberosKeys}}, $key);
        }
    }

    return $credentials;
}

1;
