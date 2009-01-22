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


# package EBox::CGI::ServiceModule::View
#
#  This class is to used to warn and prompt the user about the
#  configuration files which are going to be modified
#
package EBox::CGI::ServiceModule::View;

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox::ServiceManager;
use EBox::Global;
use EBox::Gettext;



## arguments:
## 	title [required]
sub new 
{
    my $class = shift;
    my $self = $class->SUPER::new( 'template' => '/configurationFiles.mas',
            @_);

    bless($self, $class);
    return $self;
}



sub _process
{
    my ($self) = @_;

    my $manager = new EBox::ServiceManager();
    my $files = $manager->checkFiles();
    my @params;
    push @params, (files => $files);

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


