# Copyright (C) 2006-2007 Warp Networks S.L
# Copyright (C) 2008-2011 Zentyal S.L.
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

package EBox::CGI::SysInfo::PageNotFound;
use base 'EBox::CGI::ClientBase';
# Description: CGI for "page not found error"
use strict;
use warnings;

use  EBox::Gettext;

sub new
{
    my $class = shift;
    my $title = __("Page not found");
    my $template = 'pageNotFound.mas';
    my $self = $class->SUPER::new(title => $title, template => $template, @_);
    bless($self, $class);
     return $self;
}

# we do nothing,
# we can not even valdiate params because this a page not found error (any parameter can be in)
sub _process
{}

1;
