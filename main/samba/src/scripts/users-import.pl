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
            print "Domain user '$samAccountName' imported successfully.";

    	    addToGroup($samAccountName, $groups);

            if ($mail) {
                set_user_mail($user, $mail);
            }
        } catch ($e){
            warn "Failed to import the domain user '$samAccountName': $e\n";
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
        $container = EBox::Samba::User->defaultContainer();
	    print "LDAP Object with DN $parentDN not found, giving default container: " . $container->dn() . "\n";
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
            print "Domain user '$user' added to group '$group'\n";
        } catch ($e) {
            warn "Cannot add user to group '$group': $e\n";
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
    print "\nMail '$mail' assigned using Mail module to the domain user '$user'\n";
}

sub setMailWithSamba {
    my ($user, $mail) = @_;

    my $global = EBox::Global->getInstance();
    my $mod = $global->modInstance('samba');

    $mod->checkMailNotInUse($mail);

    $user->set('mail', $mail, 1);
    $user->save();
    print "\nMail '$mail' assigned using Samba module to the domain user '$user'\n";
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

    die "Usage: $0 <source-file>\n" unless @args == 1;

    print "Importing users from file: $args[0]\n";
    readCSV($args[0]);
}

getParms(@ARGV);
