# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::BWMonitor;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::FirewallObserver);

use EBox;
use EBox::Gettext;
use EBox::Menu::Item;
use Error qw(:try);
use EBox::Exceptions::External;

use constant CONF_DIR => EBox::Config::conf() . '/bwmonitor/';
use constant UPSTART_DIR => '/etc/init/';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'bwmonitor',
                                      printableName => __('Bandwidth Monitor'),
                                      @_);
    bless($self, $class);
    return $self;
}

sub modelClasses
{
    return [
        'EBox::BWMonitor::Model::Interfaces',
    ];
}

# Method: menu
#
#       Overrides EBox::Module method.
#
sub menu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'BWMonitor/View/Interfaces',
                                    'text' => $self->printableName(),
                                    'separator' => 'Gateway',
                                    'order' => 230));
}

sub _setConf
{
    my ($self) = @_;

    # Write daemon upstart and config files
    foreach my $iface (@{$self->ifaces()}) {
        EBox::Module::Base::writeConfFileNoCheck(UPSTART_DIR . "zentyal.bwmonitor-$iface.conf",
            "bwmonitor/upstart.mas",
            [ interface => $iface ]);

#        EBox::Module::Base::writeConfFileNoCheck(CONF_DIR . 'TODOCONFFILE.foo',
#            "bwmonitor/upstart.mas",
#            [
#            ]);
    }
}

sub _daemons
{
    my ($self) = @_;

    # TODO
    return [];
}

# Function: ifaces
#
#   Interfaces where bandwidth monitor is enabled
#
sub ifaces
{
    my ($self) = @_;
    my $model = $self->model('Interfaces');
    my @ifaces;

    for my $id (@{$model->enabledRows()}) {
        my $row = $model->row($id);
        push(@ifaces, $row->valueByName('interface'));
    }

    return \@ifaces;
}


1;
