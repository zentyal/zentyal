# Copyright (C) 2005-2007 Warp Networks S.L
# Copyright (C) 2011-2011 Zentyal S.L.
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

package EBox::CGI::SysInfo::ChangeDate;

use strict;
use warnings;

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
    $self->{redirect} = 'SysInfo/General';
    return $self;
}

sub _process
{
    my $self = shift;
    my $sysinfo= EBox::Global->modInstance('sysinfo');

    $self->_requireParam('day', __('Day'));
    $self->_requireParam('month', __('Month'));
    $self->_requireParam('year', __('Year'));
    $self->_requireParam('hour', __('Hour'));
    $self->_requireParam('minute', __('Minutes'));
    $self->_requireParam('second', __('Seconds'));

    my $day = $self->param('day');
    my $month = $self->param('month');
    my $year = $self->param('year');
    my $hour = $self->param('hour');
    my $minute = $self->param('minute');
    my $second = $self->param('second');

    $sysinfo->setNewDate($day, $month, $year, $hour, $minute, $second);

    my $audit = EBox::Global->modInstance('audit');
    my $dateStr = "$year/$month/$day $hour:$minute:$second";
    $audit->logAction('System', 'General', 'changeDateTime', $dateStr);
}

1;
