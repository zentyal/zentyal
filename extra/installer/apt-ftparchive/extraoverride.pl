#! /usr/bin/perl
# extraoverride.pl
# generate ExtraOverride file
# use as follows :-
# extraoverride.pl < /opt/cd-image/dists/dapper/main/binary-i386/Packages >> /opt/indices/override.dapper.extra.main

while (<>) {
        chomp;
        next if /^ /;
        if (/^$/ && defined($task)) {
                print "$package Task $task\n";
                undef $package;
                undef $task;
        }
        ($key, $value) = split /: /, $_, 2;
        if ($key eq 'Package') {
                $package = $value;
        }
        if ($key eq 'Task') {
                $task = $value;
        }
}