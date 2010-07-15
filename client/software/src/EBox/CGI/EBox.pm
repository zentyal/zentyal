# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::CGI::Software::EBox;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

use constant FIRST_RUN_FILE => '/var/lib/ebox/.first';

## arguments:
##  title [required]
sub new {
    my $class = shift;
    my $self;
    if (-f FIRST_RUN_FILE) {
        $self = $class->SUPER::new('title'    => __('Choose eBox packages to install'),
                'template' => 'software/ebox.mas',
                @_);
    } else {
        $self = $class->SUPER::new('title'    => __('eBox components'),
                'template' => 'software/ebox.mas',
                @_);
    }
    $self->{domain} = 'ebox-software';
    bless($self, $class);
    return $self;
}

sub _process($) {
    my $self = shift;
    my $software = EBox::Global->modInstance('software');
    my @array = ();
    push(@array, 'eboxpkgs' => $software->listEBoxPkgs());
    push(@array, 'updateStatus' => $software->updateStatus(1));
    $self->{params} = \@array;
}

sub _menu {
    my ($self) = @_;
    my $file = '/var/lib/ebox/.first';
    if (-f  $file) {
        my $software = EBox::Global->modInstance('software');
        $software->firstTimeMenu(0);
    } else {
        $self->SUPER::_menu(@_);
    }
}

sub _top
{
	print '<div id="top"></div><div id="header"><img src="/data/images/title.png" alt="title"/></div>';
	return;
}

1;
