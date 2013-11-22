#!/usr/bin/perl -w

# Copyright (C) 2008-2013 Zentyal S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

# external_acl helper to Squid to verify AD domain group
# membership based on group SID
#
# Based on wbinfo_group.pl written by Jerry Murdock <jmurdock@itraktech.com>

use Getopt::Long;
use File::Temp qw(tempfile);
use Authen::SASL qw(Perl);
use Authen::Krb5::Easy qw(kinit kdestroy kerror);
use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value canonical_dn);
use Data::Hexdumper;
use Time::HiRes;
use POSIX;

use constant LOG_DEBUG   => 0;
use constant LOG_INFO    => 1;
use constant LOG_ERROR   => 2;

my %opt;

sub logevent
{
    my ($level, $msg) = @_;

    return if ($level == LOG_DEBUG and not $opt{d});

    my ($x,$y) = Time::HiRes::gettimeofday();
    my $timestamp = POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime ($x));
    $timestamp .= ".$y";

    if ($level == LOG_DEBUG) {
        $level = 'DEBUG';
    } elsif ($level == LOG_INFO) {
        $level = 'INFO';
    } elsif ($level == LOG_ERROR) {
        $level = 'ERROR';
    }

    $msg = "$timestamp $level> $msg\n";

    print STDERR $msg;
    if (length $opt{l}) {
        open (my $log, '>>', $opt{l}) or return;
        print $log $msg;
        close ($opt{l});
    }
}

# Method: adLdap
#
#   Check if we are already connected and the connection is alive. Otherwise
#   open a new connection to AD LDAP
#
sub adLdap
{
    my $reconnect = 0;
    if (defined $opt{ldap}) {
        my $result = $opt{ldap}->search(
            base => '',
            scope => 'base',
            filter => "(cn=*)");
        if ($result->is_error()) {
            delete $opt{ldap};
            $reconnect = 1;
        }
    }

    if (not defined $opt{ldap} or $reconnect) {
        logevent(LOG_INFO, "Reconnecting to LDAP");
        my $keytab = $opt{k};
        my $server = $opt{h};
        my $princ = $opt{s};

        # Get credentials for computer account
        my $ok = kinit($keytab, $princ);
        unless (defined $ok and $ok == 1) {
            logevent(LOG_ERROR, "Unable to get kerberos ticket: " . kerror());
            delete $opt{ldap};
            return undef;
        }

        # Set up a SASL object
        my $sasl = new Authen::SASL(mechanism => 'GSSAPI');
        unless ($sasl) {
            logevent(LOG_ERROR, "Unable to setup SASL object: $@");
            delete $opt{ldap};
            return undef;
        }

        # Set up an LDAP connection
        my $ldap = new Net::LDAP($server);
        unless ($ldap) {
            logevent(LOG_ERROR, "Unable to setup LDAP object: $@");
            delete $opt{ldap};
            return undef;
        }

        # Check GSSAPI support
        my $dse = $ldap->root_dse(attrs => ['defaultNamingContext', '*']);
        unless ($dse->supported_sasl_mechanism('GSSAPI')) {
            logevent(LOG_ERROR, "AD LDAP server does not support GSSAPI");
            delete $opt{ldap};
            return undef;
        }

        # Finally bind to LDAP using our SASL object
        my $msg = $ldap->bind(sasl => $sasl);
        if ($msg->is_error()) {
            logevent(LOG_ERROR, "Unable to bind: " . $msg->error_desc());
            delete $opt{ldap};
            return undef;
        }

        # Clear acquired credentials
        kdestroy();

        $opt{ldap} = $ldap;
    }

    return $opt{ldap};
}

#
# Check if a user belongs to a group
#
sub check
{
    my ($user, $groupSID) = @_;

    logevent(LOG_INFO, "Checking if user '$user' belongs to group '$groupSID'");
    logevent(LOG_DEBUG, "\n" . hexdump(data => $user, suppress_warnings => 1));
    logevent(LOG_DEBUG, "\n" . hexdump(data => $groupSID, suppress_warnings => 1));

    if ($opt{K} && ($user =~ m/\@/)) {
        my @tmpuser = split (/\@/, $user);
        $user = $tmpuser[0];
        logevent(LOG_DEBUG, "Realm strip enabled, username changed to '$user'");
    }

    unless (defined $groupSID and length $groupSID) {
        logevent(LOG_ERROR, "Undefined group SID");
        return 'ERR';
    }

    unless (defined $user and length $user) {
        logevent(LOG_ERROR, "Undefined user");
        return 'ERR';
    }

    my $ldap = adLdap();
    unless (defined $ldap) {
        logevent(LOG_ERROR, "Could not connect to AD LDAP");
        return 'ERR';
    }

    # Get default naming context
    my $rootDSE = $ldap->root_dse(attrs => ['defaultNamingContext']);
    my $defaultNC = $rootDSE->get_value('defaultNamingContext');

    # Get the user DN
    my $result = $ldap->search(
        base => $defaultNC,
        scope => 'sub',
        filter => "(&(objectClass=user)(samAccountName=$user))",
        attrs => ['distinguishedName']);
    if ($result->is_error()) {
        logevent(LOG_ERROR, "Error in LDAP search: " . $result->error_desc());
        delete $opt{ldap};
        return 'ERR';
    }
    unless ($result->count() == 1) {
        logevent(LOG_ERROR, "No user DN found for samAccountName '$user'\n");
        return 'ERR';
    }
    my $userEntry = $result->entry(0);
    my $userDN = $userEntry->dn();
    logevent(LOG_DEBUG, "User DN is '$userDN'");

    # Get the group DN
    $result = $ldap->search(
        base => $defaultNC,
        scope => 'sub',
        filter => "(&(objectClass=group)(objectSid=$groupSID))",
        attrs => ['distinguishedName']);
    if ($result->is_error()) {
        logevent(LOG_ERROR, "Error in LDAP search: " . $result->error_desc());
        delete $opt{ldap};
        return 'ERR';
    }
    unless ($result->count() == 1) {
        logevent(LOG_ERROR, "No group DN found for SID '$groupSID'\n");
        return 'ERR';
    }
    my $groupEntry = $result->entry(0);
    my $groupDN = $groupEntry->dn();
    logevent(LOG_DEBUG, "Group DN is '$groupDN'");

    # Check user membership against group. The string 1.2.840.113556.1.4.1941
    # specifies LDAP_MATCHING_RULE_IN_CHAIN to look inside nested groups.
    # This is an extended match operator that walks the chain of ancestry in
    # objects all the way to the root until it finds a match. This reveals
    # group nesting. It is available only on domain controllers with
    # Windows Server 2003 SP2 or above
    $userDN = canonical_dn($userDN);
    $groupDN = canonical_dn($groupDN);
    $groupDN = escape_filter_value($groupDN);
    my $filter = "(memberOf:1.2.840.113556.1.4.1941:=$groupDN)";
    logevent(LOG_DEBUG, "LDAP search filter is '$filter'");
    $result = $ldap->search(
        base => $userDN,
        scope => 'base',
        filter => $filter,
        attrs => ['*']);
    if ($result->is_error()) {
        logevent(LOG_ERROR, "Error in LDAP search: " . $result->error_desc());
        delete $opt{ldap};
        return 'ERR';
    }
    my $count = $result->count();
    my $member = ($count == 1);
    logevent(LOG_DEBUG, "Search has returned $count results");
    logevent(LOG_DEBUG, "Member: $member");
    return 'OK' if ($member);

    return 'ERR';
}

#
# Command line options processing
#
sub init
{
    my $debug = undef;
    my $stripRealm = 0;
    my $log = undef;
    my $host = undef;
    my $keytab = undef;
    my $principal = undef;

    GetOptions("log=s" => \$log,
               "debug" => \$debug,
               "strip-realm" => \$stripRealm,
               "host=s" => \$host,
               "keytab=s" => \$keytab,
               "principal=s" => \$principal) or usage();

    unless (defined $host and defined $keytab and
            defined $principal) {
        usage();
    }

    $opt{l} = $log;
    $opt{d} = $debug;
    $opt{K} = $stripRealm;
    $opt{h} = $host;
    $opt{k} = $keytab;
    $opt{s} = $principal;
    $opt{ldap} = undef;
}

sub usage
{
    print "Usage: squid_ldap_group_sid.pl [options]\n";
    print "\t--host <host>              LDAP server to connect to\n";
    print "\t--keytab <path>            Keytab path to use to bind to LDAP\n";
    print "\t--principal <principal>    Principal name to use from keytab\n";
    print "\t--strip-realm              Strip Kerberos realm from user names\n";
    print "\t--debug                    Enable debugging\n";
    print "\t--log <path>               Log file path\n";
    exit;
}

# Disable output buffering
$|=1;

init();
logevent(LOG_INFO, "$0 started");

while (<STDIN>) {
    # Remove trailing \n
    chomp ($_);

    logevent(LOG_INFO, "Received request from squid '$_'");
    logevent(LOG_DEBUG, "\n" . hexdump(data => $_, suppress_warnings => 1));

    # Split the user and groups SIDs to check against
    my ($user, @groups) = split(/\s+/);

    # Test membership for each received group
    my $ans = 'ERR';
    foreach my $group (@groups) {
        $ans = check($user, $group);
        last if $ans eq "OK";
    }
    logevent(LOG_INFO, "Returning '$ans' to squid");
    print STDOUT "$ans\n";
}

exit 0;
