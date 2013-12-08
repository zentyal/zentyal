# Copyright (C) 2010-2011 Zentyal S.L.
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

package EBox::Jabber::Model::GeneralSettings;

# Class: EBox::Jabber::Model::GeneralSettings
#
#   Form to set the general configuration settings for the jabber server.
#
use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::DomainName;
use EBox::Types::Select;
use EBox::Jabber;

# Group: Public methods

# Constructor: new
#
#       Create the new GeneralSettings model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Jabber::Model::GeneralSettings> - the recently
#       created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Method: formSubmitted
#
# Overrides:
#
#       <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    my @services = ();

    push(@services, { protocol => 'tcp', sourcePort => 'any', 'destinationPort' => EBox::Jabber::JABBERPORT });

    if ($self->sslValue() ne 'disabled') {
    push(@services, { protocol => 'tcp', sourcePort => 'any', 'destinationPort' => EBox::Jabber::JABBERPORTSSL });
    }

    if ($self->s2sValue()) {
    push(@services, { protocol => 'tcp', sourcePort => 'any', 'destinationPort' => EBox::Jabber::JABBERPORTS2S });
    }

    my $servMod = EBox::Global->modInstance('services');

    $servMod->setMultipleService(name => 'jabber', internal => 1, services => \@services);
}

# Group: Protected methods

sub _populateSSLsupport
{
    my @options = (
                       { value => 'disabled' , printableValue => __('Disabled')},
                       { value => 'allowssl', printableValue => __('Allow SSL')},
                       { value => 'forcessl', printableValue => __('Force SSL')},
                  );
    return \@options;
}

# Method: _table
#
#       The table description.
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
      (
       new EBox::Types::DomainName(
                                fieldName     => 'domain',
                                printableName => __('Jabber domain'),
                                editable      => 1,
                                defaultValue  => EBox::Jabber->fqdn(),
                               ),
       new EBox::Types::Select(
                                fieldName     => 'ssl',
                                printableName => __('SSL support'),
                                editable      => 1,
                                populate => \&_populateSSLsupport,
                                defaultValue => 'forcessl'
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 's2s',
                                printableName => __('Connect to other servers'),
                                editable      => 1,
                                defaultValue  => 0,
                               ),
       new EBox::Types::Boolean(
                                fieldName     => 'muc',
                                printableName => __('Enable MUC (Multi User Chat)'),
                                editable      => 1,
                                defaultValue  => 1,
                               ),
      );

    my $dataTable =
      {
       tableName          => 'GeneralSettings',
       printableTableName => __('General configuration settings'),
       defaultActions     => [ 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataForm',
       messages           => {
                              update => __('General Jabber server configuration settings updated.'),
                             },
       modelDomain        => 'Jabber',
      };

    return $dataTable;
}

1;
