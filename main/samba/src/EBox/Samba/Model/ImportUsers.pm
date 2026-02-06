# Copyright (C) 2012-2013 Zentyal S.L.
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

# Class: EEBox::Samba::Model::ImportUsers
#
#   This model is used to manage the domain users importation
#
package EBox::Samba::Model::ImportUsers;

use base 'EBox::Model::DataForm::Action';

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Types::File;
use EBox::Exceptions::External;

use TryCatch;
use File::MMagic;
use FileHandle;
use File::Slurp;
use Filesys::Df;
use Data::Dumper;

# Constructor: new
#
#       Create the new ExportUsers model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless ( $self, $class );

    return $self;
}

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHead = (
        new EBox::Types::File(
            fieldName => 'usersCSV',
            printableName => __(q{Upload users CSV}),
            editable => 1,
            filePath   => EBox::Config::tmp() . 'user-importer',
        ),
    );

    my $dataTable = {
        'tableName' => __PACKAGE__->nameFromClass(),
        'printableTableName' => __('Import domain users from CSV file'),
        'printableActionName' => 'Upload file and import users',
        'automaticRemove' => 1,
        'defaultActions' => ['add', 'del', 'editField',  'changeView' ],
        'tableDescription' => \@tableHead,
        'class' => 'dataTable',
        'modelDomain' => 'Samba',
    };

    return $dataTable;
}

# Method: formSubmitted
#
# Overrides:
#
#       <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self, $row) = @_;
    my $csvField  = $row->elementByName('usersCSV');
    my $csv = $csvField->tmpPath();
    my $fileName = $csvField->userPath();
    my $path = EBox::Config::tmp().$fileName;
    
    system("cp '$csv' '$path'");
    
    try {
        $self->_checkCSVFile($path);
        $self->_checkSize($csv);
        $self->run($csv);
    } catch ($e) {
        my $errorMsg = 'Error while restoring: ' . $e->text();
        EBox::error($errorMsg);
        throw EBox::Exceptions::External(
            __x("Error importing users: {err}", err => $e->text())
        );
        $e->throw();
    }
    unlink $csv if (-f $csv);
}

# Method: _setDefaultMessages
#
# Overrides:
#
#      <EBox::Model::DataTable::_setDefaultMessages>
#
sub _setDefaultMessages
{
    my ($self) = @_;

    unless (exists $self->table()->{'messages'}->{'update'}) {
        $self->table()->{'messages'}->{'update'} = __('Users was imported successfully');
    }
}

# Method: Viewer
#
# Overrides:
#
#        <EBox::Model::DataTable::Viewer>
#
sub Viewer
{
    return '/ajax/form.mas';
}

# Method: _checkCSVFile
#
#     Checks whether the CSV file has the right mime type
#
sub _checkCSVFile
{
    my ($self, $path) = @_;

    my $mm = new File::MMagic();
    my $mimeType = $mm->checktype_filename($path);

    system("rm -f $path");

    #FIXME
    if ($mimeType eq 'text/plain') {
        return 1;
    }

    if ($mimeType ne 'text/csv' || $mimeType ne 'text/plain') {
        throw EBox::Exceptions::External(__x("The file is not a correct CSV file: {mimeType}", mimeType => $mimeType));
    }
}

# Method: _checkSize
#
#     Checks whether the system has enough free space
#
sub _checkSize
{
    my ($self, $archive) = @_;

    my $size;
    my $freeSpace;
    my $safetyFactor = 2; # I multiply the CSV size by this number. The value was guessed, so change it if you need

    try {
        my @stat = stat $archive;
        $size = $stat[7];
    } catch ($ex) {
        EBox::Sudo::silentRoot("rm -rf '$archive") if (defined $archive);
        $ex->throw();
    }

    if (not $size) {
        EBox::warn("File size not found. Can not check if there is enough space to complete the importation");
        return;
    }

    my $tmpDir = EBox::Config::tmp();
    $freeSpace = df($tmpDir, 1024)->{bfree};

    if ($freeSpace < ($size*$safetyFactor)) {
        throw EBox::Exceptions::External(__x("There is not enough space left in the hard disk to complete the import process. {size} Kb required. Free sufficient space and retry", size => $size));
    }
}

# Method: run
#
#     Run the users importer script
#
sub run
{
    my ($self, $uploadedFile) = @_;
    my $script = '/usr/share/zentyal-samba/users-import.pl';
    my $command = $script . ' ' . $uploadedFile . ' 2>&1';
    EBox::info($command);
    
    my $output = `$command`;
    my $exitCode = $? >> 8;
    
    # Parse output for summary information
    my $successCount = 0;
    my $errorCount = 0;
    
    if ($output =~ /Successfully imported: (\d+)/) {
        $successCount = $1;
    }
    if ($output =~ /Failed to import: (\d+)/) {
        $errorCount = $1;
    }
    
    if ($exitCode != 0) {
        my @lines = split(/\n/, $output);
        my @errors;
        
        foreach my $line (@lines) {
            # Match "Failed to import" lines anywhere in the line (not just at start)
            if ($line =~ /Failed to import the domain user '([^']+)': (.+?)(?:\s+at\s+|$)/) {
                my $userName = $1;
                my $errorMsg = $2;
                # Clean up error message - remove redundant "at" clauses
                $errorMsg =~ s/\s+at\s+.*$//;
                push @errors, "<li><strong>$userName</strong>: $errorMsg</li>";
            }
        }
        
        my $formattedOutput = '';
        if (@errors) {
            $formattedOutput = "<ul>" . join("", @errors) . "</ul>";
        } else {
            # If we couldn't parse specific errors, show a generic message
            $formattedOutput = "<p>" . __('Some users could not be imported. Check the logs for details.') . "</p>";
        }
        $formattedOutput .= "<p><strong>Successfully imported:</strong> $successCount users</p>";
        $formattedOutput .= "<p><strong>Failed to import:</strong> $errorCount users</p>";
        
        my $msg = __('User import failed.') . "<br><br>" . $formattedOutput;
        throw EBox::Exceptions::External($msg);
    }
    
    # Success message with details
    my $successMsg = __('Users imported successfully!') . "<br><br>";
    $successMsg .= "<p><strong>" . __('Total users imported:') . "</strong> $successCount</p>";
    if ($errorCount > 0) {
        $successMsg .= "<p><strong>" . __('Users skipped:') . "</strong> $errorCount</p>";
    }
    
    EBox::info("User import completed successfully");
    $self->setMessage($successMsg, 'note');
    return $output;
}

# Method: precondition
#
#   Check if usersandgroups is enabled.
#
# Overrides:
#
#       <EBox::Model::DataTable::precondition>
#
sub precondition
{
    my ($self) = @_;

    my $ed = EBox::Global->communityEdition();
    my $dep = $self->parentModule()->isEnabled();

    # Return false if this is a community edition
    if ($ed) {
        return 0;
    }

    if (! $dep) {
        return 0;
    }

    return 1;
}

1;
