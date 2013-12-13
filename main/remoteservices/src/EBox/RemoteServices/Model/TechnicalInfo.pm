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

# Class: EBox::RemoteServices::Model::TechnicalInfo
#
# This class is the model to show information about technical support
#
#     - server name
#     - server edition
#     - support via
#     - SLA
#

use strict;
use warnings;

package EBox::RemoteServices::Model::TechnicalInfo;

use base 'EBox::Model::DataForm::ReadOnly';

use v5.10;

use EBox;
use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Types::EBoxCommonName;
use EBox::Types::Text;
use EBox::Types::HTML;
use POSIX;

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
    my $rs = $self->{confmodule};
    if ( $rs->technicalSupport() < 0 ) {
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

    my $rs = $self->{confmodule};

    my ($serverName, $subscription, $supportVia, $sla) =
      (__('None'), __('None'),
       '<span>' . __('None') . '</span>', __('None'));

    if ( $rs->eBoxSubscribed() ) {
        $serverName = $rs->eBoxCommonName();

        $subscription = $rs->i18nServerEdition();

        my $techSupportLevel = $rs->technicalSupport();
        if ( $techSupportLevel >= 0 ) {
            my %i18nVia = ( '0'  => __sx('{oh}On-line Support Platform{ch}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>'),
                            '1'  => __sx('{os}{oh}On-line Support Platform{ch}, Chat and Phone upon request{cs}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>',
                                         os => '<span>',
                                         cs => '</span>'),
                            '2'  => __sx('{os}{oh}On-line Support Platform{ch}, Chat and Phone upon request{cs}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>',
                                         os => '<span>',
                                         cs => '</span>'),
                            '3'  => __sx('{os}{oh}On-line Support Platform{ch}, Chat'
                                         . ', Phone{cs}',
                                         oh => '<a href="https://support.zentyal.com" target="_blank">',
                                         ch => '</a>',
                                         os => '<span>',
                                         cs => '</span>')
                           );
            $supportVia = $i18nVia{$techSupportLevel};

            my %i18nSLA = ('0' => __s('2 Business Days'),
                           '1' => __s('1 Business Day'),
                           '2' => __s('4 hours'),
                           '3' => __s('1 hour'));
            $sla = $i18nSLA{$techSupportLevel};
        }

    }

    return {
        server_name  => $serverName,
        edition      => $subscription,
        support_via  => $supportVia,
        sla          => $sla,
    };
}

# Group: Private methods

sub _message
{
    return __sx('Zentyal is a full-featured Linux server that you can use for free without cloud services, technical support or quality assured updates, or you can get it fully supported for an {oh}affordable monthly fee{ch} through your local Authorized Partner.',
                oh => '<a href="http://www.zentyal.com/smb-editions/" target="_blank">',
                ch => '</a>');
}

1;
