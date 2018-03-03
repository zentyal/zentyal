# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::SysInfo::CGI::RestartService;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Config;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use TryCatch;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    $self->{errorchain} = "/Dashboard/Index";
    $self->{redirect} = "/Dashboard/Index";
    return $self;
}

sub _process
{
    my $self = shift;

    my $global = EBox::Global->getInstance(1);

    $self->_requireParam('module', __('module name'));
    my $mod = $global->modInstance($self->param('module'));
    my $name = $mod->printableName();
    $self->{chain} = "/Dashboard/Index";
    try {
        $mod->restartService(restartUI => 1);
        $self->{msg} = __('The module was restarted correctly.');

        my $audit = $global->modInstance('audit');
        $audit->logAction('Dashboard', 'Module Status', 'restartService', $name);
    } catch (EBox::Exceptions::Lock $e) {
        EBox::error("Restart of $name from dashboard failed because it was locked");
        $self->{msg} = __x('Service {mod} is locked by another process. Please wait its end and then try again.',
                           mod  => $name,
                          );
    } catch (EBox::Exceptions::Internal $e) {
        EBox::error("Restart of $name from dashboard failed: " . $e->text);
        $self->{msg} = __x('Error restarting service {mod}. See {logs} for more information.',
                           mod  => $name,
                           logs => EBox::Config::logfile());
    }
    my $request = $self->request();
    my $parameters = $request->parameters();
    $parameters->clear();
}

1;
