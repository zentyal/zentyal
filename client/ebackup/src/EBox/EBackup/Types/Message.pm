# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::EBackup::Types::Message;

use strict;
use warnings;

use base 'EBox::Types::Text';

sub new
{
        my $class = shift;
        my %opts = @_;

        my $self = $class->SUPER::new(%opts);

        bless($self, $class);
        return $self;
}


# Method: optional
#
#     Overrides <EBox::Types::Text::optional>
#
sub optional
{
    my ($self) = @_;
    return 1;
}


# Method: value
#
#     Overrides <EBox::Types::Text::value>
#
#     Here is where we can compute or return stuff that we want to report
#     to the user.
#
sub value
{
    my ($self) = @_;

    my $row = $self->row();
    return undef unless ($row);

    my $name = $row->valueByName(’module’);

    return ( -f "/etc/apache2/mods-enabled/$name.load" );
}


# Method: printableValue
#
#     Overrides <EBox::Types::Text::printableValue>
#
#      We don’t need to do fancy stuff with the value returned in a printable
#      way, so we just spit out what value() returns.
#
sub printableValue
{
    my ($self) = @_;
    return $self->value();
}


# Method: restoreFromHash
#
#     Overrides <EBox::Types::Text::restoreFromHash>
#
#     We don’t need to restore anything from GConf so we leave this method empty.
#
sub restoreFromHash
{
}


# Method: storeInGConf
#
#    Overrides <EBox::Types::Text::storeInGConf>
#
#    Following the same reasoning as restoreFromHash, we don’t need to store
#    anything in GConf.
#
sub storeInGConf
{
}

1;
