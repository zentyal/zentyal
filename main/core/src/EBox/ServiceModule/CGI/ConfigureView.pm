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

package EBox::ServiceModule::CGI::ConfigureView;

use base 'EBox::CGI::ClientPopupBase';

#   This class is used to list the actions and file modifications
#   that Zentyal needs to do to enable the module

use EBox::ServiceManager;
use EBox::Global;
use EBox::Gettext;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('template' => '/configureView.mas', @_);

    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance();
    my $mod = $self->param('module');
    my $modInstance = $global->modInstance($mod);
    my %files   = map {
         ($_->{file} => $_)
    }   @{ $modInstance->usedFiles};
    my @actions = @{ $modInstance->actions()  };

    my @depsToEnable;
    my @modDeps = @{ $modInstance->enableModDependsRecursive()  };
    foreach my $depName (@modDeps) {
        my $depMod = $global->modInstance($depName);
        $depMod->isa('EBox::Module::Service') or next;

        if ($depMod->isEnabled()) {
            next;
        }
        push @depsToEnable, $depMod->printableName();

        foreach my $usedFile (@{ $depMod->usedFiles()  }) {
            if ($files{$usedFile->{file}}) {
                my $file = $files{$usedFile->{file}};
                $file->{module} .= ' ' . $usedFile->{module};
                $file->{reason} .= "\n" . $usedFile->{reason};
            } else {
                $files{$usedFile->{file}} = $usedFile;
            }
        }

        push @actions, @{ $depMod->actions() };

    }

    my @params = (files => [values %files],
                  actions => \@actions,
                  module => $mod,
                  depsToEnable => \@depsToEnable,
                 );
   $self->{params} = \@params;

}

1;
