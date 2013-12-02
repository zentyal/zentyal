# Copyright (C) 2012-2013 Zentyal S.L.
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

use strict;
use warnings;

package EBox::RemoteServices::CGI::DisasterRecovery;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;
use EBox::RemoteServices::Backup;
use TryCatch::Lite;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title' => __('Recover from a disaster'),
                                  'template' => 'remoteservices/disaster.mas', @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my @array;

    try {
        my $backups = EBox::RemoteServices::Backup->new()->listRemoteBackups();
        if ($backups) {
            push (@array, 'backups' => $backups);
        }
    } catch ($e) {
        $self->setErrorFromException($e);
        $self->setChain('RemoteServices/NoConnection');
    }

    $self->{params} = \@array;
}

sub _menu
{
    my ($self) = @_;

    my $software = EBox::Global->modInstance('software');
    $software->firstTimeMenu(0);
}

sub _top
{
    my ($self) = @_;

    $self->_topNoAction();
}

1;
