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

package EBox::HA::CGI::RetryReplication;

# Class: EBox::HA::CGI::RetryReplication
#
#      Retry replication on a failed node
#

use base qw(EBox::CGI::ClientBase);

use EBox::Gettext;
use EBox::Global;
use EBox::Exceptions::DataNotFound;
use EBox::HA::NodeList;

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless ($self, $class);
    return $self;
}

# Method: requiredParameters
#
# Overrides:
#
#    <EBox::CGI::Base::requiredParameters>
#
sub requiredParameters
{
    return [ 'node' ];
}

# Method: actuate
#
#    Leave the cluster and redirect
#
# Overrides:
#
#    <EBox::CGI::Base::actuate>
#
sub actuate
{
    my ($self) = @_;

    my $name = $self->param('node');

    my $ha = EBox::Global->modInstance('ha');
    my $list = new EBox::HA::NodeList($ha);
    my $node = $list->node($name);

    $ha->askForReplicationNode($node);

    my $errors = $ha->get_state()->{errors};
    if ($errors->{$node}) {
        $self->JSONReply({ error => __x('Replication failed. Please check {logfile} for more information.', logfile => '/var/log/zentyal/zentyal.log') });
    }

    my $request = $self->request();
    my $parameters = $request->parameters();
    # No parameters to send to the chain
    $parameters->clear();
}

1;
