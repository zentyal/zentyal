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
use EBox::HA::CRMWrapper;

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

    return {
        metadata => [
            # name => value
            [ __('Cluster name')   => $self->parentModule()->model('Cluster')->nameValue()],
            [ __('Cluster secret') => 'raro'],
            [ __('Current DC')     => EBox::HA::CRMWrapper::currentDCNode()],
           ],
        help => __('DC is the Designated Controller to perform the operations in the cluster. This node may change and has no impact in the cluster.'),
    };
}

1;
