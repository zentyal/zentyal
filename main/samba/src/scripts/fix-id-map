#!/usr/bin/perl

# This script updates the samba users and groups SIDs to uidNumber and gidNumber
# mappings in the idmap database.

use strict;
use warnings;

use Error qw(:try);

use EBox::Global;
use EBox::Samba::User;

EBox::init();

print "Updating users mappings...\n";
my $usersModule = EBox::Global->modInstance('users');
my $ldapUsers = $usersModule->users();
foreach my $user (@{$ldapUsers}) {
    my $uid = $user->get('uid');
    my $uidNumber = $user->get('uidNumber');
    next unless defined $uid and defined $uidNumber;

    my $sambaUser = new EBox::Samba::User(samAccountName => $uid);
    next unless $sambaUser->exists();

    try {
        print "Updating uidNumber mapping for user '$uid' (uidNumber: $uidNumber)\n";
        $sambaUser->setupUidMapping($uidNumber);
    } otherwise {
        my ($error) = @_;
        print "\tError: $error\n";
    };
}
print "\n";

print "Updating groups mappings...\n";
my $ldapGroups = $usersModule->groups();
foreach my $group (@{$ldapGroups}) {
    my $gid = $group->get('cn');
    my $gidNumber = $group->get('gidNumber');
    next unless defined $gid and defined $gidNumber;

    my $sambaGroup = new EBox::Samba::Group(samAccountName => $gid);
    next unless $sambaGroup->exists();

    try {
        print "Updating gidNumber mapping for group '$gid' (gidNumber: $gidNumber)\n";
        $sambaGroup->setupGidMapping($gidNumber);
    } otherwise {
        my ($error) = @_;
        print "\tError: $error\n";
    };
}
print "\n";

print "Done.\n";
