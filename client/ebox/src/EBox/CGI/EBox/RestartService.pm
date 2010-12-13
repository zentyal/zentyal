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

package EBox::CGI::EBox::RestartService;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use Error qw(:try);

sub new # (cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    $self->{errorchain} = "/Dashboard/Index";
    $self->{redirect} = "/Dashboard/Index";
    return $self;
}

sub domain
{
    return 'ebox';
}

sub _process
{
    my $self = shift;

    my $global = EBox::Global->getInstance(1);

    $self->_requireParam('module', __('module name'));
    my $mod = $global->modInstance($self->param('module'));
    $self->{chain} = "/Dashboard/Index";
    try {
        $mod->restartService();
        $self->{msg} = __('The module was restarted correctly.');
    } catch EBox::Exceptions::Internal with {
        my ($ex) = @_;
        EBox::error("Restart of $mod from dashboard failed: " . $ex->text);
        $self->{msg} = __x('Error restarting service. See {logs} for more information.', logs => '/var/log/ebox/ebox.log');
    };
    $self->cgi()->delete_all();
}

1;
