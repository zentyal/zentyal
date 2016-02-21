# Copyright (C) 2014-2015 Zentyal S.L.
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

package EBox::CGI::Search;
use base 'EBox::CGI::ClientBase';

use EBox::Search;
use EBox::Gettext;
use TryCatch;
use URI::Escape;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title'    => __('Search'),
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
    my $searchString = $self->unsafeParam('searchterm');
    if (not $searchString) {
        $self->setError(__('No search term'));
        $self->{params} = [
            searchString => __('None'),
            matches      => [],
           ];

        return;
    }

    my $matches = [];
    if (length($searchString) < 3) {
        $self->setError(__('The search term should have a length of, at least, 3 characters'));
    } else {
        try {
              $matches = EBox::Search::search($searchString);
        } catch ($ex) {
            $self->setError("$ex");
        }
    }

    # Avoid XSS attack as searchString is returned as GET parameter
    $searchString = uri_escape($searchString);

    $self->{params} = [
         searchString => $searchString,
         matches      => $matches,
     ];
}


1;
