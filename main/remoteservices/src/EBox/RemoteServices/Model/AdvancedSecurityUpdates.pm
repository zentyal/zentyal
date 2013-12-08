# Copyright (C) 2011-2012 Zentyal S.L.
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

# Class: EBox::RemoteServices::Model::AdvancedSecurityUpdates
#
# This class is the model to show information about advanced security updates
#
#     - server name
#     - server edition
#     - asu
#     - latest security update
#

package EBox::RemoteServices::Model::AdvancedSecurityUpdates;

use strict;
use warnings;

use base 'EBox::Model::DataForm::ReadOnly';

use v5.10;

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Types::EBoxCommonName;
use EBox::Types::Int;
use EBox::Types::Text;
use POSIX;

# Constants:

use constant STORE_URL => 'http://store.zentyal.com/';
use constant SB_URL  => STORE_URL . 'small-business-edition/?utm_source=zentyal&utm_medium=security_updates&utm_campaign=smallbusiness_edition';
use constant ENT_URL   => STORE_URL . 'enterprise-edition/?utm_source=zentyal&utm_medium=security_updates&utm_campaign=enterprise_edition';

# Group: Public methods

# Constructor: new
#
#     Create the subscription form
#
# Overrides:
#
#     <EBox::Model::DataForm::new>
#
# Returns:
#
#     <EBox::RemoteServices::Model::AdvancedSecurityUpdates>
#
sub new
{

    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class);

    return $self;

}
# Method: viewCustomizer
#
#      Return a custom view customizer to set a permanent message if
#      the technical support is not purchased
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
    my $rs = $self->{confmodule};
    unless ( $rs->securityUpdatesAddOn() ) {
        $customizer->setPermanentMessage(_message(), 'ad');
    }
    return $customizer;
}

# Group: Protected methods

# Method: _table
#
# Overrides:
#
#     <EBox::Model::DataForm::_table>
#
sub _table
{
    my ($self) = @_;

    my @tableDesc =
      (
          new EBox::RemoteServices::Types::EBoxCommonName(
              fieldName     => 'server_name',
              printableName => __('Server name'),
             ),
          new EBox::Types::Text(
              fieldName     => 'edition',
              printableName => __('Server edition'),
             ),
          new EBox::Types::Text(
              fieldName     => 'asu',
              printableName => __('Security Updates'),
             ),
          new EBox::Types::Text(
              fieldName     => 'latest',
              printableName => __('Latest security update'),
             ),
      );

    my $global = EBox::Global->getInstance(1);
    if ( $global->modExists('ids') ) {
        push(@tableDesc,
             new EBox::Types::Int(
                 fieldName     => 'available_ids_rules',
                 printableName => __('Available IDS rules'),
                 min           => -1,
                ));
    }

    my $dataForm = {
                    tableName        => __PACKAGE__->nameFromClass(),
                    pageTitle        => __('Security Updates'),
                    modelDomain      => 'RemoteServices',
                    tableDescription => \@tableDesc,
                };

    return $dataForm;
}

# Method: _content
#
# Overrides:
#
#    <EBox::Model::DataForm::ReadOnly::_content>
#
sub _content
{
    my ($self) = @_;

    my $rs = $self->parentModule();

    my ($serverName, $subscription, $asu, $latest) =
      (__('None'), __('None'), __('Disabled'), __('None'));

    if ( $rs->eBoxSubscribed() ) {
        $serverName = $rs->eBoxCommonName();

        $subscription = $rs->i18nServerEdition();

        my $asuEnabled = $rs->securityUpdatesAddOn();
        if ( $asuEnabled ) {
            $asu = __('Enabled');

            $latest = $rs->latestSecurityUpdates();
            $latest = __('Unknown') if ( $latest eq 'unknown' );
        }

    }

    my $retData = {
        server_name => $serverName,
        edition     => $subscription,
        asu         => $asu,
        latest      => $latest,
    };

    # Optional fields depending on the installed modules
    my $global = EBox::Global->getInstance(1);
    if ( $global->modExists('ids') ) {
        my $ids = $global->modInstance('ids');
        if ( $ids->can('rulesNum') ) {
            my $rules = $ids->rulesNum(1);
            $retData->{available_ids_rules} = $rules;
        } else {
            # Upgrade to zentyal-ids 2.2.1 onwards
            $retData->{available_ids_rules} = -1;
        }
    }

    return $retData;
}

# Group: Private methods

sub _message
{
    return __sx('Want to offer enterprise-level security for your organization? Get the {ohs}Small Business{ch} or {ohe}Enterprise Edition{ch}: both include automatic security updates so you can stop worrying about the Antivirus, Antispam, IDS and the Content Filtering System.',
                ch => '</a>',
                ohs => '<a href="' . SB_URL . '" target="_blank">',
                ohe => '<a href="' . ENT_URL . '" target="_blank">');
}

1;
