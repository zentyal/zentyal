#!/usr/bin/perl

# Copyright (C) 2009-2012 eBox Technologies S.L.
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

package EBox::UsersAndGroups::Keytab;

use EBox::Sudo;
use EBox::Exceptions::MissingArgument;

sub new
{
    my ($class, %opts) = @_;

    unless (defined $opts{file}) {
        throw EBox::Exceptions::MissingArgument('file');
    }
    unless (defined $opts{user}) {
        throw EBox::Exceptions::MissingArgument('user');
    }

    my $self = {};
    $self->{file} = $opts{file};
    $self->{user} = $opts{user};

    bless ($self, $class);
    return $self;
}

sub file
{
    my ($self) = @_;

    return $self->{file};
}

sub user
{
    my ($self) = @_;

    return $self->{user};
}

# Method: setPermissions
#
#   This method grant read access to the specified user
#
sub setPermissions
{
    my ($self) = @_;

    my $file = $self->file();
    my $user = $self->user();
    my @cmds;
    push (@cmds, "chown root:$user '$file'");
    push (@cmds, "chmod 0440 '$file'");
    EBox::Sudo::root(@cmds);
}

# Method: updateEntry
#
#   This method updates an existing principal or adds it if it does not exists
#
sub update
{
    my ($self, $principal) = @_;

    my $file = $self->file();
    my $krb5PrincipalName = $principal->get('krb5PrincipalName');
    my $kvno = $principal->get('krb5KeyVersionNumber');

    # Remove the entry. If does not exists ignore the error
    my $removeCmd = "ktutil -k '$file' remove -p '$krb5PrincipalName'";
    EBox::Sudo::silentRoot($removeCmd);

    # Add the new entries, one for each key encryption type
    my @addCmds;
    my $keys = $principal->kerberosKeys();
    foreach my $key (@{$keys}) {
        my $etype = $key->{type};
        my $hexKey = unpack ('H*', $key->{value});
        my $cmd = "ktutil -k '$file' add " .
            "-p '$krb5PrincipalName' -e '$etype' -V '$kvno' -w '$hexKey' -H";
        push (@addCmds, $cmd);
    }
    EBox::Sudo::root(@addCmds);

    # Reset permissions
    $self->setPermissions();
}

# Method: remove
#
#   This method removes a principal from a keytab
#
sub remove
{
    my ($self, $principal) = @_;

    my $file = $self->file();
    my $krb5PrincipalName = $principal->get('krb5PrincipalName');

    # Remove the entry. If does not exists ignore the error
    my $removeCmd = "ktutil -k '$file' remove -p '$krb5PrincipalName'";
    EBox::Sudo::silentRoot($removeCmd);

    # Reset permissions
    $self->setPermissions();
}

1;
