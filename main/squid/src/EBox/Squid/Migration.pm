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

package EBox::Squid::Migration;

use EBox;
use EBox::Global;
use EBox::Sudo;
use EBox::Squid::Model::CategorizedLists;
use File::Basename;
use String::ShellQuote;

# Migrate categorized lists paths and content directories with blanks
sub migrateWhitespaceCategorizedLists
{
    my $squid = EBox::Global->getInstance(0)->modInstance('squid');
    my $categorizedLists = $squid->model('CategorizedLists');
    my $changedConf = 0;

    foreach my $id (@{ $categorizedLists->_ids() }) {
        my $row = $categorizedLists->row($id);
        my $name = $row->valueByName('name');
        my $file = $row->elementByName('fileList');

        my $unpackPath =  $file->unpackPath();
        # create unpack path if not exists
        if (not EBox::Sudo::fileTest('-d', $unpackPath)) {
            EBox::Sudo::root("mkdir -p '$unpackPath'");
        }

        my $newPath = $file->path();
        my $oldPath =  EBox::Squid::Model::CategorizedLists::LIST_FILE_DIR;
        $oldPath .= '/'  . $name;
        _fixPath($newPath, $oldPath, 'archive file');

        my $changedDirs = 0;
        my $newDir = $file->archiveContentsDir();
        my $oldDir =  $unpackPath . '/' . basename($oldPath);
        $changedDirs = _fixPath($newDir, $oldDir, 'contents directory');

        if (not $changedDirs) {
            # older versions are not under categories
            $oldDir =~ s{squid/categories/}{squid/};
            $changedDirs = _fixPath($newDir, $oldDir, 'contents directory');
        }

        if ($changedDirs) {
            if (_dirChange($squid, $oldDir, $newDir)) {

                $changedConf = 1;
            }
        }
    }

    if ($changedConf) {
        $squid->saveConfig();
    }
}

sub _fixPath
{
    my ($new, $old, $desc) = @_;
    if ($new eq $old) {
        return 0;
    }

    my $existsOld = EBox::Sudo::fileTest('-e', $old);
    if (not $existsOld) {
        return 0;
    }

    my $existsNew = EBox::Sudo::fileTest('-e', $new);
    if (not $existsNew) {
        EBox::info("Moving old $desc from $old to $new");
        my $oldQuoted = shell_quote($old);
        my $newQuoted = shell_quote($new);
        EBox::Sudo::root("mv $oldQuoted $newQuoted");
        return 1;
    } else {
        EBox::warn("Possible idle path $old for $desc, we suggest to remove it");
    }

    return 0;
}

sub _dirChange
{
    my ($squid, $old, $new) = @_;
    my $changed = 0;
    my $filterProfiles = $squid->model('FilterProfiles');

    foreach my $profileId (@{ $filterProfiles->ids() }) {
        my $profileRow = $filterProfiles->row($profileId);
        my $profileConf = $profileRow->subModel('filterPolicy');
        my $categories = $profileConf->componentByName('DomainFilterCategories', 1);
        # avoid syncRow
        foreach my $id (@{ $categories->_ids() }) {
            my $row = $categories->row($id);
            my $dir = $row->valueByName('dir');
            my $baseDir = dirname(dirname($dir)); # skip intermediate dir
            if ($old eq $baseDir) {
                $dir =~ s/^$old/$new/;
                $row->elementByName('dir')->setValue($dir);
                $row->store();
                $changed = 1;
            }
        }
    }

    return $changed;
}

1;
