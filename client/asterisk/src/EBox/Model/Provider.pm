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


package EBox::Asterisk::Model::Provider;

# Class: EBox::Asterisk::Model::Provider
#
#      Form to set the configuration for the SIP provider.
#

use base 'EBox::Model::DataForm';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::Password;
use EBox::Types::Host;
use EBox::View::Customizer;

use EBox::Asterisk;

# Group: Public methods

# Constructor: new
#
#      Create the new Provider model.
#
# Overrides:
#
#      <EBox::Model::DataForm::new>
#
# Returns:
#
#      <EBox::Asterisk::Model::Provider> - the recently created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}


sub providers
{
      my @providers;
      push @providers, { 'value' => 'custom', printableValue => 'Custom' };
      push @providers, { 'value' => 'ebox', printableValue => 'eBox VoIP Credit' };
      return \@providers;
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
       new EBox::Types::Select(
                                fieldName     => 'provider',
                                printableName => __('Provider'),
                                populate      => \&providers,
                                editable      => 1,
                               ),
       new EBox::Types::Text(
                                fieldName     => 'name',
                                printableName => __('Name'),
                                size          => 12,
                                unique        => 1,
                                editable      => 1,
                                defaultValue  => EBox::Asterisk->EBOX_VOIP_SRVNAME,
                                help          => __('VoIP service provider name.'),
                               ),
       new EBox::Types::Text(
                                fieldName     => 'username',
                                printableName => __('Username'),
                                size          => 12,
                                unique        => 1,
                                editable      => 1,
                               ),
       new EBox::Types::Password(
                                fieldName     => 'password',
                                printableName => __('Password'),
                                size          => 12,
                                unique        => 1,
                                editable      => 1,
                               ),
       new EBox::Types::Host(
                                fieldName     => 'server',
                                printableName => __('Server'),
                                size          => 12,
                                unique        => 1,
                                editable      => 1,
                                defaultValue  => EBox::Asterisk->EBOX_SIP_SERVER,
                               ),
       new EBox::Types::Text(
                                fieldName     => 'incoming',
                                printableName => __('Recipient of incoming calls'),
                                size          => 12,
                                unique        => 1,
                                editable      => 1,
                                help          => __('Extension recipient of incoming calls through the provider.'),
                               ),
      );

    my $dataTable =
    {
        tableName          => 'Provider',
        printableTableName => __('SIP provider'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataForm',
        help               => __('SIP provider for outgoing calls configuration.'),
        messages           => {
                                  update => __('SIP provider configuration updated.')
                              },
        modelDomain        => 'Asterisk',
    };

    return $dataTable;

}


# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer> to implement
#   a custom behaviour to enable and disable fields
#   depending on the 'provider' value
#
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    # Be careful: password should be always the first item if there are more
    # as we remove it using shift later
    my @enableEbox= ('incoming', 'password', 'username');
    my @disableEbox= ('server', 'name');
    my @enableCustom = ('incoming', 'server', 'password', 'username', 'name');
    my @disableCustom = ();

    $customizer->setOnChangeActions(
            { provider =>
                {
                  'ebox'    => {
                        enable  => \@enableEbox,
                        disable => \@disableEbox,
                    },
                  'custom' => {
                        enable  => \@enableCustom,
                        disable => \@disableCustom,
                    },
                }
            });
    $customizer->setPermanentMessage(_message());
    return $customizer;
}


sub _message
{
    my $voipmsg =  __x(
        'eBox VoIP Credit: make low-cost VoIP calls to mobile phones and ' .
        'landlines directly with eBox. Purchase the VoIP credit you need directly ' .
        'at the {ohref}eBox on-line store{chref}! ',
         ohref => '<a href="http://store.ebox-technologies.com/">',
         chref => '</a>'
    );
    return $voipmsg;
}

1;
