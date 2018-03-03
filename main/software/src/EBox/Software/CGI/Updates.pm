# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Software::CGI::Updates;

use base 'EBox::CGI::ClientBase';

use EBox;
use EBox::Global;
use EBox::Gettext;
use TryCatch;

## arguments:
##  title [required]
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new('title'    => __('System updates'),
            'template' => 'software/updates.mas',
            @_);
    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;

    my $software = EBox::Global->modInstance('software');

    try {
        my $updateList = 0;
        if (defined($self->param('updatePkgs'))) {
            # EBox::info("Update packages list");
            if ($software->updatePkgList()) {
                $updateList = 1;
            } else {
                $updateList = 2;
            }
        }
        my @array = ();
        # Clear list if the user has clicked on update pkg list
        my $upg = $software->listUpgradablePkgs(($updateList == 1), 1);
        if (@{$upg} == 0) {
            $self->{msg} = __('The system components are up to date.');
            $self->{params} = [
                updateStatus => $software->updateStatus(0),
                automaticUpdates => 0,
                QAUpdates => $software->QAUpdates(),
                updateList => $updateList,
            ];
            return;
        }
        push(@array, 'upgradables' => $upg);
        push(@array, 'updateList' => $updateList);
        push(@array, 'updateStatus' => $software->updateStatus(0));
        push(@array, 'automaticUpdates' => $software->getAutomaticUpdates());
        push(@array, 'QAUpdates' => $software->QAUpdates());
        $self->{params} = \@array;
    } catch (EBox::Exceptions::External $e) {
        my @array;
        push(@array, 'automaticUpdates' => 0);
        push(@array, 'QAUpdates'        => $software->QAUpdates());
        push(@array, 'updateStatus'     => $software->updateStatus(0));
        $self->{params} = \@array;
    }
}

1;
