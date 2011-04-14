# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::CGI::Software::EBox;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use Error qw(:try);

use constant FIRST_RUN_FILE => '/var/lib/ebox/.first';

## arguments:
##  title [required]
sub new {
    my $class = shift;
    my $self;
    if (-f FIRST_RUN_FILE) {
        $self = $class->SUPER::new('title' =>
                __d('Choose Zentyal packages to install', 'ebox-software'),
                'template' => 'software/ebox.mas',
                @_);
    } else {
        $self = $class->SUPER::new('title' =>
                __d('Zentyal components', 'ebox-software'),
                'template' => 'software/ebox.mas',
                @_);
    }
    $self->{domain} = 'ebox-software';
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $software = EBox::Global->modInstance('software');

    my $updateList = 0;
    my $updateListError = 0;
    my $updateListErrorMsg = undef;
    if (defined($self->param('updatePkgs'))) {
        $updateList = 1;
        try {
            unless ($software->updatePkgList()) {
                $updateListError = 1;
            } 
        } otherwise {
            my ($ex) = @_;
            $updateListError = 1;
            $updateListErrorMsg = "$ex";
        };
    }

    my @array = ();
    push(@array, 'eboxpkgs'     => $software->listEBoxPkgs());
    push(@array, 'updateStatus' => $software->updateStatus(1));
    push(@array, 'QAUpdates'    => $software->QAUpdates());
    push(@array, 'isOffice'     => $software->isInstalled('ebox-office'));
    push(@array, 'isUtm'        => $software->isInstalled('ebox-security'));
    push(@array, 'isInfrastructure'    => $software->isInstalled('ebox-infrastructure'));
    push(@array, 'isGateway'    => $software->isInstalled('ebox-gateway'));
    push(@array, 'isCommunication'    => $software->isInstalled('ebox-communication'));
    push(@array, 'updateList'    => $updateList);
    push(@array, 'updateListError'    => $updateListError);
    push(@array, 'updateListErrorMsg'    => $updateListErrorMsg);
    push(@array, 'brokenPackages'     => $software->listBrokenPkgs());

    $self->{params} = \@array;
}

sub _menu
{
    my ($self) = @_;
    if (-f FIRST_RUN_FILE) {
        my $software = EBox::Global->modInstance('software');
        $software->firstTimeMenu(0);
    } else {
        $self->SUPER::_menu(@_);
    }
}

sub _top
{
    my ($self) = @_;
    if (-f FIRST_RUN_FILE) {
        $self->_topNoAction();
    } else {
        $self->SUPER::_top(@_);
    }
}

1;
