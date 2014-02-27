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

package EBox::HA::Model::ClusterMetadata;

# Class: EBox::HA::Model::ClusterMetadata
#
#     Model to show the cluster metadata.
#     It gives you the option to leave current cluster.
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
    return '/ha/metadata.mas';
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

    my $summary = $self->{clusterStatus}->summary() ? $self->{clusterStatus}->summary() : undef;

    if ($summary) {
        return {
            metadata => [
                # id, name, value
                [ 'cluster_name', __('Cluster name'), $self->parentModule()->model('Cluster')->nameValue()],
                [ 'cluster_secret', __('Cluster secret'), $self->parentModule()->userSecret()],
                [ 'cluster_dc', __('Current Designated Controller'), $self->{clusterStatus}->designatedController()],
            ],
            help => __('The current Designated Controller performs the operations in the cluster. This node may be changed without any impact in the cluster.'),
        };
    } else {
        return {
            metadata => [
                # id, name, value
                [ 'cluster_name', __('Cluster name'), $self->parentModule()->model('Cluster')->nameValue()],
                [ 'cluster_status', __('Cluster status'),
                    __x('Error: {service} service is not running', service => 'Zentyal HA') ],
            ],
        }
    }
}

1;
