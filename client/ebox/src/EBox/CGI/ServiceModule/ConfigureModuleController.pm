# Copyright (C) 2008 Warp Networks S.L.
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


# package EBox::CGI::ServiceModule::ConfigureModuleController
#
#   This class is used as a controller to receive the green light
#   from users to configure which is needed to enable a module
#
package EBox::CGI::ServiceModule::ConfigureModuleController;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::ServiceModule::Manager;
use EBox::Global;
use EBox::Gettext;

use Error qw(:try);
use EBox::Exceptions::Base;



## arguments:
## 	title [required]
sub new 
{
    my $class = shift;
    my $self = $class->SUPER::new( @_);

    bless($self, $class);
    return $self;
}



sub _process
{
    my ($self) = @_;

    $self->_requireParam('module');
    my $modName = $self->param('module');
    my $manager = new EBox::ServiceModule::Manager();
    my $module = EBox::Global->modInstance($modName);

    $module->setConfigured(1);
    $module->enableService(1);
    $manager->updateModuleDigests($modName);
    
    try {
        $module->enableActions();
    } otherwise {
        my ($excep) = @_;
        $module->setConfigured(undef);
        $module->enableService(undef);
        #throw EBox::Exceptions::Internal($excep->as_string());
        throw EBox::Exceptions::Internal("Failed to enable");
    };

    $manager->updateModuleDigests($modName);


    $self->{redirect} = "ServiceModule/StatusView";

}

1;


