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

# Class: EBox::Samba::Model::ImportUsers
#
#   This model provides the UI for importing domain users from CSV.
#   The actual import is handled by the ImportUsers CGI using
#   Zentyal's ProgressIndicator infrastructure.
#
package EBox::Samba::Model::ImportUsers;

use base 'EBox::Model::DataForm::Action';

use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;
use EBox::Types::File;
use EBox::Exceptions::External;
use EBox::ProgressIndicator;
use EBox::WebAdmin;

use TryCatch;
use File::MMagic;
use FileHandle;
use File::Slurp;
use Filesys::Df;
use POSIX;

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless ( $self, $class );

    return $self;
}

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
        'printableActionName' => __('Upload file and import users'),
        'automaticRemove' => 1,
        'defaultActions' => ['add', 'del', 'editField', 'changeView'],
        'tableDescription' => \@tableHead,
        'class' => 'dataTable',
        'modelDomain' => 'Samba',
    };

    return $dataTable;
}

sub formSubmitted
{
    my ($self, $row) = @_;
    my $csvField  = $row->elementByName('usersCSV');
    my $csv = $csvField->tmpPath();
    my $fileName = $csvField->userPath();

    unless ($csv && $fileName && -f $csv) {
        throw EBox::Exceptions::External(
            __('You must select a CSV file before importing.')
        );
    }

    my $path = EBox::Config::tmp() . $fileName;

    system("cp '$csv' '$path'");

    try {
        $self->_checkCSVFile($path);
        $self->_checkSize($csv);

        # Count lines for totalTicks
        my @lines = read_file($csv);
        my @validLines = grep { $_ !~ /^\s*$/ && $_ !~ /^\s*#/ } @lines;
        my $totalTicks = scalar(@validLines);
        $totalTicks = 1 if ($totalTicks < 1);

        my $script = '/usr/share/zentyal-samba/users-import.pl';
        my $executable = "$script $csv";

        my $progressIndicator = EBox::ProgressIndicator->create(
            executable => $executable,
            totalTicks => $totalTicks,
        );
        $progressIndicator->runExecutable();

        # Store progress ID so the Viewer can show a link
        $self->{progressId} = $progressIndicator->id();

        # Build a message with JS redirect to progress page
        my $pId = $progressIndicator->id();
        my $msg = __('Import started. Redirecting to progress view...');
        $msg .= "<script>window.location.href='/Progress?progress=$pId"
              . "&title=" . __('Importing Users')
              . "&currentItemCaption=" . __('Current operation')
              . "&itemsLeftMessage=" . __('users processed')
              . "&endNote=" . __('Import finished')
              . "&errorNote=" . __('Some errors occurred during import')
              . "&nextStepUrl=/Samba/Composite/ImportExport"
              . "&nextStepText=" . __('Go back to Import/Export')
              . "';</script>";
        $self->setMessage($msg, 'note');
    } catch ($e) {
        my $errorMsg = 'Error while importing: ' . $e->text();
        EBox::error($errorMsg);
        unlink $csv if (-f $csv);
        throw EBox::Exceptions::External(
            __x("Error importing users: {err}", err => $e->text())
        );
    }
}

sub _setDefaultMessages
{
    my ($self) = @_;

    unless (exists $self->table()->{'messages'}->{'update'}) {
        $self->table()->{'messages'}->{'update'} = __('Users import started');
    }
}

sub Viewer
{
    return '/ajax/form.mas';
}

sub _checkCSVFile
{
    my ($self, $path) = @_;

    my $mm = new File::MMagic();
    my $mimeType = $mm->checktype_filename($path);

    system("rm -f $path");

    if ($mimeType eq 'text/plain' || $mimeType eq 'text/csv') {
        return 1;
    }

    throw EBox::Exceptions::External(__x("The file is not a correct CSV file: {mimeType}", mimeType => $mimeType));
}

sub _checkSize
{
    my ($self, $archive) = @_;

    my $size;
    my $freeSpace;
    my $safetyFactor = 2;

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

sub precondition
{
    my ($self) = @_;

    my $ed = EBox::Global->communityEdition();
    my $dep = $self->parentModule()->isEnabled();

    if ($ed) {
        return 0;
    }

    if (! $dep) {
        return 0;
    }

    return 1;
}

1;
