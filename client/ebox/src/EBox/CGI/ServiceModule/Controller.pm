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


# package EBox::CGI::ServiceModule::Controller
#
#  This class is to gather the files which have been accepted to modify 
#  by the user
#
package EBox::CGI::ServiceModule::Controller;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::ServiceModule::Manager;
use EBox::Global;
use EBox::Gettext;



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

    my $manager = new EBox::ServiceModule::Manager();

    my @accepted;
    my @rejected;
    if ($self->param('acceptedFiles')) {
        @accepted = $self->param('acceptedFiles');
    }

    if ($self->param('rejectedFiles')) {
        @rejected = $self->param('rejectedFiles');
    }


    $manager->setAcceptedFiles(\@accepted, \@rejected);
}


1;


