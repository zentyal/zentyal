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

package EBox::Software::CGI::Enable;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
##  title [required]
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{redirect} = 'Software/Config';
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;
    my $software= EBox::Global->modInstance('software');

    $self->_requireParam('active', __('automatic updates configuration'));
    $software->setAutomaticUpdates(($self->param('active') eq 'yes'));
}

1;
