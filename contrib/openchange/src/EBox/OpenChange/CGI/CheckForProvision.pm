# Copyright (C) 2008-2015 Zentyal S.L.
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

package EBox::OpenChange::CGI::CheckForProvision;
use base 'EBox::CGI::ClientRawBase';

use EBox::Global;
use TryCatch;

sub new
{
    my ($class, @params) = @_;
    my $self = $class->SUPER::new(@params);
    bless($self, $class);
    return  $self;
}

sub _process
{
    my ($self) = @_;
    $self->{json} = {success => 0};

    my $global = EBox::Global->getInstance();
    my $openchange = $global->modInstance('openchange');
    my $provision  = $openchange->model('Provision');

    my $orgName = $self->unsafeParam('orgName');
    my $admin   = $self->unsafeParam('admin');
    my $adminPassword = $self->unsafeParam('adminPassword');
    try {
        my @params = (admin => $admin, adminPassword => $adminPassword);
        $provision->checkForProvision($orgName, @params);
        $self->{json}->{success} = 1;        
    } catch ($ex) {
        $self->{json}->{error} = "$ex";
    }
}

1;
