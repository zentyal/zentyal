# Copyright (C) 2011-2013 Zentyal S.L.
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

package EBox::Asterisk::Model::Phones;

use base 'EBox::Model::DataTable';

# Class: EBox::Asterisk::Model::Phones
#
#      Form to set the configuration settings for static phones.
#

use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Password;
use EBox::Types::MailAddress;

use EBox::Asterisk::Extensions;

# Group: Public methods

# Constructor: new
#
#       Create the new Phones model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Asterisk::Model::Phones> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

sub getPhones
{
    my ($self) = @_;

    my @phones = ();

    foreach my $id (@{$self->enabledRows()}) {

        my $row = $self->row($id);

        my %phone = ();

        my $exten = $row->valueByName('exten');
        $phone{'exten'} = $exten;
        $phone{'secret'} = $row->valueByName('secret');
        $phone{'vmail'} = $row->valueByName('vmail');
        $phone{'mail'} = $row->valueByName('mail');
        $phone{'desc'} = $row->valueByName('desc');
        push (@phones, \%phone);

    }

    return \@phones;
}

# Group: Private methods

# Method: _table
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{

    my @tableHeader =
      (
       new EBox::Types::Int(
                            fieldName     => 'exten',
                            printableName => __('Extension'),
                            size          => 4,
                            unique        => 1,
                            editable      => 1,
                            optional      => 0,
                            help          => __x('A number between {min} and {max}.',
                                                 min => EBox::Config::configkey('asterisk_phone_min_extn'),
                                                 max => EBox::Config::configkey('asterisk_phone_max_extn'),
                                                ),
                           ),
       new EBox::Types::Password(
                                 fieldName     => 'secret',
                                 printableName => __('Password'),
                                 size          => 12,
                                 unique        => 0,
                                 editable      => 1,
                                 optional      => 0,
                                 minLength     => 6,
                                 maxLength     => 12,
                                ),
       new EBox::Types::Int(
                            fieldName     => 'vmail',
                            printableName => __('Voicemail'),
                            size          => 4,
                            unique        => 0,
                            editable      => 1,
                            optional      => 0,
                            help          => __('Voicemail extension to forward missed calls.'),
                           ),
       new EBox::Types::MailAddress(
                             fieldName     => 'mail',
                             printableName => __('Email notified'),
                             size          => 32,
                             unique        => 0,
                             editable      => 1,
                             optional      => 1,
                            ),
       new EBox::Types::Text(
                             fieldName     => 'desc',
                             printableName => __('Description'),
                             size          => 24,
                             unique        => 0,
                             editable      => 1,
                             optional      => 1,
                            ),
      );

    my $dataTable =
    {
        tableName          => 'Phones',
        printableTableName => __('List of Phones'),
        pageTitle          => __('Phones'),
        printableRowName   => __('phone'),
        defaultActions     => [ 'add', 'del', 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        help               => __("VoIP phones connected to the server."),
        sortedBy           => 'exten',
        modelDomain        => 'Asterisk',
        enableProperty => 1,
        defaultEnabledValue => 1,
    };

    return $dataTable;
}

1;
