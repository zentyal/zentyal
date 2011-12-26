#!/usr/bin/perl

use warnings;
use strict;

use File::Basename;
use File::Slurp;

my ($olddir, $newdir, $package, $nowarnings) = @ARGV;

my %oldfiles = get_file_sizes(glob ("$olddir/*.deb"));
my %newfiles = get_file_sizes(glob ("$newdir/*.deb"));

my @lines = read_file('moved_files.list');
chomp(@lines);
my %moved = map { $_ => 1 } @lines;

for my $name (keys %oldfiles) {
    next if (defined ($package) and ($name ne $package));

    unless (exists $newfiles{$name}) {
        print "ERROR: $name does not exists in the new packages\n";
        next;
    }
    for my $file (keys %{$oldfiles{$name}}) {
        next if ($moved{$file});

        unless (exists $newfiles{$name}->{$file}) {
            print "ERROR: $file does not exists in the new $name\n";
            next;
        }
        next if ($nowarnings);
        unless ($newfiles{$name}->{$file} eq $oldfiles{$name}->{$file}) {
            print "WARNING: sizes for file $file do not match\n";
        }
    }
}

sub get_file_sizes
{
    my (@packages) = @_;

    my %files;
    foreach my $pkg (@packages) {
        my @lines = `dpkg -c $pkg`;
        chomp (@lines);
        $pkg = basename($pkg);
        $pkg =~ s/^zentyal-//;
        $pkg =~ s/_.*$//;
        $files{$pkg} = {};
        for my $line (@lines) {
            my (undef, undef, $size, undef, undef, $file) = split (/\s+/, $line);
            next if ($file =~ /changelog.gz$/);
            $files{$pkg}->{$file} = $size;
        }
    }
    return %files;
}
