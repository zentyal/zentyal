#!/usr/bin/perl -w
#
# Author: Petter Reinholdtsen <pere@hungry.com>
# Date:   2001-11-20
#
# Parse logfile from Debian debian-cd build, and report how much each package
# added to the CD size.

$logfile = ($ARGV[0] ||
            "$ENV{TDIR}/$ENV{CODENAME}-$ENV{ARCH}/log.list2cds");

open(LOG, $logfile) || die "Unable to open $logfile";

my $pkg;
while (<LOG>) {
    chomp;
    $pkg = $1 if (/^\+ Trying to add (.+)\.\.\./);
    if (/  \$cd_size = (\d+), \$size = (\d+)/) {
	$cdsize{$pkg} = $1;
	$size{$pkg} = $2;
    }
    last if (/Limit for CD 2 is/);
    # Add delimiter
    if (/Standard system already takes (.\d+)/) {
	my $pkg = "<=============== end of standard pkgs";
        $size{$pkg} = 0;
        $cdsize{$pkg} = $1;
    }
}
close(LOG);

print "  +size  cdsize pkgname\n";
print "-----------------------\n";

for $pkg (sort { $cdsize{$a} <=> $cdsize{$b} } keys %size) {
    printf "%7d %7d %s\n", $size{$pkg} / 1024, $cdsize{$pkg} / 1024, $pkg;
}
