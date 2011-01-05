# Copyright (C) 2009-2010 eBox Technologies S.L.
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

package EBox::UsersAndGroups::Model::PendingSync;

# Class: EBox::UsersAndGroups::Model::PendingSync
#
#	This model is used to list those operations that need to be run by the slaves
#	because the master failed to contact them.
#
# TODO:
#	- Document methods
#	- _processDir and _processFile are used in slave-sync too
#
use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Model::Row;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;
use EBox::UserCorner;
use EBox::Types::Text;

use strict;
use warnings;

use base 'EBox::Model::DataTable';

sub new
{
    my $class = shift;
    my %parms = @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

sub _table
{
    my @tableHead =
        (

         new EBox::Types::Text(
             'fieldName' => 'slave',
             'printableName' => __('Slave'),
             'size' => '12',
             ),
         new EBox::Types::Text(
             'fieldName' => 'operation',
             'printableName' => __('Operation'),
             'size' => '12',
             ),
         new EBox::Types::Text(
             'fieldName' => 'parameter',
             'printableName' => __('Parameter'),
             'size' => '12',
             ),

        );

    my $dataTable =
    {
        'tableName' => 'PendingSync',
        'printableTableName' => __('List of pending operations on slaves'),
        'defaultController' =>
            '/ebox/Users/Controller/PendingSync',
        'defaultActions' =>
            ['changeView'],
        'tableDescription' => \@tableHead,
        'menuNamespace' => 'UsersAndGroups/PendingSync',
        'help' => __x('This is a list those operations that need to be run by the slaves ' .
		      'because the master failed to contact them.'),
        'printableRowName' => __('operation'),
    };

    return $dataTable;
}

# Method: precondition
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
sub precondition
{
    my ($self) = @_;
    my $users = EBox::Global->modInstance('users');
    unless ($users->configured() and ($users->mode() ne 'slave')) {
        $self->{preconFail} = 'notConfigured';
        return undef;
    }

    unless (@{$users->listSlaves()} and @{_pendingOps()}) {
        $self->{preconFail} = 'noSlaves';
        return undef;
    }

    return 1;
}

# Method: preconditionFailMsg
#
# Check if the module is configured
#
# Overrides:
#
# <EBox::Model::DataTable::precondition>
sub preconditionFailMsg
{
    my ($self) = @_;

    if ($self->{preconFail} eq 'notConfigured') {
        return __('You must enable the module Users in master mode.');
    } else {
        return __('There are no pending operations at the moment.');

    }
}

# Method: ids
#
#   Override <EBox::Model::DataTable::ids> to return rows identifiers
#   based on the slaves stored in LDAP
#
sub ids
{
    my ($self) = @_;

    my $users = EBox::Global->modInstance('users');
    unless ($users->configured()) {
        return [];
    }

    my @ops = @{_pendingOps()};
    if (@ops) {
	return [0 .. $#ops];
    } else {
	return [];
    }
}

# Method: row
#
#   Override <EBox::Model::DataTable::row>
#
sub row
{
    my ($self, $id) = @_;

    my @ops = @{_pendingOps()};
    my ($slave, $op, $par) = @{$ops[$id]};
    my $row = $self->_setValueRow(slave => $slave, operation => $op, parameter => $par);
    $row->setId($id);
    $row->setReadOnly(1);
    return $row;
}

sub Viewer
{
    return '/ajax/tableBodyWithoutActions.mas';
}

sub _processSlaveDir
{
    my ($journaldir, $slave) = @_;

    my $dir = "$journaldir$slave/";

    my $dh;
    opendir($dh, $dir) or
        die "Can't open the journal dir: $dir\n";

    my %files;
    while (defined(my $file = readdir($dh))) {
        (-d "$dir$file" and next);
        $files{$file}=(stat("$dir$file"))[9];
    }
    closedir($dh);
    my @ops;
    foreach my $file (sort { $files{$a} cmp $files{$b} } keys %files){
        push (@ops,  _processFile($slave, "$dir$file"));
    }
    return \@ops;
}

sub _processFile
{
    my ($slave, $file) = @_;

    open(FILE, $file);
    my ($method, $param) = <FILE>;
    close(FILE);
    chomp($method);
    chomp($param);

    return [$method, $param];
}

sub _processDir
{
    my ($journaldir) = @_;

	my $users = EBox::Global->modInstance('users');

	opendir(my $jdir, $journaldir) or return [];

	my @ops;
	while (defined(my $slave = readdir($jdir))) {
	    ($slave=~ m/^\./) and next;
	    for my $op (@{_processSlaveDir($journaldir, $slave)}) {
		push (@ops, [ $slave, @{$op} ]);
	    }
	}
	closedir($jdir);

	return \@ops;
}

sub _pendingOps
{
    my $ops = _processDir(EBox::Config::conf() . "userjournal/");
    my $userops = _processDir(EBox::UserCorner::usercornerdir() . "userjournal/");
    return [(@{$ops}, @{$userops})];
}

1;
