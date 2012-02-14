#!/usr/bin/perl

use strict;

use Net::LDAP;
use File::Slurp;
use MIME::Base64;
use Encode qw(encode);
use Data::Dumper;

use EBox;
use EBox::Global;

use constant LDAP_SECRET_FILE => '/etc/ldap.secret';
use constant LDAP_USER => 'cn=ebox,dc=precise';
use constant LDAP_BASE => 'dc=precise';

use constant SAMBA_SAM_FILE => '/var/lib/samba/private/sam.ldb.d/DC=KERNEVIL,DC=LAN.ldb';

my @sambaUsersToIgnore = ('krbtgt', 'Administrator', 'dns-precise', 'Guest'); # TODO build dns account dynamically
my @sambaGroupsToIgnore = ('Read-only Domain Controllers', 'Group Policy Creator Owners', 'Domain Controllers', 'Domain Computers', 'DnsUpdateProxy', 'Domain Admins',
                           'Domain Guests', 'Domain Users');
my @ldapUsersToIgnore  = ('');
my @ldapGroupsToIgnore = ('__USERS__');

sub debug
{
    my ($msg) = @_;
    print "$msg\n";
}

sub decodeKerberos
{
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

sub decodeWDigest
{
    my ($data) = @_;

    # http://msdn.microsoft.com/en-us/library/cc245502(v=prot.10).aspx
    my $format = 'x4 a2 a2 x24 (a32)29';
    my ($version, $nHashes, @hashes) = unpack($format, $data);
    $version = hex($version);
    $nHashes = hex($nHashes);

    print "WDigest: Version $version, hash count $nHashes\n";
    print "Found " . "@hashes\n";
}

sub decodeUserProperties
{
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

sub getSambaPassword
{
    my ($user) = @_;

    debug("get password for user $user->{sAMAccountName}");

    my $blob = decode_base64($user->{supplementalCredentials});
    my $blobFormat = 'x4 L< x2 x2 x96 S< S< a*';
# TODO check that length is enought
   my ($blobLength, $blobSignature, $nProperties, $properties) = unpack ($blobFormat, $blob);

   print "Length: $blobLength\n";
   print "Signature: $blobSignature\n";
   print "Properties count: $nProperties\n\n";

#   decodeUserProperties ($nProperties, $properties);
}

####################################################################################################

sub getLdapUsers
{
    my ($ldap) = @_;

    my $ldapUsers = {};

    my $result = $ldap->search({ base => LDAP_BASE,
            scope  => 'sub',
            filter => 'objectClass=posixAccount'});

    my @entries = $result->entries;
    foreach my $entry (@entries) {
        $ldapUsers->{$entry->get_value('uid')} = $entry->attributes;
    }

    return $ldapUsers;
}

sub getLdapGroups
{
    my ($ldap) = @_;

    my $ldapGroups = {};

    my $result = $ldap->search({ base => LDAP_BASE,
            scope  => 'sub',
            filter => 'objectClass=posixGroup'});

    my @entries = $result->entries;
    foreach my $entry (@entries) {
        $ldapGroups->{$entry->get_value('cn')} = $entry->attributes;
    }

    return $ldapGroups;
}

sub parseLdbsearch
{
    my ($output, $key) = @_;
    my $retVal = {};
    $output =~ s/\n(?=\s)//g; # Fix continuation lines
    my @entries = split(/#\s+record\s+\d+\n/, $output);
    shift (@entries); # remove the first empty element
    foreach my $entry (@entries) {
        $entry =~ s/#.*\n//mg;
        my @attributes = split(/\n/, $entry); # Split attributes
        my %attributes = map { split(/: |:: /, $_) } @attributes;
        $retVal->{$attributes{$key}} = \%attributes;
    }
    return $retVal;
}

sub getSambaUsers
{
    my $command = " ldbsearch -H " . SAMBA_SAM_FILE .
#        " '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200)(!(IsCriticalSystemObject=TRUE)))'";
        " '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200))'";
    my $output = `$command`;
    return parseLdbsearch($output, 'sAMAccountName');
}

sub getSambaGroups
{
    my $command = " ldbsearch -H " . SAMBA_SAM_FILE .
#                  " '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002)(!(isCriticalSystemObject=TRUE)))'";
                  " '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002))'";
    my $output = `$command`;
    return parseLdbsearch($output, 'sAMAccountName');
}

####################################################################################################
sub addLdapUser
{
    my ($usersModule, $sambaUser) = @_;

    debug("Adding samba user '$sambaUser->{sAMAccountName}' to ldap");
    my %params = {
        user => $sambaUser->{sAMAccountName},
        fullname => '',
        password => getSambaPassword($sambaUser),
        givenname => '',
        surname => '',
        comment => '',
    };
#    $usersModule->addUser(\%params, 0 );
    # TODO Check the groups that the user belongs to and update ldap calling to addUserToGroup(user, group)
}

my $errors = 0;

my $sambaUsers = getSambaUsers();
my $sambaGroups = getSambaGroups();

EBox::init();
my $usersModule = EBox::Global->modInstance('users');
my $ldap = $usersModule->ldap();
my $ldapUsers = getLdapUsers($ldap);
my $ldapGroups = getLdapGroups($ldap);

debug( "Got " . scalar(keys(%{$sambaUsers})) . " samba users and " . scalar(keys(%{$ldapUsers})) . " ldap users" );
debug( "Got " . scalar(keys(%{$sambaGroups})) . " samba groups and " . scalar(keys(%{$ldapGroups})) . " ldap groups" );

# Insert new users from Samba to LDAP
foreach my $sambaUser (keys %{$sambaUsers}) {
    my %sambaUsersToIgnore = map { $_ => 1 } @sambaUsersToIgnore;
    unless (exists $ldapUsers->{$sambaUser} or exists $sambaUsersToIgnore{$sambaUser}) {
        addLdapUser($usersModule, $sambaUsers->{$sambaUser});
    }
    delete ($sambaUsers->{$sambaUser});
}

# Delete users that are not in Samba
#foreach (keys %{$ldapUsers}) {
#    delLdapUser($ldapUsers->{$_}) unless exists $sambaUsers->{$_};
#}

# Insert new groups from Samba to LDAP
#foreach (keys %{$sambaGroups}) {
#    addLdapGroup($sambaGroups->{$_}) unless exists $ldapGroups->{$_};
#}

# Delete groups that are not in Samba
#foreach (keys %{$ldapGroups}) {
#    delLdapGroup($ldapGroups->{$_}) unless exists $sambaGroups->{$_};
#}

# Sync passwords from Samba to LDAP
#foreach (keys %{$sambaUsers}) {
#    my $password = getSambaPassword($sambaUsers->{$_}->{supplementalCredentials});
#}

# Sync groups membership from Samba to LDAP
#foreach (keys %{$sambaUsers}) {
#}


