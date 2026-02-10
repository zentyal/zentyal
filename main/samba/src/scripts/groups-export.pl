#!/usr/bin/perl

use strict;

use EBox;
use EBox::Global;
use EBox::ProgressIndicator;
use Cwd 'abs_path';
use Getopt::Long;
use Scalar::Util qw(blessed);
use TryCatch;

my @getGroups;
my $checkOptions;
my $getPath;
my $writeCSV;
my @lines;
my $gid;
my $progressId;
my $progress;

EBox::init();

sub getGroups
{
    my $samba = EBox::Global->modInstance('samba');

    my @allGroups = @{ $samba->groups() };
    my @groupsToExport = grep { !$_->isInternal() and $_->name ne 'Domain Admins' } @allGroups;
    my $total = scalar(@groupsToExport);

    if ($progress) {
        $progress->setTotalTicks($total);
    }

    foreach my $g (@groupsToExport) {
        if ($progress) {
            $progress->setMessage("Exporting " . $g->name());
            $progress->notifyTick();
        }

        push @lines,
            $g->name() . ';'
          . $g->parent()->dn() . ';'
          . $g->description() . ';'
          . $g->mail() . ';'
          . $g->isSecurityGroup() . ";\n";
    }

    return @lines;
}

sub getPath
{
    my ($path) = @_;
    $path = abs_path($path);

    return $path;
}

sub writeCSV
{
    my ($p) = getPath(@_);
    
    # Check if directory exists and is writable
    my ($dir) = $p =~ m{^(.*/)};
    $dir = '.' unless $dir;
    unless (-d $dir && -w $dir) {
        die "Directory '$dir' does not exist or is not writable\n";
    }
    
    open( my $fh, '>', $p )
      or die "Could not create file '$p': $!\n";
    print $fh getGroups();
    close $fh;
    print "Groups have been exported to file '$p'\n";

    return 1;
}

sub getParms
{
    my (@args) = @_;

    # Parse --progress-id if present (used by Zentyal web UI)
    GetOptions('progress-id=i' => \$progressId) or die "Bad options\n";

    if ($progressId) {
        $progress = EBox::ProgressIndicator->retrieve($progressId);
    }

    die "Usage: ./group-exporter <dest-file> \n" unless @ARGV == 1;

    print "Exporting domain groups to file: $ARGV[0]\n";
    try {
        writeCSV( $ARGV[0] );
        if ($progress) {
            $progress->setAsFinished(0);
        }
    } catch ($e) {
        my $errorTxt = blessed($e) ? $e->text() : "$e";
        if ($progress) {
            $progress->setAsFinished(1, $errorTxt);
        }
        die $errorTxt;
    }
}

getParms(@ARGV);
