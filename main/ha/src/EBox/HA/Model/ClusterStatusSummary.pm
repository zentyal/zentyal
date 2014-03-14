# Copyright (C) 2014 Zentyal S. L.
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

package EBox::HA::Model::ClusterStatusSummary;

# Class: EBox::HA::Model::ClusterStatusSummary
#
#     Model to show the cluster summary status.
#

use base 'EBox::Model::Template';

use EBox::Gettext;
use EBox::HA::ClusterStatus;

# Group: Public methods

# Method: templateName
#
# Overrides:
#
#     <EBox::Model::Template::templateName>
#
sub templateName
{
    return '/ha/summary.mas';
}

# Method: templateContext
#
# Overrides:
#
#     <EBox::Model::Template::templateContext>
#
sub templateContext
{
    my ($self) = @_;

    $self->{ha} = $self->parentModule();
    $self->{clusterStatus} = new EBox::HA::ClusterStatus(ha => $self->{ha});
    my $summary = $self->{clusterStatus}->summary();

    if (defined($summary)) {
        return {
            metadata => [
                # name => value
                [ __('Cluster name')   => $self->{ha}->model('Cluster')->nameValue()],
                [ __('Cluster secret') => $self->{ha}->userSecret()],
                [ __('Current Designated Controller')     => $self->{clusterStatus}->designatedController()],
                [ __('Last update')     => $summary->{'last_update'}],
                [ __('Last modification')     => $summary->{'last_change'}],
                [ __('Configurated nodes')     => $self->{clusterStatus}->numberOfNodes() . ' ' . __('nodes')],
                [ __('Configurated resources')     => $self->{clusterStatus}->numberOfResources() . ' ' . __('resources')],
            ],
        };
    } else {
        return {
            metadata => [
                # name => value
                [ __('Cluster name') => $self->{ha}->model('Cluster')->nameValue()],
                [ __('Cluster status') =>
                        __x('Error: {service} service is not running', service => 'Zentyal HA') ],
            ],
        };
    }
}

1;
