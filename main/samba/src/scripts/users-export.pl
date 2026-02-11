#!/usr/bin/perl

use strict;

use EBox;
use EBox::Samba::User;
use EBox::Samba::Group;
use EBox::ProgressIndicator;

use TryCatch;
use File::Spec;
use File::Temp;
use File::Copy;
use Getopt::Long;
use Scalar::Util qw(blessed);

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

sub getUsers
{
    my $samba = EBox::Global->modInstance('samba');

    my @allUsers = @{ $samba->users() };
    my @usersToExport = grep { $_->isInternal() ne 0 } @allUsers;
    my $total = scalar(@usersToExport);

    if ($progress) {
        $progress->setTotalTicks($total);
    }

    foreach my $u (@usersToExport) {
        if ($progress) {
            $progress->setMessage("Exporting " . $u->get('samAccountName'));
            $progress->notifyTick();
        }

        push @lines,
            $u->get('samAccountName') . ';'
          . $u->parent()->dn() . ';'
          . $u->get('givenName') . ';'
          . $u->get('sn') . ';'
          . $u->initials() . ';'
          . $u->displayName() . ';'
          . $u->description() . ';'
          . $u->mail() . ';'
          . 'password' . ';'
          . getUserGroups($u) . ";\n";
        print "Exporting " . $u->get('samAccountName') . " done...\n";
    }
    return @lines;
}

sub getUserGroups
{
    my($u) = @_;

    my $groups;

    foreach my $g(@ { $u-> groups(internal => 0, system => 1) } ) {
        $groups = $groups . $g->dn() . ':';
    }

    return substr($groups, 0, -1);
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
    print $fh getUsers();
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
    print "Users have been exported to file '$destPath'\n";

    return 1;
}

sub main
{
    if ($progressId) {
        $progress = EBox::ProgressIndicator->retrieve($progressId);
    }

    print "Exporting users to file: $destFile\n";
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
