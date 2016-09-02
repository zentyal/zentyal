# Copyright (C) 2012-2014 Zentyal S.L.
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

package EBox::Squid::Model::CategorizedLists;

use base 'EBox::Model::DataTable';

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Validate;
use EBox::Sudo;
use EBox::Types::Text::WriteOnce;
use EBox::Squid::Types::ListArchive;
use EBox::Exceptions::External;

use TryCatch;
use Perl6::Junction qw(any);
use File::Basename;

use constant LIST_FILE_DIR => '/var/lib/zentyal/files/squid/archives';

# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my @tableHeader = (
         new EBox::Types::Text::WriteOnce(
             fieldName => 'name',
             printableName => __('Name'),
             unique   => 1,
             editable => 1,
         ),
         new EBox::Squid::Types::ListArchive(
             fieldName     => 'fileList',
             printableName => __('File'),
             unique        => 1,
             editable      => 1,
             optional      => 1,
             allowDownload => 1,
             dynamicPath   => sub {
                                my ($self) = @_;
                                my $name = $self->row()->valueByName('name');
                                $name =~ s/\s/_/g;
                                return LIST_FILE_DIR . '/' .$name;
                              },
             user          => 'ebox',
             group         => 'ebox',
         ),
    );

    my $dataTable =
    {
        tableName          => 'CategorizedLists',
        pageTitle          => __('HTTP Proxy'),
        printableTableName => __('Categorized Lists'),
        modelDomain        => 'Squid',
        defaultActions => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        rowUnique          => 1,
        automaticRemove    => 1,
        printableRowName   => __('categorized list'),
        help               => __('You can upload files with categorized lists of domains. You will be able to filter by those categories in each filter profile.'),
    };
}

sub syncRows
{
    my ($self, $currentRows) = @_;
    my $changed = 0;
    # removes row if the archive  files in not longer present
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $fileList = $row->elementByName('fileList');
        if (not $fileList->exist()) {
            my $path = $fileList->path();
            my $name = $row->valueByName('name');
            EBox::error("File $path for categorized list $name not longer exits. Removing its row");
            $changed = 1;
            $self->removeRow($id, 1);
        }
    }

    return $changed;
}

sub validateTypedRow
{
    my ($self, $action, $params, $actual) = @_;
    if (($action eq 'add') or ($action eq 'update')) {
        my $name = exists $params->{name} ? $params->{name}->value() : $actual->{name}->value();
        my $dir = LIST_FILE_DIR . '/' . $name;
        if (EBox::Sudo::fileTest('-e', $dir)) {
            throw EBox::Exceptions::External(__x(
                "Cannot use name {name} because there arready a directory for this name: {dir}.\n Maybe a uncommited removal?.",
                name => $name,
                dir => $dir
               )
            );
        }
    }
}

sub addedRowNotify
{
    my ($self) = @_;
    $self->_changeInCategorizedLists();
}

sub updatedRowNotify
{
    my ($self, $row, $oldRow) = @_;
    if ($row->isEqualTo($oldRow)) {
        # no need to change categorized lists
        return;
    }
    $self->_changeInCategorizedLists();
}

sub deletedRowNotify
{
    my ($self, $row, $force) = @_;
    my $name = $row->valueByName('name');
    if (not $force) {
        $row->elementByName('fileList')->markArchiveContentsForRemoval();
    }

    $self->parentModule()->model('FilterProfiles')->markCategoriesAsNoPresent($name);
    $self->_changeInCategorizedLists();
}

sub _changeInCategorizedLists
{
    my ($self) = @_;
    # clear list directories seen list
    my $filterProfiles =  $self->parentModule()->model('FilterProfiles');
    my @ids = @{ $filterProfiles->ids() };
    if (not @ids) {
        # no profiles to notify
        return
    }

    my $profileId = $ids[0];
    my $profileConf =  $filterProfiles->row($profileId)->subModel('filterPolicy');
    my $modelCategories = $profileConf->componentByName('DomainFilterCategories', 1);
    $modelCategories->cleanSeenListDirectories();

    # XXX workaround ids() called to avoid the 'no change button' bug
    $modelCategories->ids();
}

# to mark files and categories that shoudl be deleted/marked a no present after
# saving the new configuration
sub beforeRestoreConfig
{
    my ($self) = @_;
    my @names;
    my @paths;
    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        push @names, $row->valueByName('name');
        my $fileList = $row->elementByName('fileList');
        push @paths, $fileList->path();
        push @paths, $fileList->archiveContentsDir();

    }

    $self->parentModule()->addPathsToRemove('restoreConfig', @paths);
    $self->parentModule()->addPathsToRemove('restoreConfigNoPresent', @names);
}

sub afterRestoreConfig
{
    my ($self) = @_;
    my $squid = $self->parentModule();
    my %toRemove = map {
        $_ => 1
    } @{  $squid->pathsToRemove('restoreConfig') };
    my %noPresent =  map {
        $_ => 1
    } @{  $squid->pathsToRemove('restoreConfigNoPresent') };

    foreach my $id (@{ $self->ids() }) {
        my $row = $self->row($id);
        delete $noPresent{$row->valueByName('name')};
        my $fileList = $row->elementByName('fileList');
        my $path = $fileList->path();
        my $archiveDir = $fileList->archiveContentsDir();
        delete $toRemove{$path};
        delete $toRemove{$archiveDir};
        $self->parentModule()->addPathsToRemove('revoke', $path, $archiveDir);
    }

    my $filterProfiles = $squid->model('FilterProfiles');
    foreach my $name (keys %noPresent) {
        $filterProfiles->markCategoriesAsNoPresent($name);
    }
    $self->parentModule()->addPathsToRemove('save', keys %toRemove);

    $squid->clearPathsToRemove('restoreConfig');
    $squid->clearPathsToRemove('restoreConfigNoPresent');
    $self->_changeInCategorizedLists();
}

1;
