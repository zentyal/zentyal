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

package EBox::Wizard::CGI::SoftwareSetupFinish;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Installation finished'),
            'template' => 'wizard/software-setup-finish.mas',
            @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;
    $self->{params} = [
         firstTime => $self->param('firstTime'),
       ];
}

sub _menu
{
    my ($self) = @_;
    if (EBox::Global->first() and EBox::Global->modExists('software')) {
        my $software = EBox::Global->modInstance('software');
        return $software->firstTimeMenu(5);
    } else {
        return $self->SUPER::_menu(@_);
    }
}

sub _top
{
    my ($self)= @_;
    return $self->_topNoAction();
}

1;
