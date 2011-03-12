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

# Class: EBox::RemoteServices::Model::SubscriptionInfo
#
# This class is the model to show information about the server subscriptions
#
#     - server name
#     - server subscription
#     - subscription renovation date
#     - Central Monitoring & management
#

package EBox::RemoteServices::Model::SubscriptionInfo;

use strict;
use warnings;

use v5.10;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox::Gettext;
use EBox::Global;
use EBox::RemoteServices::Types::EBoxCommonName;
use EBox::Types::Text;
use EBox::Types::HTML;

# Core modules
use Error qw(:try);
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
       new EBox::RemoteServices::Types::EBoxCommonName(
           fieldName     => 'server_name',
           printableName => __('Server name'),
          ),
       new EBox::Types::HTML(
           fieldName     => 'subscription',
           printableName => __('Server subscription'),
           ),
       new EBox::Types::Text(
           fieldName     => 'renovation_date',
           printableName => __('Subscription renovation date'),
          ),
       new EBox::Types::Text(
           fieldName     => 'mm',
           printableName => __('Central monitoring & management'),
          ),
      );

    my $dataForm = {
                    tableName          => 'SubscriptionInfo',
                    printableTableName => __('Server subcription info'),
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

    my $rs = $self->{gconfmodule};

    my ($serverName, $subs, $renovationDate, $mm) =
      ( __('None'),
        __sx('<span>None - {ohb}Get Free Basic Subscription{ch}</span>',
             ohb => '<a href="' . BASIC_URL . '" target="_blank">',
             ch  => '</a>'),
        __('None'), __('Disabled'));

    if ( $rs->eBoxSubscribed() ) {
        $serverName = $rs->eBoxCommonName();

        my %i18nLevels = ( '-1' => __('Unknown'),
                           '0'  => __('Basic'),
                           '1'  => __('Professional'),
                           '2'  => __('Enterprise') );
        $subs = '<span>' . $i18nLevels{$rs->subscriptionLevel()} . '</span>';

        $renovationDate = $rs->renovationDate();
        given ($renovationDate) {
            when (-1) { $renovationDate = __('Unknown'); }
            when (0)  { $renovationDate = __('Unlimited'); }
            default {
                $renovationDate = POSIX::strftime("%c", localtime($renovationDate));
            }
        }

        $mm = __('Enabled') if ($rs->subscriptionLevel() >= 2);
    }

    return {
        server_name     => $serverName ,
        subscription    => $subs,
        renovation_date => $renovationDate,
        mm              => $mm,
       };
}

1;

