#!/usr/bin/perl

BEGIN {
    # Silence locale warnings
    $ENV{LC_ALL} = 'C';
    $ENV{LANGUAGE} = 'C';
}

use strict;
use warnings;

use EBox;
use EBox::Samba::Group;
use EBox::Samba::Container;
use EBox::Samba::OU;
use EBox::Validate;

use File::Slurp;
use Cwd 'abs_path';
use TryCatch;

my $getParms;
my $getPath;
my $readCSV;
my $createLDAPGroups;
my $getLDAPContainer;
my @lines;

my $ERRORS = 0;
my $SUCCESS = 0;

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

        # Validate email if provided
        if ($mail) {
            unless (EBox::Validate::checkEmailAddress($mail)) {
                warn "Invalid email address '$mail' for group '$groupname'\n";
                $ERRORS++;
                next;
            }
        }

        try {
            EBox::Samba::Group -> create(
                name => $groupname,
                parent => getLDAPContainer($parentDN),
                description => $description,
                mail => $mail,
                isSecurityGroup => $isSecurityGroup,
            );
            print "Domain group '$groupname' imported successfully.\n";
            $SUCCESS++;
        } catch ($e){
            warn "Failed to import the domain group '$groupname': $e\n";
            $ERRORS++;
        }
    }
    
    print "\n=== IMPORT SUMMARY ===\n";
    print "Successfully imported: $SUCCESS groups\n";
    print "Failed to import: $ERRORS groups\n";
    return $ERRORS == 0;
}

sub getLDAPContainer
{
    my ($parentDN) = @_;

    my $container = EBox::Samba::Container->new( dn => $parentDN );
    
    # Check if the container actually exists in LDAP
    unless ($container->exists()) {
        # Try to create the OU if it doesn't exist
        if ($parentDN =~ /^OU=([^,]+),(.+)$/) {
            my $ouName = $1;
            my $parentPath = $2;
            
            try {
                print "OU '$ouName' not found. Attempting to create it at $parentPath...\n";
                my $parent = EBox::Samba::Container->new( dn => $parentPath );
                $container = EBox::Samba::OU->create(
                    name => $ouName,
                    parent => $parent,
                );
                print "OU '$ouName' created successfully.\n";
            } catch ($createError) {
                warn "Failed to create OU '$ouName': $createError\n";
                $container = EBox::Samba::Group->defaultContainer();
                warn "Using default container: " . $container->dn() . "\n";
            }
        } else {
            warn "LDAP Object with DN $parentDN not found.\n";
            $container = EBox::Samba::Group->defaultContainer();
            warn "Using default container: " . $container->dn() . "\n";
        }
    }

    return $container;
}

sub readCSV
{
    my($p) = getPath(@_);
    my @lines = read_file($p);
    return createLDAPGroups(@lines);
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
    my $success = readCSV($args[0]);
    exit($success ? 0 : 1);
}

getParms(@ARGV);
