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

package EBox::SysInfo::CGI::ComponentNotFound;
use base 'EBox::CGI::ClientBase';

# Description: CGI to be used when the request contains a reference to a
# component which does not exists (i.e. was removed and then its URL used)

use EBox::Gettext;

sub new
{
    my $class = shift;
    my $title = __("Element not found");
    my $template = 'componentNotFound.mas';
    my $self = $class->SUPER::new(title => $title, template => $template, @_);
    bless($self, $class);
    return $self;
}

# we do nothing,
# we can not even validate params because this is a page not found error (any parameter can be in)
sub _process
{
}

# this is to be able to display this page wtih any parameter and this page is
# safe because it only displays text
sub _validateReferer
{
    return 1;
}

1;
