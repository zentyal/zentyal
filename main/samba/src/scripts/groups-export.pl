#!/usr/bin/perl

use strict;

use EBox;
use EBox::Global;
use EBox::ProgressIndicator;
use File::Spec;
use File::Temp;
use File::Copy;
use Getopt::Long;
use Scalar::Util qw(blessed);
use TryCatch;

my @lines;
my $progressId;
my $progress;

# Parse CLI args BEFORE EBox::init() drops privileges (setuid to ebox)
GetOptions('progress-id=i' => \$progressId) or die "Bad options\n";
die "Usage: $0 <dest-file>\n" unless @ARGV == 1;

# Save destination path while we are still root
my $destFile = File::Spec->rel2abs($ARGV[0]);

# Check if destination directory is writable BEFORE dropping privileges
my ($destDir) = $destFile =~ m{^(.*/)};   
$destDir = '.' unless $destDir;
unless (-d $destDir && -w $destDir) {
    die "Directory '$destDir' is not writable. Please check permissions.\n";
}

# Now drop privileges
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
    $path = File::Spec->rel2abs($path);

    return $path;
}

sub writeCSV
{
    my ($destPath) = @_;

    # Write to a temp file (writable by ebox user)
    my $tmpFile = File::Temp->new(SUFFIX => '.csv', UNLINK => 0, DIR => '/tmp');
    my $tmpPath = $tmpFile->filename();

    open( my $fh, '>', $tmpPath )
      or die "Could not create temp file '$tmpPath': $!\n";
    print $fh getGroups();
    close $fh;

    # Copy temp file to final destination
    # Try direct copy first (works when dest is writable by current user, e.g. web UI)
    if (File::Copy::copy($tmpPath, $destPath)) {
        chmod(0644, $destPath);
    } else {
        # Fall back to sudo cp for CLI usage where dest may not be writable by ebox
        my $rc = system('sudo', 'cp', $tmpPath, $destPath);
        if ($rc != 0) {
            unlink $tmpPath;
            die "Failed to copy export file to '$destPath'\n";
        }
        system('sudo', 'chmod', '644', $destPath);
    }
    unlink $tmpPath;
    print "Groups have been exported to file '$destPath'\n";

    return 1;
}

sub main
{
    if ($progressId) {
        $progress = EBox::ProgressIndicator->retrieve($progressId);
    }

    print "Exporting domain groups to file: $destFile\n";
    try {
        writeCSV($destFile);
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

main();
