# Copyright (C) 2011-2011 Zentyal S.L.
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
#

package EBox::Util::SQL;

use strict;
use warnings;

use EBox::Logs::Consolidate;
use Perl6::Junction qw(any);
use File::Basename;
use File::Slurp;

use constant SQL_TABLES_DIR => '/var/lib/zentyal/sql-tables/';

# Method: createCoreTables
#
#   This method creates the regular SQL log tables under
#   /usr/share/zentyal/sql/*.sql and the time-period
#   tables under /usr/share/zentyal/sql/period/*.sql
#
sub createCoreTables
{
    _createTables(EBox::Config::share() . 'zentyal/sql');
}

# Method: createModuleTables
#
#   This method creates the regular SQL log tables under
#   /usr/share/zentyal-$module/sql/*.sql and the time-period
#   tables under /usr/share/zentyal-$module/sql/period/*.sql
#
sub createModuleTables
{
    my ($module) = @_;

    _createTables(EBox::Config::share() . "zentyal-$module/sql", $module);
}

sub _createTables
{
    my ($path, $modname) = @_;

    my @names;

    foreach my $sqlfile (glob ("$path/*.sql")) {
        push (@names, _addTable($sqlfile));
    }

    my @timePeriods = @{ EBox::Logs::Consolidate->timePeriods() };
    foreach my $sqlfile (glob ("$path/period/*.sql")) {
        push (@names, _addTable($sqlfile, @timePeriods));
    }

    # Write table names file to drop them in purge-module
    if (defined $modname) {
        unless (-d SQL_TABLES_DIR) {
            mkdir (SQL_TABLES_DIR);
        }
        my $filename = SQL_TABLES_DIR . $modname;
        write_file($filename, join ("\n", @names));
    }
}

# Method: dropModuleTables
#
#   This method drops the SQL table names stored at
#   /var/lib/zentyal/sql-tables/$module
#
sub dropModuleTables
{
    my ($module) = @_;

    my $dbName = EBox::Config::configkey('eboxlogs_dbname');

    my $tablesFile = SQL_TABLES_DIR . $module;

    unless (-f $tablesFile) {
        return;
    }

    my @tables = read_file($tablesFile);
    return unless @tables;
    chomp (@tables);

    foreach my $table (@tables) {
        # FIXME: Use DBI?
        EBox::Sudo::sudo("psql -c \"DROP TABLE $table\" $dbName", 'postgres');
    }

    unlink ($tablesFile);
}

sub _addTable
{
    my ($file, @timePeriods) = @_;

    my $dbName = EBox::Config::configkey('eboxlogs_dbname');
    my $dbUser = EBox::Config::configkey('eboxlogs_dbuser');

    my $table = basename($file);
    $table =~ s/\.sql$//;

    if (@timePeriods) {
        my @names;
        foreach my $timePeriod (@timePeriods) {
            my $fullName = $table . '_' . $timePeriod;

            my $fileCmds = read_file($file);
            my $sqlCmds = $fileCmds;
            $sqlCmds =~ s/$table/$fullName/g;

            my $tmpFile = EBox::Config::tmp() . "$fullName.sql";
            write_file($tmpFile, $sqlCmds);

            EBox::Sudo::sudo("psql -f $tmpFile $dbName", 'postgres');
            EBox::Sudo::sudo("psql -c 'GRANT SELECT, INSERT, UPDATE, DELETE ON $fullName TO $dbUser' $dbName", 'postgres');
            push (@names, $fullName);
        }
        return @names;
    } else {
        # FIXME: Use DBI?
        EBox::Sudo::sudo("psql -f $file $dbName", 'postgres');
        EBox::Sudo::sudo("psql -c \"GRANT SELECT, INSERT, UPDATE, DELETE ON $table TO $dbUser\" $dbName", 'postgres');
        return $table;
    }
}

1;
