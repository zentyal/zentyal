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

package EBox::ServiceModule::CGI::ConfigureModuleController;

use base 'EBox::CGI::ClientBase';

#   This class is used as a controller to receive the green light
#   from users to configure which is needed to enable a module

use EBox::ServiceManager;
use EBox::Global;
use EBox::Gettext;

use TryCatch;
use EBox::Exceptions::Base;
use EBox::Exceptions::External;
use EBox::Exceptions::Internal;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    $self->_requireParam('module');
    my $modName = $self->param('module');

    my $manager = new EBox::ServiceManager();
    my $global = EBox::Global->getInstance();
    my $module = $global->modInstance($modName);
    my @depModules = map {
        my $mod = $global->modInstance($_);
        $mod->isa('EBox::Module::Service') ? ($mod) : ();
    } @{ $module->enableModDependsRecursive() };

    foreach my $dep (@depModules) {
        try {
            if (not $dep->configured()) {
                $dep->configureModule();
            } elsif (not $dep->isEnabled()) {
                $dep->enableService(1);
            }
        } catch ($e) {
            if ($e->isa("EBox::Exceptions::External")) {
                throw EBox::Exceptions::External(
                    __x('Failed to enable {mod}: {err}', mod => $dep->printableName(), err => $e->stringify())
                );
            } else {
                throw EBox::Exceptions::Internal('Failed to enable' . $dep->name() . ' ' .  $e->stringify());
            }
        }
    }

    try {
        $module->configureModule();
    } catch ($e) {
        if ($e->isa("EBox::Exceptions::External")) {
            throw EBox::Exceptions::External(__x('Failed to enable: {err}', err => $e->stringify()));
        } else {
            throw EBox::Exceptions::Internal("Failed to enable: " .  $e->stringify());
        }
    }
    $self->{redirect} = "ServiceModule/StatusView";
}

1;

