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


# package EBox::CGI::ServiceModule::ConfigureView
#
#   This class is used to list the actions and file modifications
#   that eBox needs to do to enable the module
#
package EBox::CGI::ServiceModule::ConfigureView;

use strict;
use warnings;

use base 'EBox::CGI::ClientRawBase';

use EBox::ServiceModule::Manager;
use EBox::Global;
use EBox::Gettext;



## arguments:
## 	title [required]
sub new 
{
    my $class = shift;
    my $self = $class->SUPER::new( 'template' => '/configureView.mas',
            @_);

    bless($self, $class);
    return $self;
}



sub _process
{
    my ($self) = @_;

    my $mod = $self->param('module');
    my $modInstance = EBox::Global->modInstance($mod);

    my @params; 
    push (@params, (files => $modInstance->usedFiles(),
                    actions => $modInstance->actions(),
                    module => $mod));

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
