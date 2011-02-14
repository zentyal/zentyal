# Copyright (C) 2010 eBox Technologies S.L.
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

package EBox::CGI::Wizard;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new # (error=?, msg=?, cgi=?)
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Initial configuration wizard'),
            'template' => 'wizard.mas',
            @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my $self = shift;

    my @array = ();
    push(@array, 'pages' => $self->_modulesWizardPages);
    $self->{params} = \@array;
}


# Method: _modulesWizardPages
#
#   Returns an array ref with installed modules wizard pages
sub _modulesWizardPages
{
    my $global = EBox::Global->getInstance();
    my @pages = ();

    my $mgr = EBox::ServiceManager->new();
    my @modules = @{$mgr->_dependencyTree()};

    foreach my $name ( @modules ) {
        my $module = $global->modInstance($name);
        if ($module->firstInstall()) {
            push (@pages, @{$module->wizardPages()});
        }
    }

    return \@pages;
}

sub _menu
{
    my ($self) = @_;

    if (EBox::Global->first() and EBox::Global->modExists('software')) {
        my $software = EBox::Global->modInstance('software');
        $software->firstTimeMenu(3);
    } else {
        $self->SUPER::_menu(@_);
    }
}

sub _top
{
    my ($self)= @_;
    $self->_topNoAction();
}

1;
