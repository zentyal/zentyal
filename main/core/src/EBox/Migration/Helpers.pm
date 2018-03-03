# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Migration::Helpers;

use EBox;
use EBox::DBEngineFactory;
use TryCatch;

# SQL helpers

sub runQuery
{
    my ($query) = @_;

    try {
        my $dbengine = EBox::DBEngineFactory::DBEngine();
        $dbengine->do($query);
    } catch {
        return 1;
    }

    return 0;
}

sub renameTable
{
    my ($oldTable, $newTable) = @_;

    my $exists_query = "SELECT COUNT(*) FROM $oldTable";
    my @queries = (
        "ALTER TABLE $newTable RENAME TO $newTable" . "_new",
        "ALTER TABLE $oldTable RENAME TO $newTable",
        "INSERT INTO $newTable SELECT * FROM $newTable" . "_new",
        "DROP TABLE $newTable" . "_new"
    );

    my $res = runQuery($exists_query);
    if ($res == 0) {
        for my $q (@queries) {
            runQuery($q);
        }
    }
}

sub renameConsolidationTable
{
    my ($oldTable, $newTable) = @_;

    my @types = ('hourly', 'daily', 'weekly', 'monthly');

    for my $t (@types) {
        renameTable($oldTable . "_$t", $newTable . "_$t");
    }
}

sub renameField
{
    my ($table, $oldField, $newField) = @_;

    my $query = "ALTER TABLE $table RENAME COLUMN $oldField TO $newField";
    runQuery($query);
}

sub createIndex
{
    my ($table, $field) = @_;

    my $query = "CREATE INDEX $table" . "_$field" . "_i ON $table($field)";
    runQuery($query);
}

sub createTimestampIndex
{
    my ($table) = @_;
    createIndex($table, 'timestamp');
}

sub dropIndex
{
    my ($index) = @_;

    my $query = "DROP INDEX $index";
    runQuery($query);
}

sub addColumn
{
    my ($table, $column, $columnData) = @_;
    my $exists_query = "SELECT COUNT(*) FROM $table";
    my $res = runQuery($exists_query);
    if ($res == 0) {
        $exists_query = "SELECT $column FROM $table LIMIT 1";
        my $exists = runQuery($exists_query) == 0;
        if ($exists) {
            return;
        }
        my $addColumnQuery = "ALTER TABLE $table " .
                             "ADD COLUMN $column " .
                             "$columnData";
        runQuery($addColumnQuery);
    }
}

1;
