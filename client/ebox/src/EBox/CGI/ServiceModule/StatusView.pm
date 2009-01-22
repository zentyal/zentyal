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


# package EBox::CGI::ServiceModule::StatusView
#
#   This class is used to list the status of the modules
#
package EBox::CGI::ServiceModule::StatusView;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::ServiceManager;
use EBox::Global;
use EBox::Gettext;



## arguments:
## 	title [required]
sub new 
{
    my $class = shift;
    my $self = $class->SUPER::new( 'title' => __('Module status configuration'),
                                   'template' => '/moduleStatus.mas',
            @_);

    bless($self, $class);
    return $self;
}



sub _process
{
    my ($self) = @_;

    my $manager = new EBox::ServiceManager();
    my $modules = $manager->moduleStatus();
    my @params;
    push @params, (modules => $modules);

    $self->{params} = \@params;
}


1;


