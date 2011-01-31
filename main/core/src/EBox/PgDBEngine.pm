# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::PgDBEngine;

use strict;
use warnings;

use base qw(EBox::AbstractDBEngine);

use DBI;
use EBox::Gettext;
use EBox::Validate;
use EBox;
use EBox::Config;
use EBox::Sudo;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::FileSystem;
use File::Slurp;
use File::Copy;
use File::Basename;
use EBox::Logs::SlicedBackup;

use Error qw(:try);
use Data::Dumper;

sub new
{
    my $class = shift,
    my $self = {};
    bless($self,$class);

    $self->_connect();

    return $self;
}

# Method: _dbname
#
#       This function returns the database name.
#
sub _dbname
{
    my $root = EBox::Config::configkey('eboxlogs_dbname');
    ($root) or
        throw EBox::Exceptions::External(__x('You must set the {variable} ' .
                    'variable in the ebox configuration file',
                    variable => 'eboxlogs_dbname'));
    return $root;
}

# Method: _dbuser
#
#       This function returns the database user.
#
sub _dbuser
{
    my $root = EBox::Config::configkey('eboxlogs_dbuser');
    ($root) or
        throw EBox::Exceptions::External(__x('You must set the {variable} ' .
                    'variable in the ebox configuration file',
                    variable => 'eboxlogs_dbuser'));
    return $root;
}

# Method: _dbpass
#
#  This function returns the database user password.
#
sub _dbpass
{
    my $root = EBox::Config::configkey('eboxlogs_dbpass');
    ($root) or
        throw EBox::Exceptions::External(__x('You must set the {variable} ' .
                    'variable in the ebox configuration file',
                    variable => 'eboxlogs_dbpass'));
    return $root;
}


# Method: _dbsuperuser
#
#  This function returns the database superuser's username
#
sub _dbsuperuser
{
    return 'postgres';
}

# Method: _connect
#
#       This function do the necessary operations to establish a connection with the
#       database.
#
sub _connect
{
    my $self = shift;

    return if($self->{'dbh'});

    my $dbh = DBI->connect("dbi:Pg:dbname=".$self->_dbname(),
            $self->_dbuser(), $self->_dbpass(), { PrintError => 0});

    unless ($dbh) {
        throw EBox::Exceptions::Internal("Connection DB Error: $DBI::errstr\n");
    }

    $self->{'dbh'} = $dbh;
}

# Method: _disconnect
#
#       This function do the necessary operations to get disconnected from the
#       database.
#
sub _disconnect
{
    my ($self) = @_;

    $self->{'sthinsert'}->finish() if ($self->{'sthinsert'});
    if ($self->{'dbh'}) {
        $self->{'dbh'}->disconnect();
        $self->{'dbh'} = undef;
    } else {
        throw EBox::Exceptions::Internal(
            'There wasn\'t a database connection, check if database exists\n');
    }
}

sub _prepare
{
    my ($self, $sql) = @_;

    $self->{'sthinsert'} =  $self->{'dbh'}->prepare($sql);
    unless ($self->{'sthinsert'}) {
        #throw exception
        EBox::debug("Error preparing sql: $sql\n");
        throw EBox::Exceptions::Internal("Error preparing sql: $sql\n");
    }
}

# Method: unbufferedInsert
#
#   This function do the necessary operations to create and establish an insert
#   operation to a table form the database. This operation is executed
#   immediately as opposite to the insert method.
#
# Parameters:
#   $table: The table name to insert data.
#   $values: A hash ref with database fields name and values pairs that do you
#   want to insert to the table name passed as parameter too.
#
sub unbufferedInsert
{
    my ($self, $table, $values) = @_;
    my $sql = "INSERT INTO $table ( ";

    my @keys = ();
    my @vals = ();
    while(my ($key, $value) = each %$values ) {
        push(@keys, $key);
        push(@vals, $value);
    }

    $sql .= join(", ", @keys);
    $sql .= ") VALUES (";

    foreach (@vals) {
        $sql .= " ?,";
    }
    $sql = (substr($sql, 0, -1)).')';


    $self->_prepare($sql);
    my $err = $self->{'sthinsert'}->execute(@vals);
    if (!$err) {
        #throw exception
        EBox::debug ("Error inserting data: $sql\n" .
                     $self->{dbh}->errstr . " \n");
        EBox::debug ("Values: " . Dumper(\@vals) . "\n");
        throw EBox::Exceptions::Internal("Error inserting data: $sql\n" .
                                         $self->{dbh}->errstr .
                                         " \n" .
                                         "Values: " . Dumper(\@vals) .
                                         "\n");
    }
}

# Method: insert
#
#   This function do the necessary operations to create and establish an insert
#   operation to a table form the database. This operation is buffered
#   and will be executed when calling the multiInsert method.
#
# Parameters:
#   $table: The table name to insert data.
#   $values: A hash ref with database fields name and values pairs that do you
#   want to insert to the table name passed as parameter too.
#
sub insert
{
    my ($self, $table, $values) = @_;
    if (not exists $self->{multiInsert}->{$table}) {
        $self->{multiInsert}->{$table} = [];
    }
    push (@{$self->{multiInsert}->{$table}}, $values);
}

# Method: multiInsert
#
#   Commits the INSERT operation with all the buffered rows stored by
#   the insert function. This is called from EBox::Loggerd so in
#   general you don't have to care about it.
#
sub multiInsert
{
    my ($self) = @_;

    for my $table (keys %{$self->{multiInsert}}) {
        my @values = @{$self->{multiInsert}->{$table}};
        next unless (@values);

        my @keys = keys %{$self->{multiInsert}->{$table}->[0]};
        my $sql = sprintf("INSERT INTO $table (%s) VALUES %s",
                          join (',', @keys),
                          join (',',
                                map {'(' . join(',', map {'?'} @keys) . ')'}
                                     @values),
        );
        $self->_prepare($sql);
        my @flat;
        for my $val (@values) {
            push (@flat, map {$val->{$_}} @keys);
        }
        my $err = $self->{'sthinsert'}->execute(@flat);
        $self->{multiInsert}->{$table} = [];
        if (!$err) {
            throw EBox::Exceptions::Internal("Error inserting data: $sql\n" .
                                             $self->{dbh}->errstr .  " \n" .
                                             "Values: " . Dumper(\@values) .
                                             "\n");
        }
    }
}


# Method: update
#
#     This function performs an update in the database.
#
# Parameters:
#   $table: The table name to insert data.
#   $values: A hash ref with database fields name and values pairs that do you
#   want to update
#   $where: An array ref with conditions for the where
#
sub update
{
    my ($self, $table, $values, $where) = @_;
    my $sql = "UPDATE $table SET ";

    $sql .= join(", ", map { $_ . " = " . $values->{$_} } keys %$values);
    $sql .= ' WHERE ' . join(' AND ', @{$where});

    $self->_prepare($sql);
    my $err = $self->{'sthinsert'}->execute();
    if (!$err) {
        #throw exception
        EBox::debug ("Error updating data: $sql\n" .
                     $self->{dbh}->errstr .
                     " \n"
                    );
        throw EBox::Exceptions::Internal ("Error updating data: $sql\n" .
                                          $self->{dbh}->errstr .
                                          " \n"
                                         );
    }
}

# Method: query
#
#       This function do the necessary operations to create and establish a query
#       operation to a table form the database.
#
# Parameters:
#   $sql: A string that contains the SQL query.
#   @values: An array with the values to substitute in the query.
#
# Returns:
#  (this is copied for the perldoc for DBI)
# It returns a reference to an array that contains one hash reference per
#  row.   If there are no rows to return, fetchall_arrayref returns a reference
#  to an empty array. If an error occurs, fetchall_arrayref returns the data
#  fetched thus far, which may be none. You should check $sth->err afterwards
#  (or use the RaiseError attribute) to discover if the data is complete or was
#  truncated due to an error.
#
#
sub query
{
    my ($self, $sql, @values) = @_;

    my $ret;
    my $err;

    $self->_prepare($sql);
    if (@values) {
       $err = $self->{'sthinsert'}->execute(@values);
    } else {
        $err = $self->{'sthinsert'}->execute();
    }
    if (!$err) {
        my $errstr = $self->{'dbh'}->errstr();
        EBox::debug ("Error querying data: $sql , $errstr\n");
        #                 throw EBox::Exceptions::Internal ("Error querying data: $sql , $errstr");
    }
    $ret = $self->{'sthinsert'}->fetchall_arrayref({});
    $self->{'sthinsert'}->finish();

    return $ret;
}

# Method: query_hash
#
#   Run a custom SQL query and return the results
#
# Parameters:
#
#       index - String the module name in lower case
#       query - Hash containing SQL strings with optional (except 'from') keys:
#          'select', 'from', 'where', 'group', 'order', 'limit'
#
# Return:
#       array reference. Each row will be a hash reference with column/values
#       as key/values.
sub query_hash
{
    my ($self, $query) = @_;
    my $sql = $self->query_hash_to_sql($query);
    my @results = @{$self->query($sql)};
    return \@results;
}

sub query_hash_to_sql
{
    my ($self, $query, $semicolon) = @_;

    defined $semicolon or
        $semicolon  = 1;

    my $sql = "SELECT ";
    if (defined($query->{'select'})) {
        $sql .= $query->{'select'};
    } else {
        $sql .= '*';
    }
    $sql .= " FROM " . $query->{'from'} . " ";
    if (defined($query->{'where'})) {
        $sql .= "WHERE " . $query->{'where'} . " ";
    }
    if (defined($query->{'group'})) {
        $sql .= "GROUP BY " . $query->{'group'} . " ";
    }
    if (defined($query->{'order'})) {
        $sql .= "ORDER BY " . $query->{'order'} . " ";
    }
    if (defined($query->{'limit'})) {
        $sql .= "LIMIT " . $query->{'limit'} . " ";
    }
    if ($semicolon) {
        $sql .= ';';
    }

    return $sql;
}


# Method: do
#
#   Prepare and execute a single statement.
#
#
# Parameters:
#   $sql: A string that contains the SQL statement.
#   $attr:
#   @bind_values
#
#
# Returns : the number of rows affected
sub do
{
    my ($self, $sql, $attr, @bindValues) = @_;

    my @optionalCallParams;
    if (defined $attr) {
        push @optionalCallParams, $attr;
    }
    if (@bindValues) {
        push @optionalCallParams, @bindValues;
    }

    my $res = $self->{dbh}->do($sql, @optionalCallParams);
    if (not defined $res) {
        my $errstr = $self->{'dbh'}->errstr();
        throw EBox::Exceptions::Internal("Error doing statement: $sql , $errstr\n");
    }

    return $res;
}

# Method: tables
#
# Returns:
#   reference to a list with all the public (regular) tables of the database
sub tables
{
    my ($self) = @_;
    my $sql = q{select tablename from pg_catalog.pg_tables where schemaname = 'public';};
    my @tables = map { $_->{tablename}  }  @{$self->query($sql)};
    return \@tables;
}

sub backupDB
{
    my ($self, $dir, $basename, %args) = @_;
    my $slicedMode;
    if (exists $args{slicedMode}) {
        $slicedMode = delete  $args{slicedMode};
    } else {
        $slicedMode = EBox::Logs::SlicedBackup::slicedMode();
    }

    if ($slicedMode) {
        EBox::Logs::SlicedBackup::slicedBackup($self, $dir, %args);
    } else {
        my $file = "$dir/$basename.dump";
        $self->dumpDB($file, 0);
    }
}


sub restoreDB
{
    my ($self, $dir, $basename, %params) = @_;
    my $slicedMode;
    if (exists $params{slicedMode}) {
        $slicedMode = delete $params{slicedMode};
    } else {
        $slicedMode = EBox::Logs::SlicedBackup::slicedMode();
    }

    my $noSlicesDumpFile = "$dir/$basename.dump";

    if ($slicedMode) {
        if (-e $noSlicesDumpFile) {
            throw EBox::Exceptions::External(
  __('You are using sliced backup mode and this backup was made in no-sliced mode')
                                            );
        }

        EBox::Logs::SlicedBackup::slicedRestore($self, $dir, %params);
    } else {
        if (not -e $noSlicesDumpFile) {
            throw EBox::Exceptions::External(
  __('Database dump file not found. Maybe the backup you are trying to restore was made in sliced mode?')
                                            );
        }

        $self->restoreDBDump($noSlicesDumpFile, 0);
    }
}

# Method: dumpDB
#
#         Makes a dump of the database in the specified file
#
# Parameters:
#     $outputFile - output database dump file
#
sub  dumpDB
{
    my ($self, $outputFile, $onlySchema) = @_;
    defined $onlySchema or
        $onlySchema = 0;

    my $tmpFile = _superuserTmpFile(1);

    my $dbname = _dbname();
    my $dumpCommand = "/usr/bin/pg_dump --clean --file $tmpFile $dbname";
    if ($onlySchema) {
        $dumpCommand .= ' --schema-only';
    }

    $self->commandAsSuperuser($dumpCommand);

    # give file to ebox and move to real desitnation
    EBox::Sudo::root("chown ebox.ebox $tmpFile");
    File::Copy::move($tmpFile, $outputFile);

    $self->_mangleDumpFile($outputFile);
}


sub _mangleDumpFile
{
    my ($self, $file) = @_;

    my @linesToComment = (
                          'DROP TABLE public.' .
                            EBox::Logs::SlicedBackup::backupSlicesDBTable(),
                         );
    foreach my $line (@linesToComment) {
        my $sed = qq{sed -i s/'$line'/'-- $line'/ $file};
        EBox::Sudo::command($sed);
    }
}


# Method: restoreDB
#
# restore a database from a dump file.
# WARNING:  This erase all the DB current dara
#
# Parameters:
#      $file - database dump file
#
sub restoreDBDump
{
    my ($self, $file, $onlySchema) = @_;
    defined $onlySchema or
        $onlySchema = 0;

    EBox::info('We wil try to restore the database. This will erase your current data' );

    my $tmpFile = _superuserTmpFile(0);
    EBox::Sudo::root("mv $file $tmpFile");

    try {
        my $superuser = _dbsuperuser();
        EBox::Sudo::root("chown $superuser:$superuser $tmpFile");
    } otherwise {
        # left file were it was before
        my $ex =shift;
        EBox::Sudo::root("mv $tmpFile $file");
        $ex->throw();
    };

    try {
        $self->sqlAsSuperuser(file => $tmpFile);
    } finally {
        # undo ownership and file move
        EBox::Sudo::root("chown ebox:ebox $tmpFile");
        EBox::Sudo::root("mv $tmpFile $file");
    };

    if ($onlySchema) {
        EBox::info('Database schema dump for ' . _dbname() . ' restored' );

    } else {
        EBox::info('Database dump for ' . _dbname() . ' restored' );
    }
}


# Method: sqlAsSuperuse
#
#  Executes sql as the database's superuser
#
#  Arguments (named):
#      sql - string with SQL code to execute
#      file - file which contents will be read as executed as SQL
sub sqlAsSuperuser
{
    my ($self, %args) = @_;
    my $file = $args{file};
    my $sql  = $args{sql};

    if ($file and $sql) {
        throw EBox::Exceptions::Internal('Incompatible parameters: file and sql');
    } elsif (not ($file or $sql)) {
        throw EBox::Exceptions::MissingArgument('file or sql');
    }

    if ($sql) {
        $file = EBox::Config::tmp() . 'sqlSuper.cmd';
        File::Slurp::write_file($file, $sql);
   }

    my $dbname = $self->_dbname();
    my $psqlCmd = "/usr/bin/psql --file $file $dbname ";
    $self->commandAsSuperuser($psqlCmd);
}


# Method: commandAsSuperuser
#
#   Executes a shell command with the ID of the database superuser
sub commandAsSuperuser
{
    my ($self, $cmd) = @_;
    defined $cmd or
        throw EBox::Exceptions::MissingArgument('command');

    my $dbsuperuser = _dbsuperuser();
    EBox::Sudo::sudo($cmd, $dbsuperuser);
}


sub _superuserTmpFile
{
    my ($create) = @_;

    my $file = EBox::Config::tmp() . 'db_superuser.tmp';

    if ($create) {
        my $superuser = _dbsuperuser();
        if (not -e $file) {
            EBox::Sudo::command("touch $file");
        }

        EBox::Sudo::root("chown $superuser:$superuser $file");
    }

    return $file;
}

sub DESTROY
{
    my ($self) = @_;
    $self->_disconnect() if (defined($self));
}

1;
