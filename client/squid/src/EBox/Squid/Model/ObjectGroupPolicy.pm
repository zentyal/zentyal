# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Squid::Model::ObjectGroupPolicy;
use base 'EBox::Squid::Model::GroupPolicyBase';
# Class:
#
#    EBox::Squid::Model::ObjectGroupPolicy
#
#
#   It subclasses <EBox::Model::DataTable>
#

# eBox uses
use EBox;
use EBox::Global;
use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Text;
use EBox::Squid::Types::Policy;
use EBox::Squid::Types::TimePeriod;

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::Squid::Model::GroupPolicy> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    
    bless $self, $class;
    return $self;
    
}



# Method: _table
#
#
sub _table
{
    my ($self) = @_;

  my $dataTable =
  {
      tableName          => name(),
#      pageTitle          => __(q{Configure object's user groups policies}),
      printableTableName => __('List of groups'),
      modelDomain        => 'Squid',
      'defaultController' => '/ebox/Squid/Controller/ObjectGroupPolicy',
      'defaultActions' => [     
          'add', 'del',
      'editField',
      'changeView',
      'move',
          ],
      tableDescription   => $self->tableHeader(),
      class              => 'dataTable',
      order              => 1,
      rowUnique          => 1,
      automaticRemove    => 1,
      printableRowName   => __("group's policy"),
      help               => __("Here you can deny or allow access depending on the user group. Filtering would occur if the object policy requires it"),
      messages           => {
          add => __(q{Added group's policy}),
          del =>  __(q{Removed group's policy}),
          update => __(q{Updated group's policy}),
      },
  };

}






sub name
{
    return 'ObjectGroupPolicy';
}

sub validateTypedRow
{
  my ($self, $action, $params_r, $actual_r) = @_;
  $self->_checkTransProxy($params_r, $actual_r);
  $self->_checkObjectPolicy();
}


sub _checkTransProxy
{
  my ($self, $params_r, $actual_r) = @_;

  my $squid = EBox::Global->modInstance('squid');
  if (not $squid->transproxy()) {
    return;
  }

  if ($self->existsGroupPolicy()) {
    throw EBox::Exceptions::External(
       __('User group policies are not compatible with transparent proxy mode')
                                    );
  }
}


sub _checkObjectPolicy
{
    my ($self) = @_;


    my $row = $self->parentRow();
    EBox::debug("ObjectGroupPolicy parentRow $row");


    my $policy = $row->elementByName('policy');
    if (not $policy->usesAuth()) {
        throw EBox::Exceptions::External(
  __('The object needs to be set to a policy with authorization for be able to use groups policies')
                                        );
    }
}





sub pageTitle
{
    my ($self) = @_;
    my $parentRow = $self->parentRow();
    my $objectPrintableName = $parentRow->elementByName('object')->printableValue();
    my $title = __x(
            'Configure object {ob} user groups policies',
                    ob => $objectPrintableName,
                   );

    
    return $title;
}

1;

