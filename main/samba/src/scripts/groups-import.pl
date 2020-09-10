#!/usr/bin/perl
use strict;

use EBox;
use EBox::Samba::Group;
use EBox::Samba::Container;

use File::Slurp;
use Cwd 'abs_path';
use TryCatch;

my $getParms;
my $getPath;
my $readCSV;
my $createLDAPGroups;
my $getLDAPContainer;
my @lines;

EBox::init();

sub createLDAPGroups 
{
    my(@lines) = @_;

    for my $line(@lines) {
        my($groupname, $parentDN, $description, $mail, $isSecurityGroup, $isSystemGroup, $gidNumber) = split(';', $line);
        try {
            EBox::Samba::Group -> create(
                name => $groupname, 
                parent => getLDAPContainer($parentDN),
                description => $description,
                mail => $mail,
                isSecurityGroup => $isSecurityGroup,
                isSystemGroup => $isSystemGroup,
                gidNumber => $gidNumber
            );
            print "$groupname OK\n";
        } catch ($e){
            warn "Caught error: $e";
        }
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
        $container = EBox::Samba::Group->defaultContainer();
	    print "LDAP Object with DN $parentDN not found, giving default container: " . $container->dn() . "\n";
    }

    return $container;
}

sub readCSV 
{
    my($p) = getPath(@_);
    my @lines = read_file($p);
    createLDAPGroups(@lines);
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
        print "Usage: ./group-importer <source-file> \n";
    } else {
        readCSV($args[0]);
    }
}

getParms(@ARGV);
