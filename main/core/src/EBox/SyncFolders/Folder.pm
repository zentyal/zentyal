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
#
# Class: EBox::SyncFolders::Folder
#
#   Folder to be synchronized
#
use strict;
use warnings;

package EBox::SyncFolders::Folder;

use EBox::Exceptions::NotImplemented;
use EBox::Exceptions::InvalidData;
use Perl6::Junction qw(any);

use constant TYPE_OPTIONS => ('share', 'user', 'group', 'recovery');

# Folder constructor
#
# Params:
#       path     - Full local path
#       type     - Share type. Should be one of:
#       share    - Shared folder
#       user     - User's home
#       group    - Group's folder
#       recovery - Disaster Recovery data backup
#
# Optional named params:
#
#   name - name for the folder (if not present, dirname will be used)
#
sub new
{
    my ($class, $path, $type, %args) = @_;

    unless ($type eq any(TYPE_OPTIONS)) {
        throw EBox::Exceptions::InvalidData(name => 'type', value => $type);
    }

    my $self = {
        path => $path,
        type => $type,
    };
    if ($args{name}) {
        $self->{name} = $args{name};
    } else {
        my $name = $self->{path};
        # Remove the first slash if exists
        if (substr ($name, 0, 1) eq '/') {
            $name = substr ($name, 1);
        }
        # Remove trailing slash if exists
        if (substr ($name, -1, 1) eq '/') {
            chop ($name);
        }
        $self->{name} = $name;
    }
    bless($self, $class);
    return $self;
}

sub path
{
    my ($self) = @_;
    return $self->{path};
}

sub type
{
    my ($self) = @_;
    return $self->{type};
}

sub name
{
    my ($self) = @_;
    return $self->{name};
}

1;
