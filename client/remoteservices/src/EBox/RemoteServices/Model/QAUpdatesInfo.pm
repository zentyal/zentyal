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

# Class: EBox::RemoteServices::Model::QAUpdatesInfo
#
# This class is the model to show information about the server subscriptions
#
#     - QA updates enabled
#     - Latest QA update
#

package EBox::RemoteServices::Model::QAUpdatesInfo;

use strict;
use warnings;

use base 'EBox::Model::DataForm::ReadOnly';

use EBox::Gettext;
use EBox::Global;
use EBox::Types::Text;

# Core modules
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
#     <EBox::RemoteServices::Model::QAUpdatesInfo>
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
           fieldName     => 'enabled',
           printableName => __('QA software updates'),
           ),
       new EBox::Types::Text(
           fieldName     => 'latest_date',
           printableName => __('Latest QA software update'),
          ),
      );

    my $dataForm = {
                    tableName          => 'QAUpdatesInfo',
                    printableTableName => __('QA software updates'),
                    modelDomain        => 'RemoteServices',
                    defaultActions     => [ 'changeView' ],
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


    my ($qaEnabled, $latest) = 
      ( __('Disabled'), __('Disabled') );

    if ( EBox::Global->modExists('software') ) { 
        my $soft = EBox::Global->modInstance('software');
        if ( $soft->QAUpdates() ) {
            $qaEnabled = __('Enabled');
            if ( $soft->can('autoUpgradeStats') ) {
                my $stats = $soft->autoUpgradeStats();
                if ( defined( $stats ) ) {
                    $latest = __x('{date}. {num} updated packages',
                                  date => POSIX::strftime("%c",
                                                          localtime($stats->{timestamp})),
                                  num  => $stats->{packageNum})
                } else {
                    $latest = __('No update has been done');
                }
            } else {
                $latest = __('Unable to get it (Upgrade your software module)');
            }
        }
    } else {
        $qaEnabled = __('Software module is not installed');
    }

    return {
        enabled     => $qaEnabled,
        latest_date => $latest,
       };
}

1;

