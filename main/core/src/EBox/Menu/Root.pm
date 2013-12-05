# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Menu::Root;

use base 'EBox::Menu::Node';

use EBox::Gettext;

sub new
{
    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    $self->{'current'} = delete $opts{'current'};
    $self->{'currentUrl'} = delete $opts{'currentUrl'};
    $self->{'id'} = 'menu';
    bless($self, $class);
    return $self;
}

sub htmlParams
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $copyright = $global->theme()->{'copyright_footer'};

    my $comp = 'menu.mas';

    # Add separators
    my @items;
    my $currentSeparator = '';
    foreach my $item (@{$self->items}) {
        my $itemSeparator = $item->{separator};
        if ($itemSeparator) {
            if ($itemSeparator ne $currentSeparator) {
                push (@items, new EBox::Menu::Separator('text' =>
                                                        $itemSeparator));
                $currentSeparator = $itemSeparator;
            }
        }
        push (@items, $item);
    }

    my @params;
    push (@params, 'items' => \@items);
    push (@params, 'current' => $self->{'current'});
    push (@params, 'currentUrl' => $self->{'currentUrl'});
    push (@params, 'copyright_footer' => $copyright);
    return ($comp, @params);
}

1;
