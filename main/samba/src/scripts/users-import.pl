#!/usr/bin/perl

BEGIN {
    # Silence locale warnings
    $ENV{LC_ALL} = 'C';
    $ENV{LANGUAGE} = 'C';
}

use strict;
use warnings;

use EBox;
use EBox::Samba::User;
use EBox::Samba::Container;
use EBox::Samba::Group;
use EBox::Samba::OU;
use EBox::Validate;

use File::Slurp;
use Cwd 'abs_path';
use TryCatch;

EBox::init();

my $ERRORS = 0;
my $SUCCESS = 0;

sub createLDAPUsers
{
    my(@lines) = @_;

    for my $line(@lines) {
        my (
            $samAccountName,
            $parentDN,
            $givenName,
            $sn,
            $initials,
            $displayName,
            $description,
            $mail,
            $password,
            $groups
        ) = split(';', $line);

        next if $line =~ /^\s*$/;   # Is empty
        next if $line =~ /^\s*#/;   # Is comment

        # Validate email if provided
        if ($mail) {
            unless (EBox::Validate::checkEmailAddress($mail)) {
                warn "Invalid email address '$mail' for user '$samAccountName'\n";
                $ERRORS++;
                next;
            }
        }

	    try {
            my $user = EBox::Samba::User->create(
                samAccountName => $samAccountName,
                parent => getLDAPContainer($parentDN),
                givenName => $givenName,
                initials => $initials,
                sn => $sn,
                displayName => $displayName,
                description => $description,
                name => $samAccountName,
                password => $password,
            );
            print "\nDomain user '$samAccountName' imported successfully.\n";
            $SUCCESS++;

    	    addToGroup($samAccountName, $groups);

            if ($mail) {
                set_user_mail($user, $mail);
            }
        } catch ($e){
            warn "Failed to import the domain user '$samAccountName': $e\n";
            $ERRORS++;
        }
    }
    
    print "\n=== IMPORT SUMMARY ===\n";
    print "Successfully imported: $SUCCESS users\n";
    print "Failed to import: $ERRORS users\n";
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
                $container = EBox::Samba::User->defaultContainer();
                print "Using default container: " . $container->dn() . "\n";
            }
        } else {
            warn "LDAP Object with DN $parentDN not found.\n";
            $container = EBox::Samba::User->defaultContainer();
            print "Using default container: " . $container->dn() . "\n";
        }
    }

    return $container;
}

sub addToGroup
{
    my ($user, $groupsString) = @_;

    return unless $groupsString;

    my @groups = split(/:/,$groupsString);

    foreach my $group (@groups) {
        try {
            my $g = EBox::Samba::Group->new( dn => $group );
            my $u = EBox::Samba::User->new( samAccountName => $user);
            $g->addMember($u);
            print "Added to group '$group'\n";
        } catch ($e) {
            warn "\nCannot add user to group '$group': $e\n";
        }
    }
}

sub set_user_mail {
    my ($user, $mail) = @_;

    my $global = EBox::Global->getInstance();

    if ($global->modExists('mail') && $global->modInstance('mail')->isEnabled()) {
        setMailWithMail($user, $mail);
    } else {
        setMailWithSamba($user, $mail);
    }
}

sub setMailWithMail {
    my ($user, $mail) = @_;

    my $global = EBox::Global->getInstance();
    my $mod = $global->modInstance('mail');
    my $mailUser = EBox::MailUserLdap->new();

    $mod->checkMailNotInUse($mail);

    $mailUser->setUserAccount($user, $mail);
    print "Mail '$mail' assigned successfully.\n";
}

sub setMailWithSamba {
    my ($userObj, $mail) = @_;

    my $global = EBox::Global->getInstance();
    my $mod = $global->modInstance('samba');

    $mod->checkMailNotInUse($mail);

    $userObj->set('mail', $mail, 1);
    $userObj->save();
    print "Mail '$mail' assigned successfully.\n";
}

sub readCSV
{
    my($p) = getPath(@_);
    my @lines = read_file($p);
    return createLDAPUsers(@lines);
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

    die "Usage: $0 <source-file>\n" unless @args == 1;

    print "Importing users from file: $args[0]\n";
    my $success = readCSV($args[0]);
    exit($success ? 0 : 1);
}

getParms(@ARGV);
