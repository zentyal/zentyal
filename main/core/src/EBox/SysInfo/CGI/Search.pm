# Copyright (C) 2014 Zentyal S.L.
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

package EBox::SysInfo::CGI::Search;
use base 'EBox::CGI::ClientBase';

use EBox::Search;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title'    => __('Search results'),
            'template' => 'sysinfo/searchResults.mas',
            @_);
    bless($self, $class);
    return $self;
}

sub _validateReferer
{
        return 1;
}


sub _process
{
    my ($self) = @_;
    my $searchString = $self->param('search');
    if (not $searchString) {
        $self->{chain} = '/Dashboard/Index';
        return;
    }

    my $matches = EBox::Search::search($searchString);
    $self->{params} = [
         searchString => $searchString,
         matches      => $matches,
     ];
}


1;
