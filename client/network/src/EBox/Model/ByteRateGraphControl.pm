# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::Network::Model::ByteRateGraphControl
#
#   This class is intended to handle the control settings related to
#   the ByteRateGraph model to change its displayed values
#

package EBox::Network::Model::ByteRateGraphControl;
use base 'EBox::Model::ImageControl';
#

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Composite;
use EBox::Types::HostIP;
use EBox::Types::Text;
use EBox::Types::Union::Text;

# Group: Public methods

# Method: printableName
#
# Overrides:
#
#     <EBox::Model::DataTable::printableName>
#
sub printableName
{
    return  __('Select traffic graphic');
}

# Method: help
#
# Overrides:
#
#     <EBox::Model::DataTable::help>
#
sub help
{
    return __('Several views are showed depending on the parameter selection. '
              . 'An host IP address and a service, which must match the text '
              . 'given by the graphs legend based on /etc/services, may be '
              . 'required by the graph type. The flow view will change accordingly');
}

# Group: Protected methods

sub _imageModel
{
  my ($self) = @_;
  
  my $network = EBox::Global->modInstance('network');
  return $network->model('ByteRateGraph');
}
 
sub _tableDesc
{
  my @tableHead
    = (
       new EBox::Types::Union(
             printableName => __('Graph type'),
             fieldName     => 'graphType',
             editable      => 1,
             subtypes      =>
              [
               new EBox::Types::Union::Text(
                                            fieldName => 'activeSrcsGraph',
                                            printableName => __('All active traffic by source'),
                                           ),
               new EBox::Types::Union::Text(
                                            fieldName => 'activeServicesGraph',
                                            printableName => __('All active traffic by service'),
                                           ),
               new EBox::Types::HostIP(
                                       fieldName => 'srcGraph',
                                       printableName => __('Traffic by selected source'),
                                       editable => 1,
                                       size     => 13,
                                      ),
               new EBox::Types::Text(
                                     fieldName => 'serviceGraph',
                                     printableName => __('Traffic by selected service'),
                                     editable => 1,
                                     size => 6,
                                    ),
               new EBox::Types::Composite(
                      fieldName => 'srcAndServiceGraph',
                      printableName => __('Traffic by source and service'),
		      editable => 1,
		      showTypeName => 0,
                      types =>
                         [
                          new EBox::Types::HostIP(
                                                  printableName  => __('Source'),
                                                  fieldName => 'source',
                                                  size => 13,
                                                  editable => 1,
                                                 ),
                          new EBox::Types::Text(
                                                printableName  => __('Service'),
                                                fieldName => 'netService',
                                                size => 6,
                                                editable => 1,
                                               ),
                         ]
                                                ),
              ]
                             ),
      );



  return \@tableHead;
}

sub _setTypedRow
{
  my ($self, @params) = @_;
    
  my $global   = EBox::Global->getInstance();
  my $networkChanged = $global->modIsChanged('network');

  $self->SUPER::_setTypedRow(@params);

  if (not $networkChanged) {
    $global->set_bool('modules/network/changed', 0);
  }


}
1;
