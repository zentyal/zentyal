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

# package EBox::CGI::ServiceModule::StatusController
#
#  This class is to gather those modules which the user wants to enable.
#  It takes care of disabling/enabling dependencies
#
package EBox::ServiceModule::CGI::StatusController;

use base 'EBox::CGI::ClientRawBase';

use EBox::ServiceManager;
use EBox::Global;
use EBox::Gettext;


sub new
{
    my $class = shift;

    my $self = $class->SUPER::new('template' => '/moduleStatusTable.mas', @_);
    bless ($self, $class);

    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->_requireParam('module');
    $self->_requireParam('enable');

    my $global = EBox::Global->getInstance();
    my $modName = $self->param('module');
    my $enable  = $self->param('enable');

    if ($enable) {
        # enable dependencies of all modules to enable, if the module is disabled
        # the setService module take cares of that
        my @deps = @{ $global->modInstance($modName)->enableModDependsRecursive()};
        foreach my $name (@deps) {
            $global->modInstance($name)->enableService(1);
        }
    }

    my $mod = $global->modInstance($modName);
    $mod->enableService($enable);

    # answer
    my $manager = EBox::ServiceManager->new();
    my $modules = $manager->moduleStatus();
    my @params;
    push @params, (modules => $modules,
                   hasChanged => EBox::Global->getInstance()->unsaved());

    $self->{params} = \@params;
}

sub _print
{
    my $self = shift;

    if ($self->{'to_print'}) {
        print($self->cgi()->header(-charset=>'utf-8'));
        print $self->{'to_print'};
    } else {
        $self->SUPER::_print();
    }
}

1;
