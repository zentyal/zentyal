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

package EBox::IPsec::Model::ConfPhase1;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::View::Customizer;
use EBox::Exceptions::InvalidData;

# Group: Public methods

# Constructor: new
#
#       Create the new ConfPhase1 model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::IPsec::Model::ConfPhase1> - the recently created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless($self, $class);

    return $self;
}

# Method: viewCustomizer
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    my @enableAny = ('ike-keylife');
    my @disableAny = ('ike-auth');
    my @enableOther = ('ike-auth', 'ike-keylife');
    my @disableOther = ();

    $customizer->setOnChangeActions(
            { 'ike-enc' =>
                {
                  'any'    => {
                        enable  => \@enableAny,
                        disable => \@disableAny,
                    },
                  'aes256' => {
                        enable  => \@enableOther,
                        disable => \@disableOther,
                    },
                  '3des' => {
                        enable  => \@enableOther,
                        disable => \@disableOther,
                    },
                }
            });
    return $customizer;
}

# Method: validateTypedRow
#
#      Check the row to add or update if contains a valid configuration.
#
# Overrides:
#
#      <EBox::Model::DataTable::validateTypedRow>
#
# Exceptions:
#
#      <EBox::Exceptions::InvalidData> - thrown if the configuration is not valid.
#
sub validateTypedRow
{
    my ($self, $action, $changedFields, $allFields) = @_;

    if (exists $changedFields->{'ike-auth'}) {
        my $ikeenc;
        if (exists $changedFields->{'ike-enc'}) {
            $ikeenc = $changedFields->{'ike-enc'}->value();
        } else {
            $ikeenc = $allFields->{'ike-enc'}->value();
        }
        if ( $changedFields->{'ike-auth'}->value() eq 'any' and $ikeenc ne 'any') {
            throw EBox::Exceptions::InvalidData(
                'data'  => __('IKE Authentication'),
                'value' => $changedFields->{'ike-auth'}->value(),
            );

        }
    }
}

# Group: Private methods

sub _populateEnc
{
    my @opts = ();
    push (@opts, { value => 'any', printableValue => __('Any') });
    push (@opts, { value => 'aes256', printableValue => 'AES-256' });
    push (@opts, { value => '3des', printableValue => '3DES' });
    return \@opts;
}

sub _populateAuth
{
    my @opts = ();
    push (@opts, { value => 'any', printableValue => __('Any') });
    push (@opts, { value => 'sha1', printableValue => 'SHA-1' });
    push (@opts, { value => 'md5', printableValue => 'MD5' });
    return \@opts;
}

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
         new EBox::Types::Select(
                                   fieldName => 'ike-enc',
                                   printableName => __('IKE Encryption'),
                                   editable => 1,
                                   populate => \&_populateEnc,
                                  ),
         new EBox::Types::Select(
                                   fieldName => 'ike-auth',
                                   printableName => __('IKE Authentication'),
                                   editable => 1,
                                   populate => \&_populateAuth,
                                  ),
         new EBox::Types::Int(
                                   fieldName => 'ike-keylife',
                                   printableName => __('IKE Keylife'),
                                   editable => 1,
                                   defaultValue => 28800,
                                   min => 60,
                                   max => 86400,
                                  ),
        );

    my $dataTable =
    {
        tableName => 'ConfPhase1',
        printableTableName => __('Phase 1'),
        defaultActions => [ 'editField', 'changeView' ],
        tableDescription => \@tableHeader,
        modelDomain => 'IPsec',
    };

    return $dataTable;
}

1;
