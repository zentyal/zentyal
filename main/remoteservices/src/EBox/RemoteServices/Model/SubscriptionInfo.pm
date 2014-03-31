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

use v5.10;

# Class: EBox::RemoteServices::Model::SubscriptionInfo
#
# This class is the model to show information about the server edition
#
#     - server name
#     - server edition
#     - zentyal.me name
#     - subscription renovation date
#     - ad messages, if apply
#

package EBox::RemoteServices::Model::SubscriptionInfo;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;
use EBox::Types::HTML;

# Core modules
use TryCatch::Lite;
use POSIX;

use constant STORE_URL => 'http://store.zentyal.com/';
use constant UTM       => '?utm_source=zentyal&utm_medium=ebox&utm_content=remoteservices'
                          . '&utm_campaign=register';
use constant BASIC_URL  => STORE_URL . 'serversubscriptions/subscription-basic.html' . UTM;

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
#     <EBox::RemoteServices::Model::SubscriptionInfo>
#
sub new
{

    my $class = shift;
    my %opts = @_;
    my $self = $class->SUPER::new(@_);
    bless ( $self, $class);

    return $self;

}

# Method: headTitle
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
sub headTitle
{
    return undef;
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
       new EBox::Types::Text(
           fieldName     => 'server_name',
           printableName => __('Server name'),
          ),
       new EBox::Types::HTML(
           fieldName     => 'edition',
           printableName => __('Server edition'),
           ),
       new EBox::Types::Text(
           fieldName     => 'external_server_name',
           printableName => __('External server name (Dynamic DNS)'),
           help          => __('Use this name to connect to Zentyal externally'),
          ),
       new EBox::Types::Text(
           fieldName     => 'renovation_date',
           printableName => __('Renovation date'),
          ),
       new EBox::Types::Text(
           fieldName => 'messages',
           printableName => __('Messages')
          ),
      );

    my $dataForm = {
                    tableName          => 'SubscriptionInfo',
                    printableTableName => __('Server info'),
                    defaultActions     => [ 'changeView' ],
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

    my ($serverName, $fqdn, $subs, $renovationDate, $msg) =
      ( __('None'), __('Not using Zentyal Dynamic DNS service'),
        __sx('<span>None - {oh}Register for Free!{ch}</span>',
             oh => '<a href="/Wizard?page=RemoteServices/Wizard/Subscription">',
             ch  => '</a>'),
        __('None'), __('None'));

    if ( $rs->eBoxSubscribed() ) {
        $serverName = $rs->eBoxCommonName();

        my $net = EBox::Global->getInstance(1)->modInstance('network');
        if ( $net->can('DDNSUsingCloud') and $net->DDNSUsingCloud() ) {
            $fqdn = $rs->dynamicHostname();
        }

        $subs = '<span>' . $rs->i18nServerEdition() . '</span>';

        $renovationDate = $rs->renovationDate();
        given ($renovationDate) {
            when (-1) { $renovationDate = __('Unknown'); }
            when (0)  { $renovationDate = __('Unlimited'); }
            default {
                $renovationDate = POSIX::strftime("%c", localtime($renovationDate));
            }
        }
    }
    if ($rs->adMessages()->{text}) {
        $msg = $rs->adMessages()->{text};
    }

    return {
        server_name          => $serverName ,
        external_server_name => $fqdn,
        edition              => $subs,
        renovation_date      => $renovationDate,
        messages             => $msg,
       };
}

1;

