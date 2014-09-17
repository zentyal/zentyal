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

package EBox::IPsec::Model::ConfPhase2;

use base 'EBox::Model::DataForm';

use EBox::Gettext;
use EBox::Types::Int;
use EBox::Types::Select;
use EBox::Types::Boolean;
use EBox::Exceptions::InvalidData;

# Group: Public methods

# Constructor: new
#
#       Create the new ConfPhase2 model
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::IPsec::Model::ConfPhase2> - the recently created model
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

    my @enableAny = ('phase2-keylife');
    my @disableAny = ('phase2-auth', 'phase2-dhgroup');
    my @enableOther = ('phase2-auth', 'phase2-dhgroup', 'phase2-keylife');
    my @disableOther = ();

    $customizer->setOnChangeActions(
            { 'phase2-enc' =>
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

    if (exists $changedFields->{'phase2-auth'}) {
        my $espenc;
        if (exists $changedFields->{'phase2-enc'}) {
            $espenc = $changedFields->{'phase2-enc'}->value();
        } else {
            $espenc = $allFields->{'phase2-enc'}->value();
        }
        if ( $changedFields->{'phase2-auth'}->value() eq 'any' and $espenc ne 'any') {
            throw EBox::Exceptions::InvalidData(
                'data'  => __('ESP Authentication'),
                'value' => $changedFields->{'phase2-auth'}->value(),
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

sub _populateDHGroup
{
    my @opts = ();
    push (@opts, { value => 'modp1024', printableValue => '2' });
    push (@opts, { value => 'modp1536', printableValue => '5' });
    push (@opts, { value => 'modp2048', printableValue => '14' });
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
                                   fieldName => 'phase2-enc',
                                   printableName => __('ESP Encryption'),
                                   editable => 1,
                                   populate => \&_populateEnc,
                                  ),
         new EBox::Types::Select(
                                   fieldName => 'phase2-auth',
                                   printableName => __('ESP Authentication'),
                                   editable => 1,
                                   populate => \&_populateAuth,
                                  ),
         new EBox::Types::Select(
                                   fieldName => 'phase2-dhgroup',
                                   printableName => __('ESP DH Group'),
                                   editable => 1,
                                   populate => \&_populateDHGroup,
                                  ),
         new EBox::Types::Int(
                                   fieldName => 'phase2-keylife',
                                   printableName => __('ESP Keylife'),
                                   editable => 1,
                                   defaultValue => 3600,
                                   min => 60,
                                   max => 86400,
                                  ),
         new EBox::Types::Boolean(
                                   fieldName => 'pfs',
                                   printableName => __('Enable PFS'),
                                   editable => 1,
                                   defaultValue => 1,
                                  ),
        );

    my $dataTable =
    {
        tableName => 'ConfPhase2',
        printableTableName => __('Phase 2'),
        defaultActions => [ 'editField', 'changeView' ],
        tableDescription => \@tableHeader,
        modelDomain => 'IPsec',
    };

    return $dataTable;
}

1;
