#!/usr/bin/perl

use strict;

use File::Slurp;
use MIME::Base64;
use Encode qw(encode);

sub decodeKerberos {
    my ($data) = @_;

    # http://msdn.microsoft.com/en-us/library/cc245503(v=prot.10).aspx
    my $data = pack('H*', $data); # from hex to binary
    my $format = 's x2 s s s s l a*';
    my ($revision, $nCredentials, $nOldCredentials, $saltLength, $maxSaltLength, $saltOffset) = unpack($format, $data);
    print "Revision: $revision, nCredentials $nCredentials, nOldCredentials $nOldCredentials, saltLength $saltLength, saltMaxLength $maxSaltLength, saltOffset $saltOffset\n";
# TODO assers revision is 3

    my ($saltValue) = unpack('@' . $saltOffset . 'a' . $maxSaltLength, $data);
    print "Salt length: $maxSaltLength, salt value $saltValue\n";

    my $offset = 16;
    for(my $i=0; $i<$nCredentials; $i++) {
        my ($keyType, $keyLength, $keyOffset) = unpack('@' . $offset . 'x8 l l l', $data);
        my ($keyValue) = unpack('@' . $keyOffset . 'a' . $keyLength, $data);
        $offset += 20;

        print "Key type: $keyType, key length: $keyLength, key value: $keyValue\n";
    }
}

sub decodeWDigest {
    my ($data) = @_;

    # http://msdn.microsoft.com/en-us/library/cc245502(v=prot.10).aspx
    my $format = 'x4 a2 a2 x24 (a32)29';
    my ($version, $nHashes, @hashes) = unpack($format, $data);
    $version = hex($version);
    $nHashes = hex($nHashes);

    print "WDigest: Version $version, hash count $nHashes\n";
    print "Found " . "@hashes\n";
}

sub decodeUserProperties {
    my ($nProperties, $blob) = @_;

    # Format of the USER_PROPERTY struct is documented at
    # "http://msdn.microsoft.com/en-us/library/cc245501(v=prot.10).aspx"
    my $offset = 0;
    for(my $i=0; $i<$nProperties; $i++) {
        my ($propertyNameLength) = unpack('@' . $offset . 'S<', $blob);
        $offset += 2;

        my ($propertyValueLength) = unpack('@' . $offset . 'S<', $blob);
        $offset += 4; # 2 bytes + 2 bytes reserved

        my ($propertyName) = unpack('@' . $offset . 'a' . $propertyNameLength, $blob);
        $offset += $propertyNameLength;

        my ($propertyValue) = unpack('@' . $offset . 'a' . $propertyValueLength, $blob);
        $offset += $propertyValueLength;

        print "Property '$propertyName'='$propertyValue'\n";
        if($propertyName eq encode('UTF-16LE', 'Primary:Kerberos')) {
            decodeKerberos($propertyValue);
        }
        elsif($propertyName eq encode('UTF-16LE', 'Primary:WDigest')) {
            decodeWDigest($propertyValue);
        }
    }
}

my $command = "ldbsearch -H /var/lib/samba/private/sam.ldb.d/DC=KERNEVIL,DC=LAN.ldb" .
              " '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200))'" .
              " samaccountname unicodePwd supplementalCredentials";

my $content = `$command`;

my @foo = split("\n", $content);


unless(system($command)) {
    my $line;
    while($line = <STDOUT>) {
        print $line;
#        my $blob = decode_base64 ($encodedBlob);
#        my $blobFormat = 'x4 L< x2 x2 x96 S< S< a*';
#        my ($blobLength, $blobSignature, $nProperties, $properties) = unpack ($blobFormat, $blob);
#
#        print "Length: $blobLength\n";
#        print "Signature: $blobSignature\n";
#        print "Properties count: $nProperties\n\n";
#
#        decodeUserProperties ($nProperties, $properties);
    }
}
