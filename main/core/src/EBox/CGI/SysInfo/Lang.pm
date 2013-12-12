# Copyright (C) 2004-2007 Warp Networks S.L
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

package EBox::CGI::SysInfo::Lang;

use strict;
use warnings;

use base 'EBox::CGI::Base';

use EBox;
use EBox::Global;
use EBox::Menu;
use EBox::Config;
use EBox::Gettext;
use EBox::Sudo;
use POSIX qw(setlocale LC_ALL);

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    $self->{redirect} = "SysInfo/General";
    return $self;
}

sub _process
{
    my $self = shift;

    if (defined($self->param('setlang'))) {
        my $lang = $self->param('lang');
        EBox::setLocale($lang);
        POSIX::setlocale(LC_ALL, EBox::locale());
        EBox::Menu::regenCache();
        EBox::Global->getInstance()->modChange('apache');
        my $audit = EBox::Global->modInstance('audit');
        $audit->logAction('System', 'General', 'changeLanguage', $lang);
    }
}

1;
