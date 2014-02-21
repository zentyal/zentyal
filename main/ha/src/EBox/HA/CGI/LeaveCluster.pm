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

package EBox::HA::CGI::LeaveCluster;

# Class: EBox::HA::CGI::LeaveCluster
#
#      Leave the cluster and redirect to Cluster configuration page
#

use base qw(EBox::CGI::ClientBase);

use EBox::Gettext;
use EBox::Global;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->{redirect} = 'HA/Composite/Initial';
    bless ($self, $class);
    return $self;
}

# Method: actuate
#
#    Leave the cluster and redirect
#
# Overrides:
#
#    <EBox::CGI::ClientBase>
#
sub actuate
{
    my ($self) = @_;

    my $ha = EBox::Global->getInstance()->modInstance('ha');
    $ha->leaveCluster();

    # No parameters to send to the chain
    my $request = $self->request();
    my $parameters = $request->parameters();
    $parameters->clear();
}

1;
