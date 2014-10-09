# Copyright (C) 2014 Zentyal S.L.
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

package EBox::RemoteServices::CGI::UnsubscribeServer;
use base qw(EBox::CGI::ClientRawBase);

use EBox::Config;
use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;

use TryCatch::Lite;


sub new
{
    my ($class, @params) = @_;
    my $self = $class->SUPER::new(@params);

    bless($self, $class);
    return $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json} = {success => 0 };


    my $remoteservices = EBox::Global->getInstance()->modInstance('remoteservices');
    try {
        $remoteservices->unsubscribe();

        $self->{json}->{success} = 1;
        # TODO: Launch save changes
        $self->{json}->{msg} = __x('Server unregistered. Save changes to remove all the subscription files');
    } catch ($ex)  {
        $self->{json}->{error} = "$ex";
    }


}

1;
