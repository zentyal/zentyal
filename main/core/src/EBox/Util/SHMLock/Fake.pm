# Copyright (C) 2013 Zentyal S.L.
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

package EBox::Util::SHMLock::Fake;

use EBox::Util::SHMLock;
use EBox::Exceptions::Lock;
use Test::MockObject;
use Test::MockModule;

my $mockedModule;

sub overrideOriginal
{
    $mockedModule = new Test::MockModule('EBox::Util::SHMLock');
    $mockedModule->mock(init => \&init);
}

sub restoreOriginal
{
    if ($mockedModule) {
        $mockedModule->unmock_all();
        $mockedModule = undef;
    }
}

my %locks;

sub cleanAllLocks
{
    %locks = ();
}

sub init
{
    my ($class, $name, $path) = @_;

    my $self = Test::MockObject->new();
    $self->set_isa(' EBox::Util::SHMLock');
    $self->{name} = $name;
    my $file = "$path/$name.lock";
    $self->{file} = $file;
    $self->mock('lock' => \&lock);
    $self->mock('unlock' => \&unlock);

    $locks{$file} = 1;

    return $self;
}

# does not raise error if it has been already unlocked
sub unlock
{
    my ($self) = @_;
    my $file = $self->{file};
    $locks{$file} = 0;
}

sub lock
{
    my ($self) = @_;
    my $file = $self->{file};
    if ($locks{$file}) {
        throw EBox::Exceptions::Lock($self->{name});
    } else {
        $locks{$file} = 1;
    }
}

1;
