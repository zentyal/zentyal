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

# Class:
#
#   EBox::Squid::Model::ExternalFilter
#
#
#   It subclasses <EBox::Model::DataTable>
#
#
#

use strict;
use warnings;

package EBox::Mail::Model::ExternalFilter;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;

use EBox::View::Customizer;
use EBox::Validate qw(:all);
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::Union;
use EBox::Types::Port;
use EBox::Types::HostIP;
use EBox::Types::Select;

# XXX TODO: disable custom filter controls when custom filter is not selected

use EBox::Exceptions::External;

sub new
{
    my $class = shift @_ ;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: headTitle
#
# Overrides:
#
#   <EBox::Model::Component::headTitle>
#
sub headTitle
{
    return undef;
}

# Method:  _table
#
# This method overrides <EBox::Model::DataTable::_table> to return
# a table model description.
#
# This table is composed of two fields:
#
#   domain (<EBox::Types::Text>)
#   enabled (EBox::Types::Boolean>)
#
# The only avaiable action is edit and only makes sense for 'enabled'.
#
sub _table
{
    my @tableDesc = (
         new EBox::Types::Select(
                                 fieldName => 'externalFilter',
                                 printableName => __('Filter in use'),
                                 editable => 1,
                                 populate => \&_availableFilters,
                                 defaultValue => 'none',
                                 disableCache => 1,
                                ),
         new EBox::Types::Port(
                               fieldName => 'fwport',
                               printableName => __("Custom filter's mail forward port"),
                               editable => 1,
                               defaultValue => 10025,
                              ),
         new EBox::Types::HostIP(
                                 fieldName => 'ipfilter',
                                 printableName =>  __("Custom filter's IP address"),
                                 editable => 1,
                                 defaultValue => '127.0.0.1',
                                ),
         new EBox::Types::Port(
                               fieldName => 'portfilter',
                               printableName => __("Custom filter's Port"),
                               editable => 1,
                               defaultValue => 10024,
                              ),

        );

      my $dataForm = {
                      tableName          => __PACKAGE__->nameFromClass(),
                      printableTableName => __('Mail filter options'),
                      modelDomain        => 'Mail',
                      defaultActions     => [ 'editField', 'changeView' ],
                      tableDescription   => \@tableDesc,

                     };

    return $dataForm;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to show and hide mailfilter configuration
#   depending on the filter selected
#
#
sub viewCustomizer
{
        my ($self) = @_;
        my $customizer = new EBox::View::Customizer();
        my $fields = [qw/fwport ipfilter portfilter/];
        $customizer->setModel($self);
        $customizer->setOnChangeActions(
        { externalFilter =>
            {
              none  => { disable => $fields },
              custom => { enable => $fields },
              mailfilter => { disable => $fields },
            }
        });
        return $customizer;
}

sub _availableFilters
{
    my @options = (
                       { value => 'none' , printableValue => __('none') },
                       { value => 'custom'   , printableValue => __('custom')},
                  );

    return \@options;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    $self->_checkFWPort($action, $params_r, $actual_r);
}

sub _checkFWPort
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (not $params_r->{fwport}) {
        return;
    }

    # check if port is available
    my $firewall = EBox::Global->modInstance('firewall');
    defined $firewall or
        return;
    $firewall->isEnabled() or
        return;
    $firewall->availablePort('tcp', $params_r->{fwport}->value());
}

sub precondition
{
    my ($self) = @_;
    my $mailfilter = EBox::Global->modInstance('mailfilter');
    unless ($mailfilter) {
        return 1;
    }

    return (not $mailfilter->isEnabled());
}

sub preconditionFailMsg
{
    return __('As long mailfilter module is enabled the mail server will use the filter it provides');
}

1;
