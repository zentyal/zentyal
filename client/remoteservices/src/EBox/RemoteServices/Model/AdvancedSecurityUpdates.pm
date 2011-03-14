# Copyright (C) 2011 eBox Technologies S.L.
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
#     - server subscription
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
use EBox::Types::Text;
use POSIX;

# Constants:

use constant STORE_URL => 'http://store.zentyal.com/';
use constant UTM       => '?utm_source=zentyal&utm_medium=ebox&utm_content=remoteservices'
                          . '&utm_campaign=register';

use constant ASU_URL  => STORE_URL . 'other/advanced-security.html' . UTM;
use constant PROF_URL => STORE_URL . 'serversubscriptions/subscription-professional.html' . UTM;
use constant ENTE_URL => STORE_URL . 'serversubscriptions/subscription-enterprise.html' . UTM;


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
    my $rs = $self->{gconfmodule};
    unless ( $rs->securityUpdatesAddOn() ) {
        $customizer->setPermanentMessage(_message());
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
              fieldName     => 'subscription',
              printableName => __('Server subscription'),
             ),
          new EBox::Types::Text(
              fieldName     => 'asu',
              printableName => __('Advanced Security Updates'),
             ),
          new EBox::Types::Text(
              fieldName     => 'latest',
              printableName => __('Latest security update'),
             ),
      );

    my $dataForm = {
                    tableName        => __PACKAGE__->nameFromClass(),
                    pageTitle        => __('Advanced Security Updates'),
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

    my $rs = $self->{gconfmodule};

    my ($serverName, $subscription, $asu, $latest) =
      (__('None'), __('None'), __('Disabled'), __('None'));

    if ( $rs->eBoxSubscribed() ) {
        $serverName = $rs->eBoxCommonName();

        my %i18nLevels = ( '-1' => __('Unknown'),
                           '0'  => __('Basic'),
                           '1'  => __('Professional'),
                           '2'  => __('Enterprise') );
        $subscription = $i18nLevels{$rs->subscriptionLevel()};

        my $asuEnabled = $rs->securityUpdatesAddOn();
        if ( $asuEnabled ) {
            $asu = __('Enabled');

            $latest = $rs->latestSecurityUpdates();
            $latest = __('Unknown') if ( $latest eq 'unknown' );
        }

    }

    return {
        server_name  => $serverName,
        subscription => $subscription,
        asu          => $asu,
        latest       => $latest,
       };
}

# Group: Private methods

sub _message
{
    return __sx('Enterprise-level security for your network! The '
                . '{oha}Advanced Security Updates{ch} guarantee that the '
                . 'content filtering lists, IDS threat analysis ruleset, '
                . 'Antivirus signatures and Antispam detection rules in your '
                . 'Zentyal servers are verified daily by the most trusted IT '
                . 'experts. To obtain these updates, your server must have '
                . '{ohp}Professional{ch} or '
                . '{ohe}Enterprise Server Subscription{ch}.',
                ch => '</a>',
                oha => '<a href="' . ASU_URL . '" target="_blank">',
                ohp => '<a href="' . PROF_URL . '" target="_blank">',
                ohe => '<a href="' . ENTE_URL . '" target="_blank">');

}


1;

