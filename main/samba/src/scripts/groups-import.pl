#!/usr/bin/perl

use strict;
use warnings;

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

        next if $line =~ /^\s*$/;   # empty
        next if $line =~ /^\s*#/;   # comment

        my @fields = split(';', $line, -1);  # keep trailing empty fields

        if (scalar(@fields) != 6) {
            warn "Invalid CSV format (expected 6 fields): $line\n";
            next;
        }

        my (
            $groupname,
            $parentDN,
            $description,
            $mail,
            $isSecurityGroup,
        ) = @fields;

        try {
            EBox::Samba::Group -> create(
                name => $groupname,
                parent => getLDAPContainer($parentDN),
                description => $description,
                mail => $mail,
                isSecurityGroup => $isSecurityGroup,
            );
            print "Domain group '$groupname' imported successfully.\n";
        } catch ($e){
            warn "Failed to import the domain group '$groupname': $e\n";
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
	    warn "Failed to get LDAP container for DN '$parentDN': $e\n";
        $container = EBox::Samba::Group->defaultContainer();
	    warn "LDAP Object with DN $parentDN not found, giving default container: " . $container->dn() . "\n";
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

    die "Usage: ./group-importer <source-file> \n" unless @args == 1;

    print "Importing groups from file: $args[0]\n";
    readCSV($args[0]);
}

getParms(@ARGV);
