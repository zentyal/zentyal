#!/usr/bin/perl -w

# external_acl helper to Squid to verify AD domain group
# membership based on group SID
#
# Based on wbinfo_group.pl written by Jerry Murdock <jmurdock@itraktech.com>

use strict;
use warnings;

use Getopt::Long;
use File::Temp qw(tempfile);
use Authen::SASL qw(Perl);
use Authen::Krb5::Easy qw(kinit kdestroy kerror);
use Net::LDAP;

my %opt;

sub debug
{
	print STDERR "@_\n" if $opt{d};
}

sub error
{
	print STDERR "@_\n";
}

sub adLdap
{
    my ($self) = @_;

    # TODO Make connection persistent
    my $reconnect = 1;
    if ($reconnect) {
        my $keytab = $opt{k};
        my $server = $opt{h};
        my $princ = $opt{s};

        #my (undef, $filename) = tempfile('squid_ldap_group_sid_XXXXX.ccache', DIR => '/tmp');
        #my $ccache = '/tmp/squid_ldap_group_sid.ccache'; # TODO tmp filename
        #$ENV{KRB5CCNAME} = $ccache;

        # Get credentials for computer account
        my $ok = kinit($keytab, $princ);
        unless (defined $ok and $ok == 1) {
            error("Unable to get kerberos ticket to bind to LDAP: " . kerror());
            delete $opt{ldap};
            return undef;
        }

        # Set up a SASL object
        my $sasl = new Authen::SASL(mechanism => 'GSSAPI');
        unless ($sasl) {
            error("Unable to setup SASL object: $@");
            delete $opt{ldap};
            return undef;
        }

        # Set up an LDAP connection
        my $ldap = new Net::LDAP($server);
        unless ($ldap) {
            error("Unable to setup LDAP object: $@");
            delete $opt{ldap};
            return undef;
        }

        # Check GSSAPI support
        my $dse = $ldap->root_dse(attrs => ['defaultNamingContext', '*']);
        unless ($dse->supported_sasl_mechanism('GSSAPI')) {
            error("AD LDAP server does not support GSSAPI");
            delete $opt{ldap};
            return undef;
        }

        # Finally bind to LDAP using our SASL object
        my $bindResult = $ldap->bind(sasl => $sasl);
        if ($bindResult->is_error()) {
            error("Could not bind to AD LDAP server. Error was: " .
                  $bindResult->error_desc());
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

	if ($opt{K} && ($user =~ m/\@/)) {
		my @tmpuser = split (/\@/, $user);
		$user = $tmpuser[0];
	}

    debug("User:  -$user-\tGroup SID: -$groupSID-\n");
    return 'ERR' unless (length $groupSID);

    my $ldap = adLdap();
    return 'ERR' unless (defined $ldap);

    # Get default naming context
    my $rootDSE = $ldap->root_dse(attrs => ['defaultNamingContext', '*']);
    my $defaultNC = $rootDSE->get_value('defaultNamingContext');

    # Get group DN
    my $result = $ldap->search(
        base => $defaultNC,
        scope => 'sub',
        filter => "(&(objectClass=group)(objectSid=$groupSID))",
        attrs => ['*']);
    if ($result->is_error()) {
        error("Error in LDAP search: " . $result->error_desc());
        delete $opt{ldap};
        return 'ERR';
    }
    unless ($result->count() == 1) {
        error("No group found for SID -$groupSID-\n");
        return 'ERR';
    }
    my $groupEntry = $result->entry(0);
    my $groupDN = $groupEntry->dn();

    # Check user membership
    $result = $ldap->search(
        base => $defaultNC,
        scope => 'sub',
        filter => "(&(objectClass=user)(samAccountName=$user)(memberOf=$groupDN))",
        attrs => ['*']);
    if ($result->is_error()) {
        error("Error in LDAP search: " . $result->error_desc());
        delete $opt{ldap};
        return 'ERR';
    }
    return 'OK' if ($result->count() == 1);

    return 'ERR';
}

#
# Command line options processing
#
sub init
{
    my $debug = 0;
    my $stripRealm = 0;
    my $host = undef;
    my $keytab = undef;
    my $principal = undef;

    GetOptions("debug" => \$debug,
               "strip-realm" => \$stripRealm,
               "host=s" => \$host,
               "keytab=s" => \$keytab,
               "principal=s" => \$principal) or usage();

    unless (defined $host and defined $keytab and
            defined $principal) {
        usage();
    }

    $opt{d} = $debug;
    $opt{K} = $stripRealm;
    $opt{h} = $host;
    $opt{k} = $keytab;
    $opt{s} = $principal;
}

sub usage
{
	print "Usage: squid_ldap_group_sid.pl [options]\n";
	print "\t-d enable debugging\n";
	print "\t-h LDAP server\n";
	print "\t-K strip Kerberos realm from user names\n";
    print "\t-k keytab path\n";
    print "\t-s principal name to use from keytab\n";
	exit;
}

# Disable output buffering
$|=1;

init();
print STDERR "Debugging mode ON\n" if $opt{d};

while (<STDIN>) {
    chop;
	debug("Got '$_' from squid");
    my ($user, @groups) = split(/\s+/);
	$user =~ s/%([0-9a-fA-F][0-9a-fA-F])/pack("c",hex($1))/eg;

 	# test for each group squid send in it's request
    my $ans = 'ERR';
 	foreach my $group (@groups) {
		$group =~ s/%([0-9a-fA-F][0-9a-fA-F])/pack("c",hex($1))/eg;
 		$ans = check($user, $group);
 		last if $ans eq "OK";
 	}
	debug("Sending $ans to squid");
	print "$ans\n";
}

exit 0;
