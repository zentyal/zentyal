#!/usr/bin/perl

BEGIN {
    # Silence locale warnings
    $ENV{LC_ALL} = 'C';
    $ENV{LANGUAGE} = 'C';
}

use strict;
use warnings;

use EBox;
use EBox::Gettext;
use EBox::Samba::Group;
use EBox::Samba::Container;
use EBox::Samba::OU;
use EBox::Validate;
use EBox::ProgressIndicator;

use File::Slurp;
use Cwd 'abs_path';
use TryCatch;
use Getopt::Long;
use Scalar::Util qw(blessed);

my $getParms;
my $getPath;
my $readCSV;
my $createLDAPGroups;
my $getLDAPContainer;
my @lines;

my $ERRORS = 0;
my $SUCCESS = 0;
my $SKIPPED = 0;
my @importResults;
my $progressId;
my $progress;

EBox::init();

sub createLDAPGroups
{
    my(@lines) = @_;

    # Filter out empty and comment lines for accurate count
    my @validLines = grep { $_ !~ /^\s*$/ && $_ !~ /^\s*#/ } @lines;
    my $total = scalar(@validLines);

    if ($progress) {
        $progress->setTotalTicks($total);
    }

    for my $line (@validLines) {

        my @fields = split(';', $line, -1);  # keep trailing empty fields

        if (scalar(@fields) != 6) {
            warn "Invalid CSV format (expected 6 fields): $line\n";
            $progress->notifyTick() if $progress;
            next;
        }

        my (
            $groupname,
            $parentDN,
            $description,
            $mail,
            $isSecurityGroup,
        ) = @fields;

        if ($progress) {
            $progress->setMessage(__x("Importing group '{group}'...",
                                      group => $groupname));
        }

        # Validate email if provided
        if ($mail) {
            unless (EBox::Validate::checkEmailAddress($mail)) {
                warn "Invalid email address '$mail' for group '$groupname'\n";
                $ERRORS++;
                push @importResults, { name => $groupname, status => 'failed', detail => __x("Invalid email: {mail}", mail => $mail) };
                $progress->notifyTick() if $progress;
                next;
            }
        }

        try {
            EBox::Samba::Group->create(
                name => $groupname,
                parent => getLDAPContainer($parentDN),
                description => $description,
                mail => $mail,
                isSecurityGroup => $isSecurityGroup,
            );
            print "Domain group '$groupname' imported successfully.\n";
            $SUCCESS++;
            push @importResults, { name => $groupname, status => 'created', detail => '' };
        } catch ($e) {
            my $errorText = blessed($e) ? $e->text() : "$e";
            if ($errorText =~ /already exists/) {
                print "Group '$groupname' already exists, skipping.\n";
                $SKIPPED++;
                push @importResults, { name => $groupname, status => 'skipped', detail => __('Already exists') };
            } else {
                warn "Failed to import the domain group '$groupname': $e\n";
                $ERRORS++;
                push @importResults, { name => $groupname, status => 'failed', detail => $errorText };
            }
        }

        $progress->notifyTick() if $progress;
    }

    print "\n=== IMPORT SUMMARY ===\n";
    print "Created: $SUCCESS | Skipped: $SKIPPED | Failed: $ERRORS\n";
    return $ERRORS == 0;
}

sub getLDAPContainer
{
    my ($parentDN) = @_;

    my $container = EBox::Samba::Container->new( dn => $parentDN );
    
    # Check if the container actually exists in LDAP
    unless ($container->exists()) {
        # Try to create the OU if it doesn't exist
        if ($parentDN =~ /^OU=([^,]+),(.+)$/) {
            my $ouName = $1;
            my $parentPath = $2;
            
            try {
                print "OU '$ouName' not found. Attempting to create it at $parentPath...\n";
                my $parent = EBox::Samba::Container->new( dn => $parentPath );
                $container = EBox::Samba::OU->create(
                    name => $ouName,
                    parent => $parent,
                );
                print "OU '$ouName' created successfully.\n";
            } catch ($createError) {
                warn "Failed to create OU '$ouName': $createError\n";
                $container = EBox::Samba::Group->defaultContainer();
                warn "Using default container: " . $container->dn() . "\n";
            }
        } else {
            warn "LDAP Object with DN $parentDN not found.\n";
            $container = EBox::Samba::Group->defaultContainer();
            warn "Using default container: " . $container->dn() . "\n";
        }
    }

    return $container;
}

sub readCSV
{
    my($p) = getPath(@_);
    my @lines = read_file($p);
    return createLDAPGroups(@lines);
}

sub getPath
{
    my($path) = @_;
    $path = abs_path($path);

    return $path;
}

sub buildSummaryHtml
{
    my ($entityType) = @_;
    my $total = $SUCCESS + $SKIPPED + $ERRORS;

    # Summary counts table
    my $html = '<div style="margin-top:10px;">';
    $html .= '<table style="width:100%;border-collapse:collapse;border:1px solid #ddd;">';
    $html .= '<thead><tr style="background:#f5f5f5;">';
    $html .= '<th style="padding:8px 12px;text-align:left;border-bottom:2px solid #ddd;" colspan="2">';
    $html .= __x('Import results ({total} {type} processed)', total => $total, type => $entityType);
    $html .= '</th></tr></thead><tbody>';

    if ($SUCCESS > 0) {
        $html .= '<tr><td style="padding:6px 12px;"><span style="color:#5cb85c;">&#10004;</span> ' . __('Created') . '</td>';
        $html .= '<td style="padding:6px 12px;text-align:right;font-weight:bold;">' . $SUCCESS . '</td></tr>';
    }
    if ($SKIPPED > 0) {
        $html .= '<tr><td style="padding:6px 12px;"><span style="color:#f0ad4e;">&#8856;</span> ' . __('Skipped (already exist)') . '</td>';
        $html .= '<td style="padding:6px 12px;text-align:right;font-weight:bold;">' . $SKIPPED . '</td></tr>';
    }
    if ($ERRORS > 0) {
        $html .= '<tr><td style="padding:6px 12px;"><span style="color:#d9534f;">&#10008;</span> ' . __('Failed') . '</td>';
        $html .= '<td style="padding:6px 12px;text-align:right;font-weight:bold;">' . $ERRORS . '</td></tr>';
    }
    $html .= '</tbody></table>';

    # Detail table for non-created entries
    my @details = grep { $_->{status} ne 'created' } @importResults;
    if (@details) {
        $html .= '<table style="width:100%;border-collapse:collapse;border:1px solid #ddd;margin-top:10px;">';
        $html .= '<thead><tr style="background:#f5f5f5;">';
        $html .= '<th style="padding:6px 12px;text-align:left;border-bottom:2px solid #ddd;">' . __('Name') . '</th>';
        $html .= '<th style="padding:6px 12px;text-align:left;border-bottom:2px solid #ddd;">' . __('Status') . '</th>';
        $html .= '<th style="padding:6px 12px;text-align:left;border-bottom:2px solid #ddd;">' . __('Details') . '</th>';
        $html .= '</tr></thead><tbody>';

        for my $r (@details) {
            my $color = $r->{status} eq 'skipped' ? '#f0ad4e' : '#d9534f';
            my $icon = $r->{status} eq 'skipped' ? '&#8856;' : '&#10008;';
            my $statusLabel = $r->{status} eq 'skipped' ? __('Skipped') : __('Failed');
            $html .= '<tr>';
            $html .= '<td style="padding:5px 12px;">' . $r->{name} . '</td>';
            $html .= '<td style="padding:5px 12px;color:' . $color . ';">' . $icon . ' ' . $statusLabel . '</td>';
            $html .= '<td style="padding:5px 12px;font-size:0.9em;">' . $r->{detail} . '</td>';
            $html .= '</tr>';
        }

        $html .= '</tbody></table>';
    }

    $html .= '</div>';
    return $html;
}

sub getParms
{
    my(@args) = @_;

    # Parse --progress-id if present (used by Zentyal web UI)
    GetOptions('progress-id=i' => \$progressId) or die "Bad options\n";

    if ($progressId) {
        $progress = EBox::ProgressIndicator->retrieve($progressId);
    }

    die "Usage: ./group-importer <source-file> \n" unless @ARGV == 1;

    print "Importing groups from file: $ARGV[0]\n";
    my $success;
    try {
        $success = readCSV($ARGV[0]);
    } catch ($e) {
        my $errorTxt = blessed($e) ? $e->text() : "$e";
        if ($progress) {
            $progress->setAsFinished(1, $errorTxt);
        }
        die $errorTxt;
    }

    if ($progress) {
        my $summaryHtml = buildSummaryHtml('groups');
        my $hasErrors = ($ERRORS > 0) ? 1 : 0;
        $progress->setAsFinished($hasErrors, $summaryHtml);
    }

    exit($ERRORS == 0 ? 0 : 1);
}

getParms(@ARGV);
