# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Software::CGI::AutomaticOptions;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

## arguments:
##  title [required]
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return $self;
}

sub requiredParameters
{
    return [qw(automaticHour automaticMinute)];
}

sub optionalParameters
{
    return [qw(submit ajax_request_cookie)];
}

sub actuate
{
    my ($self) = @_;
    my $hour = $self->param('automaticHour');
    my $minute = $self->param('automaticMinute');

    my $time = $hour . ':' . $minute;
    my $software = EBox::Global->modInstance('software');
    $software->setAutomaticUpdatesTime($time);

    $self->{redirect} = 'Software/Config';
}

# to avoid the <div id=content>
sub _print
{
    my ($self) = @_;
    $self->_printPopup();
}

1;
