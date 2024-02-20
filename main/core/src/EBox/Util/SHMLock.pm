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

package EBox::Util::SHMLock;

use EBox;
use EBox::Config;
use EBox::Exceptions::Internal;
use EBox::Exceptions::Lock;
use Fcntl qw(:flock);
use EBox::Sudo;

sub init
{
    my ($class, $name, $path) = @_;
    $path = EBox::Config::shm() unless defined ($path);

    my $self = {};
    bless $self, $class;

    $self->{name} = $name;

    my $file = "$path/$name.lock";
    $self->{file} = $file;

    unless (-d $path) {
        mkdir ($path);
    }

    EBox::Sudo::silentRoot("chown ebox:ebox $path");

    unless (-f $file) {
        open(LOCKFILE, ">$file") or
            throw EBox::Exceptions::Internal("Cannot create lockfile: $file");
        close(LOCKFILE);
    }

    EBox::Sudo::silentRoot("chown ebox:ebox $file");

    return $self;
}

sub unlock
{
    my ($self) = @_;

    my $file = $self->{file};

    open(LOCKFILE, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile to unlock: $file");
    flock(LOCKFILE, LOCK_UN);
    close(LOCKFILE);
}

sub lock
{
    my ($self) = @_;

    my $file = $self->{file};

    open(LOCKFILE, ">$file") or
        throw EBox::Exceptions::Internal("Cannot open lockfile to lock: $file");
    flock(LOCKFILE, LOCK_EX) or
        throw EBox::Exceptions::Lock($self->{name});
}

1;
