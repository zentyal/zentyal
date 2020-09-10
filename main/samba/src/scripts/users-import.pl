#!/usr/bin/perl
use strict;
use warnings;

use EBox;
use EBox::Samba::User;
use EBox::Samba::Container;
use EBox::Samba::Group;

use File::Slurp;
use Cwd 'abs_path';
use TryCatch;

EBox::init();

sub createLDAPUsers 
{
    my(@lines) = @_;

    for my $line(@lines) {
        my($samAccountName, $parentDN, $givenName, $initials, $sn, $displayName, $description, $mail, $password, $isSystemUser, $uid, $groups) = split(';', $line);
	    try {
            EBox::Samba::User->create(
                samAccountName => $samAccountName, 
                parent => getLDAPContainer($parentDN),
                givenName => $givenName,
                initials => $initials,
                sn => $sn,
                displayName => $displayName,
                description => $description,
                mail => $mail,
                name => $samAccountName,
                password => $password,
            );
            print "$samAccountName OK\n";
        } catch ($e){
            warn "Caught error: $e";
        }
	    addToGroup($samAccountName, $groups)
    }
}

sub getLDAPContainer 
{
    my ($parentDN) = @_;
    my $container;
    try {
        $container = EBox::Samba::Container->new( dn => $parentDN );
    }
    catch ($e) {
	    print "$e\n"; 
        $container = EBox::Samba::User->defaultContainer();
	    print "LDAP Object with DN $parentDN not found, giving default container: " . $container->dn() . "\n";
    }

    return $container;
}

sub addToGroup 
{ 
    my ($user, $groupsString) = @_;
    my @groups = split(/:/,$groupsString);
    foreach my $group (@groups) {
        my $g = EBox::Samba::Group->new( dn => $group );
        my $u = EBox::Samba::User->new( samAccountName => $user);
        try {
                $g->addMember($u);
        } catch ($e) {
            warn "$e\n";
        }
        print "$user added to $group\n";
    }
}

sub readCSV 
{
    my($p) = getPath(@_);
    my @lines = read_file($p);
    createLDAPUsers(@lines);
}

sub getPath 
{
    my($path) = @_;
    $path = abs_path($path);

    return $path;
}

sub getParms 
{
    my(@args) = @_;
    if (scalar @args < 1 or scalar @args > 1) {
        print "Usage: ./user-importer <source-file> \n";
    } else {
        readCSV($args[0]);
    }
}

getParms(@ARGV);
