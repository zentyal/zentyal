# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Menu::Root;

use strict;
use warnings;

use base 'EBox::Menu::Node';
use EBox::Gettext;
use HTML::Mason::Interp;

sub new
{
	my $class = shift;
	my %opts = @_;
	my $self = $class->SUPER::new(@_);
	$self->{'current'} = delete $opts{'current'};
	bless($self, $class);
	return $self;
}

sub html
{
	my $self = shift;

    my $output;
    my $interp = HTML::Mason::Interp->new(out_method => \$output);
    my $comp = $interp->make_component(
            comp_file => (EBox::Config::templates . '/menu.mas'));

    my @params;
    push(@params, 'items' => $self->items);
    $interp->exec($comp, @params);

	return $output;
}

1;
