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

package EBox::Firewall::CGI::Filter;

use base 'EBox::CGI::ClientBase';

use EBox::Gettext;
use EBox::Config;

sub new
{
	my $class = shift;
	my $self = $class->SUPER::new('title' => ('Packet Filter'),
				      'template' => '/firewall/filter.mas',
				      @_);

    my $showImages = not EBox::Config::boolean('hide_firewall_images');
    my $showAdvanced = EBox::Config::boolean('show_service_rules');
    my $showExtToInt = EBox::Config::boolean('show_ext_to_int_rules');
    $self->{params} = [ showImages => $showImages, showAdvanced => $showAdvanced, showExtToInt => $showExtToInt ];

    bless($self, $class);
    return $self;
}

1;
