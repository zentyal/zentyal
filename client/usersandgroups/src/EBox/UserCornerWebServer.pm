# Copyright (C) 2009  eBox Technologies S.L.
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

package EBox::UserCornerWebServer;

use EBox::Config;
use EBox::Gettext;
use EBox::Global;
use EBox::Menu::Root;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            );

use constant USERCORNER_APACHE => EBox::Config->conf() . '/user-apache2.conf';

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'usercorner',
            domain => 'ebox-usersandgroups',
            printableName => __('User Corner'),
            @_);

    bless($self, $class);
    return $self;
}


# Method: enableModDepends
#
#   Override EBox::Module::Service::enableModDepends
#
sub enableModDepends
{
    return ['users'];
}


# Method: modelClasses
#
# Overrides:
#
#       <EBox::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [ 'EBox::UserCornerWebServer::Model::Settings' ];
}

# Method: _daemons
#
#  Override <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'ebox.apache2-usercorner'
        }
    ];
}

# Method: _setConf
#
#  Override <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    # We can assume the listening port is ready available
    my $settings = $self->model('Settings');

    # Overwrite the listening port conf file
    EBox::Module::Base::writeConfFileNoCheck(USERCORNER_APACHE,
        "usersandgroups/user-apache2.conf.mas",
        [ port => $settings->portValue() ],
    )
}

# Method: menu
#
#        Show the usercorner menu entry
#
# Overrides:
#
#        <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;
    my $item = new EBox::Menu::Item(name => 'UserCorner',
                                    text => __('User corner'),
                                    url => 'UserCorner/View/Settings'
    );
    $root->add($item);
}

1;
