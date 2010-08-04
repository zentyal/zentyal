# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::CGI::Software::Updates;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';
use EBox;
use EBox::Global;
use EBox::Gettext;

## arguments:
## 	title [required]
sub new {
    my $class = shift;
    my $self = $class->SUPER::new('title'    => __('System updates'),
            'template' => 'software/updates.mas',
            @_);
    $self->{domain} = 'ebox-software';
    bless($self, $class);
    return $self;
}

sub _process($) {
    my $self = shift;

    my $software = EBox::Global->modInstance('software');

    if (defined($self->param('updatePkgs'))) {
        EBox::info("Update packages list");
        $software->updatePkgList();
    }

    $self->{title} = __('System updates');
    if (defined($self->param('updatePkgs'))) {
        EBox::info("Update packages list");
        $software->updatePkgList();
    }

    my @array = ();
    my $upg = $software->listUpgradablePkgs(0, 1);
    if (@{$upg} == 0) {
        $self->{msg} = __('The system components are up to date.');
        $self->{params} = [
            updateStatus => $software->updateStatus(0),
            automaticUpdates => 0,
            QAUpdates => $software->QAUpdates(),
        ];
        return;
    }
    push(@array, 'upgradables' => $upg);
    push(@array, 'updateStatus' => $software->updateStatus(0));
    push(@array, 'automaticUpdates' => $software->getAutomaticUpdates());
    push(@array, 'QAUpdates' => $software->QAUpdates());
    $self->{params} = \@array;
}

1;
