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

# Class: EBox::RemoteServices::Model::TechnicalInfo
#
# This class is the model to show information about technical support
#
#     - server name
#     - server subscription
#     - support package
#     - support via
#     - SLA
#

package EBox::RemoteServices::Model::TechnicalInfo;

use strict;
use warnings;

use base 'EBox::Model::DataForm::ReadOnly';

use v5.10;

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Types::EBoxCommonName;
use EBox::Types::Text;
use EBox::Types::HTML;
use POSIX;

# Constants:

use constant STORE_URL => 'http://store.zentyal.com/';
use constant UTM       => '?utm_source=zentyal&utm_medium=ebox&utm_content=remoteservices'
                          . '&utm_campaign=register';
use constant ESSE_URL  => STORE_URL . 'support/support-essential.html' . UTM;
use constant STD_URL   => STORE_URL . 'support/support-standard.html' . UTM;
use constant PREM_URL  => STORE_URL . 'support/support-premium.html' . UTM;
use constant PROF_URL  => STORE_URL . 'serversubscriptions/subscription-professional.html' . UTM;
use constant ENTE_URL  => STORE_URL . 'serversubscriptions/subscription-enterprise.html' . UTM;


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
#     <EBox::RemoteServices::Model::TechnicalInfo>
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
    if ( $rs->technicalSupport() < 0 ) {
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
              fieldName     => 'package',
              printableName => __('Support package'),
             ),
          new EBox::Types::HTML(
              fieldName     => 'support_via',
              printableName => __('Support available via'),
             ),
          new EBox::Types::Text(
              fieldName     => 'sla',
              printableName => __('Service Level Agreement'),
             ),
      );

    my $dataForm = {
                    tableName          => __PACKAGE__->nameFromClass(),
                    printableTableName => __('Technical Support'),
                    modelDomain        => 'RemoteServices',
                    tableDescription   => \@tableDesc,
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

    my ($serverName, $subscription, $package, $supportVia, $sla) =
      (__('None'), __('None'), __('None'),
       '<span>' . __('None') . '</span>', __('None'));

    if ( $rs->eBoxSubscribed() ) {
        $serverName = $rs->eBoxCommonName();

        my %i18nLevels = ( '-1' => __('Unknown'),
                           '0'  => __('Basic'),
                           '1'  => __('Professional'),
                           '2'  => __('Enterprise') );
        $subscription = $i18nLevels{$rs->subscriptionLevel()};

        my %i18nSupport = ( '-2' => __('Unknown'),
                            '-1' => $package,
                            '0'  => __('Essential'),
                            '1'  => __('Standard'),
                            '2'  => __('Premium'));
        my $techSupportLevel = $rs->technicalSupport();
        $package = $i18nSupport{$techSupportLevel};

        if ( $techSupportLevel >= 0 ) {
            my %i18nVia = ( '0'  => __sx('{oh}On-line Support Platform{ch}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>'),
                            '1'  => __sx('{os}{oh}On-line Support Platform{ch}, IRC'
                                         . ', Phone upon request{cs}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>',
                                         os => '<span>',
                                         cs => '</span>'),
                            '2'  => __sx('{os}{oh}On-line Support Platform{ch}, IRC'
                                         . ', Phone{cs}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>',
                                         os => '<span>',
                                         cs => '</span>')
                           );
            $supportVia = $i18nVia{$techSupportLevel};

            my %i18nSLA = ( '0' => __s('Next Business Day'),
                            '1' => __s('4 hours'),
                            '2' => __s('1 hour') );
            $sla = $i18nSLA{$techSupportLevel};
        }

    }

    return {
        server_name  => $serverName,
        subscription => $subscription,
        package      => $package,
        support_via  => $supportVia,
        sla          => $sla,
       };
}

# Group: Private methods

sub _message
{
    return __sx('Get your support directly from the Zentyal Support Team! '
                . 'Three yearly support packages - {ohl}Essential{ch}, '
                . '{ohs}Standard{ch} and {ohm}Premium{ch} - with unlimited '
                . 'number of issues and service delivery times from 1 hour '
                . 'up to next business day, grant you with vendor-level '
                . 'support. To obtain a support package your server must '
                . 'have {ohp}Professional{ch} '
                . 'or {ohe}Enterprise Server Subscription{ch}.',
                ch => '</a>',
                ohl => '<a href="' . ESSE_URL . '" target="_blank">',
                ohs => '<a href="' . STD_URL . '" target="_blank">',
                ohm => '<a href="' . PREM_URL . '" target="_blank">',
                ohp => '<a href="' . PROF_URL . '" target="_blank">',
                ohe => '<a href="' . ENTE_URL . '" target="_blank">');

}


1;

