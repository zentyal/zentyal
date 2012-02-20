#!/usr/bin/perl

use strict;

use Net::LDAP;
use File::Slurp;
use MIME::Base64;
use Encode qw(decode encode);
use Error qw(:try);
use Data::Dumper; #XXX

use EBox;
use EBox::Global;

use constant LDAP_BASE => 'dc=precise'; # TODO: Get this from anywhere
use constant SAMBA_SAM_FILE => '/var/lib/samba/private/sam.ldb.d/DC=KERNEVIL,DC=LAN.ldb'; # TODO: Build this path

# There users and groups won't be synchronized to LDAP
my @sambaUsersToIgnore = ('krbtgt', 'Administrator', 'dns-precise', 'Guest'); # TODO build dns account dynamically
my @sambaGroupsToIgnore = ('Read-only Domain Controllers', 'Group Policy Creator Owners', 'Domain Controllers', 'Domain Computers', 'DnsUpdateProxy', 'Domain Admins',
                           'Domain Guests', 'Domain Users');

# These are the users and groups ignored. All users and groups that are not in
# samba neither in this arrays will be deleted
my @ldapUsersToIgnore  = ('');
my @ldapGroupsToIgnore = ('__USERS__');

#############################################################################
## Info, error and debug helper functions                                  ##
#############################################################################
sub debug
{
    my ($msg) = @_;
#    print "$msg\n";
#    EBox::debug($msg);
}

sub info
{
    my ($msg) = @_;
    print "$msg\n";
    EBox::info($msg); #TODO check
}

sub error
{
    my ($msg) = @_;
    print "$msg\n";
    EBox::error($msg); #TODO check
}

#############################################################################
## SAMBA credentials related functions                                     ##
#############################################################################

# Method: decodeKerberos
#
#       Decode the KERB_STORED_CREDENTIAL struct. This struct
#       contains the hashes of the kerberos keys. Its format
#       is documented at:
#       http://msdn.microsoft.com/en-us/library/cc245503(v=prot.10).aspx
#
#       Returns a hash reference with the kerberos keys
#
sub decodeKerberos
{
    my ($data) = @_;

    my $kerberosKeys = {};

    my $data = pack('H*', $data); # from hex to binary
    my $format = 's x2 s s s s l a*';
    if (length ($data) > 16) {
        my ($revision, $nCredentials, $nOldCredentials, $saltLength, $maxSaltLength, $saltOffset) = unpack($format, $data);
        debug ("Kerberos info: revision '$revision', number of credentials '$nCredentials', " .
               "number of old credentials '$nOldCredentials', salt length '$saltLength', salt max length '$maxSaltLength', salt offset '$saltOffset'");
        if ($revision == 3) {
            my ($saltValue) = unpack('@' . $saltOffset . 'a' . $maxSaltLength, $data);
            debug ("Salt length '$maxSaltLength', salt value '$saltValue'");

            my $offset = 16;
            for(my $i=0; $i<$nCredentials; $i++) {
                my ($keyType, $keyLength, $keyOffset) = unpack('@' . $offset . 'x8 l l l', $data);
                my ($keyValue) = unpack('@' . $keyOffset . 'a' . $keyLength, $data);
                $offset += 20;

                if ($keyType == 1) {
                    $kerberosKeys->{'dec-cbc-crc'} = $keyValue;
                }
                elsif ($keyType == 3) {
                    $kerberosKeys->{'des-cbc-md5'} = $keyValue;
                }
                debug ("Found kerberos key: type '$keyType', length '$keyLength', value '$keyValue'");
            }
        }
    }
    return $kerberosKeys;
}

# Method: decodeWDigest
#
#       Docode the WDIGEST_CREDENTIALS struct. This struct
#       contains 29 different hashes produced by combinations
#       of different elements including the sAMAccountName,
#       realm, host, etc. The format is documented at:
#       http://msdn.microsoft.com/en-us/library/cc245502(v=prot.10).aspx
#       The list of included hashes is documented at:
#       http://msdn.microsoft.com/en-us/library/cc245680(v=prot.10).aspx
#
#       Returns: An array reference containing the hashes
#
sub decodeWDigest
{
    my ($data) = @_;

    my $hashes = ();

    my $format = 'x4 a2 a2 x24 (a32)29';
    if (length ($data) == 960) {
        my ($version, $nHashes, @hashValues) = unpack($format, $data);
        $version = hex($version);
        $nHashes = hex($nHashes);
        debug ("WDigest info: version '$version', hash count '$nHashes'");
        if ($version == 1 and $nHashes == 29) {
            $hashes = \@hashValues;
        }
    }
    return $hashes;
}

# Method: decodeSupplementalCredentials
#
#       This method decodes the supplementalCredentials base64
#       encoded blob, called USER_PROPERTIES. The format of this
#       this struct is documented at:
#       http://msdn.microsoft.com/en-us/library/cc245500(v=prot.10).aspx
#       The USER_PROPERTIES contains various USER_PROPERTY structs,
#       documented at:
#       http://msdn.microsoft.com/en-us/library/cc245501(v=prot.10).aspx
#
#       Returns: A hash reference containing the different hashes
#                of the user credentials in different formats
#
sub decodeSupplementalCredentials
{
    my ($user) = @_;

    my $credentials = {};
    if (exists $user->{'supplementalCredentials'}) {
        my $blob = decode_base64($user->{'supplementalCredentials'});
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

                    debug ("Found property '$propertyName'='$propertyValue'");
                    if($propertyName eq encode('UTF-16LE', 'Primary:Kerberos')) {
                        $credentials->{'Primary:Kerberos'} = decodeKerberos($propertyValue);
                    }
                    elsif($propertyName eq encode('UTF-16LE', 'Primary:WDigest')) {
                        $credentials->{'Primary:WDigest'} = decodeWDigest($propertyValue);
                    }
                    elsif($propertyName eq encode('UTF-16LE', 'Primary:CLEARTEXT')) {
                        $credentials->{'Primary:CLEARTEXT'} = decode('UTF-16LE', pack ('H*', $propertyValue));
                    }
                }
            } else {
                error ("Corrupted supplementalCredentials found on user $user->{'sAMAccountName'}");
            }
        } else {
            error ("Truncated supplementalCredentials found on user $user->{'sAMAccountName'}");
        }
    } else {
        error ("SupplemetalCredentials not found in user $user->{'sAMAccountName'}");
    }
    return $credentials;
}

# Method: getSambaCredentials
#
#       This method gets all the credentials stored in the
#       LDB for the user
#
#       Returns: A hash reference containing all found credentials
#
sub getSambaCredentials
{
    my ($user) = @_;

    debug ("Getting credentials for samba user '$user->{sAMAccountName}'");
    my $credentials = decodeSupplementalCredentials ($user);
    $credentials->{'unicodePwd'} = decode_base64 ($user->{'unicodePwd'});
    return $credentials;
}

#############################################################################
## LDAP related functions                                                  ##
#############################################################################

# Method: getLdapUsers
#
#       This method get all users stored in LDAP, not including those
#       specified in the 'ignoreLdapUsers' array.
#
#       Returns: A hash reference containing all attributes stored in
#                LDAP for each user
#
sub getLdapUsers
{
    my ($ldap) = @_;

    my $ldapUsers = {};
    my $result = $ldap->search({
            base => LDAP_BASE,
            scope  => 'sub',
            filter => 'objectClass=posixAccount'});

    my @entries = $result->entries;
    my %ldapUsersToIgnore = map { $_ => 1 } @ldapUsersToIgnore;
    foreach my $entry (@entries) {
        unless (exists $ldapUsersToIgnore{$entry->get_value('uid')}) {
            $ldapUsers->{$entry->get_value('uid')} = $entry->attributes;
        }
    }
    return $ldapUsers;
}

# Method: getLdapUsers
#
#       This method get all groups stored in LDAP, not including those
#       specified in the 'ignoreLdapGroups' array.
#
#       Returns: A hash reference containing all attributes stored in
#                LDAP for each group
#
sub getLdapGroups
{
    my ($ldap) = @_;

    my $ldapGroups = {};
    my $result = $ldap->search({
            base => LDAP_BASE,
            scope  => 'sub',
            filter => 'objectClass=posixGroup'});

    my @entries = $result->entries;
    my %ldapGroupsToIgnore = map { $_ => 1 } @ldapGroupsToIgnore;
    foreach my $entry (@entries) {
        unless (exists $ldapGroupsToIgnore{$entry->get_value('cn')}) {
            $ldapGroups->{$entry->get_value('cn')} = $entry->attributes;
        }
    }
    return $ldapGroups;
}

# Method: addLdapUser
#
#       This method add a samba user to LDAP
#
sub addLdapUser
{
    my ($usersModule, $sambaUser) = @_;

    my $sambaCredentials = getSambaCredentials($sambaUser);
    if (exists $sambaCredentials->{'Primary:CLEARTEXT'})
    {
        info ("Adding samba user '$sambaUser->{sAMAccountName}' to ldap");
        my $params = {
            user => $sambaUser->{sAMAccountName},
            fullname => $sambaUser->{name},
            password => $sambaCredentials->{'Primary:CLEARTEXT'},
            givenname => $sambaUser->{givenName},
            surname => length ($sambaUser->{sn} > 0) ? $sambaUser->{sn} : $sambaUser->{cn},
            comment => $sambaUser->{description},
        };

        try {
            $usersModule->addUser($params, 0 );
            #TODO Check the groups that the user belongs to and update ldap calling to $userModule->addUserToGroup(user, group)
        } otherwise {
            my $error = shift;
            error ("Error adding user to LDAP: $error");
        }
    } else {
        error ("Samba user '$sambaUser->{sAMAccountName}' do not added to LDAP, password not found");
    }
}

# Method: addLdapGroup
#
#       This method add a samba group to LDAP
#
#sub addLdapGroup
#{
#    my ($usersModule, $sambaGroup) = @_;
#
#    info ("Adding samba group '$sambaGroup->{sAMAccountName}' to ldap");
#    my %params = {
#       user => $sambaUser->{sAMAccountName},
#       fullname => '',
#       password => $sambaCredentials->{'Primary:CLEARTEXT'},
#       givenname => '',
#       surname => '',
#       comment => '',
#     };
#
#        try {
#            $usersModule->addUser(\%params, 0 );
#            #TODO Check the groups that the user belongs to and update ldap calling to $userModule->addUserToGroup(user, group)
#        } otherwise {
#            my $error = shift;
#            error ("Error adding user to LDAP: $error");
#        }
#    } else {
#        error ("Samba user '$sambaUser->{sAMAccountName}' do not added to LDAP, password not found");
#    }
#}

#############################################################################
## LDB related functions                                                   ##
#############################################################################

# Method: parseLdbSearch
#
#       This method parse the output of the command ldbsearch
#
#       Returns: A hash reference containing all entries and
#                its attributes
#
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

# Method: getSambaUsers
#
#       This method get all users stored in the samba LDB,
#       except those specified in the sambaUsersToIgnore
#
#       Returns: A hash referente containing all users and
#                its attributes
#
sub getSambaUsers
{
    my $command = " ldbsearch -H " . SAMBA_SAM_FILE .
#        " '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200)(!(IsCriticalSystemObject=TRUE)))'";
        " '(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=0x00000200))'";
    my $output = `$command`;
    my $sambaUsers = parseLdbsearch($output, 'sAMAccountName');
    foreach my $userToIgnore (@sambaUsersToIgnore) {
        if (exists $sambaUsers->{$userToIgnore}) {
            delete $sambaUsers->{$userToIgnore};
        }
    }
    return $sambaUsers;
}

# Method: getSambaGroups
#
#       This method get all groups stored in the samba LDB
#       except those specified in the sambaGroupsToIgnore
#
#       Returns: A hash referente containing all users and
#                its attributes
#
sub getSambaGroups
{
    my $command = " ldbsearch -H " . SAMBA_SAM_FILE .
#                  " '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002)(!(isCriticalSystemObject=TRUE)))'";
                  " '(&(objectClass=group)(groupType:1.2.840.113556.1.4.803:=0x0000002))'";
    my $output = `$command`;
    my $sambaGroups = parseLdbsearch($output, 'sAMAccountName');
    foreach my $groupToIgnore (@sambaGroupsToIgnore) {
        if (exists $sambaGroups->{$groupToIgnore}) {
            delete $sambaGroups->{$groupToIgnore};
        }
    }
    return $sambaGroups;
}

####################################################################################################

my $errors = 0;

my $sambaUsers = getSambaUsers();
my $sambaGroups = getSambaGroups();

EBox::init();
my $usersModule = EBox::Global->modInstance('users');
my $ldap = $usersModule->ldap();
my $ldapUsers = getLdapUsers($ldap);
my $ldapGroups = getLdapGroups($ldap);

debug ("Got " . scalar(keys(%{$sambaUsers})) . " samba users and " .
        scalar(keys(%{$ldapUsers})) . " ldap users" );
debug ("Got " . scalar(keys(%{$sambaGroups})) . " samba groups and " .
        scalar(keys(%{$ldapGroups})) . " ldap groups" );

# Insert new users from Samba to LDAP
foreach my $sambaUser (keys %{$sambaUsers}) {
    addLdapUser ($usersModule, $sambaUsers->{$sambaUser}) unless exists $ldapUsers->{$sambaUser};
    delete ($sambaUsers->{$sambaUser});
}

# Insert new groups from Samba to LDAP
#foreach my $sambaGroup (keys %{$sambaGroups}) {
#    addLdapGroup ($usersModule, $sambaGroups->{$sambaGroup}) unless exists $ldapGroups->{$sambaGroup};
#}

# Delete users that are not in Samba
#foreach (keys %{$ldapUsers}) {
#    delLdapUser($ldapUsers->{$_}) unless exists $sambaUsers->{$_};
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


