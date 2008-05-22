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


# package EBox::CGI::ServiceModule::StatusController
#
#  This class is to gather those modules which the user wants to enable.
#  It takes care of disabling/enabling dependencies
#
package EBox::CGI::ServiceModule::StatusController;

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
    my $self = $class->SUPER::new('template' => '/moduleStatusTable.mas', @_);

    bless($self, $class);
    return $self;
}



sub _process
{
    my ($self) = @_;

    my %modules;
    for my $mod (@{$self->params()}) {
        my  @params = $self->param($mod);
        my $enabled = undef;
        if (@params > 1) {
            $enabled = 1;
        }
        $modules{$mod} = $enabled; 
    }

#     use Data::Dumper;
#     EBox::debug(Dumper \%modules);

    my $manager = new EBox::ServiceModule::Manager();
    $manager->enableServices(\%modules);

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


