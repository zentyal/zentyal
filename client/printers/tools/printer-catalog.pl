#!/usr/bin/perl
use Foomatic::DB;
use Data::Dumper;
use File::Find;

my $db = new Foomatic::DB;

find(\&wanted, "/usr/share/ppd");

my %strings;

sub add {
	my ($string, $vendor) = @_;
	if ( $string =~ m/^-?\d+(\.\d+)?$/ ) { return };
	if ( $string =~ m/^\d+x\d+$/ ) { return };
	if ( $string =~ m/$vendor/ ) { return };
	$strings{$string} = 1;
}

sub wanted {
	-f $_ or return;
#	print STDERR "Processing $_\n";
	my $vendor = (split("/",$File::Find::name))[4];
	$db->getdatfromppd($_);
	foreach my $group (@{$db->{'dat'}->{'args'}}) {
		add($group->{'comment'},$vendor);
		foreach my $val (@{$group->{'vals'}}) {
			add($val->{'comment'},$vendor);
		}
	}
}

print qq{
msgid ""
msgstr ""
"Project-Id-Version: PACKAGE VERSION\\n"
"Report-Msgid-Bugs-To: bugs@warp.es\\n"
"POT-Creation-Date: 2005-03-03 17:11+0100\\n"
"PO-Revision-Date: 2005-03-03 17:11+0100\\n"
"Language-Team: LANGUAGE <LL@li.org>\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
};

foreach my $string (keys(%strings)) {
	print "\n";
	print "msgid \"$string\"\n";
	print "msgstr \"\"\n";
}
