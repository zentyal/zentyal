# Copyright (C) 2010-2013 Zentyal S.L.
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

package EBox::Zarafa::Model::Quota;

use base 'EBox::Model::DataForm';

# Class: EBox::Zarafa::Model::Quota
#
#   Form to set the general configuration settings for the Zarafa server.
#

use EBox::Gettext;
use EBox::Types::Int;
use EBox::Types::Union;
use EBox::Types::Union::Text;

# Group: Public methods

# Constructor: new
#
#       Create the new Quota model.
#
# Overrides:
#
#       <EBox::Model::DataForm::new>
#
# Returns:
#
#       <EBox::Zarafa::Model::Quota> - the recently
#       created model.
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless ( $self, $class );

    return $self;
}

# Group: Protected methods

# Method: _table
#
#       The table description.
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader =
      (
       new EBox::Types::Union(
                              fieldName => 'mailboxQuota',
                              printableName =>
                                  __('Maximum mailbox size'),
                              help =>
                                  __('When a mailbox reaches this size futher messages will be rejected.'),
                              subtypes => [
                              new EBox::Types::Union::Text(
                                  'fieldName' => 'mailboxUnlimited',
                                  'printableName' => __('Unlimited size'),
                                  ),
                              new EBox::Types::Int(
                                  'fieldName' => 'mailboxSize',
                                  'printableName' => __('Limited to'),
                                  'trailingText'  => 'MB',
                                  'editable'  => 1,
                                  'min'       => 1,
                                  'size'      => 5,
                                  ),
                              ],
                             ),
       new EBox::Types::Int(
                              fieldName => 'warnQuota',
                              printableName =>
                                  __('Warn user over'),
                              #help => __(''),
                              trailingText => '% quota.',
                              editable => 1,
                              defaultValue => 80,
                              min => 0,
                              max => 99,
                              size => 2,
                             ),
       new EBox::Types::Int(
                              fieldName => 'softQuota',
                              printableName =>
                                  __('Stop user sending mails over'),
                              #help => __(''),
                              trailingText => '% quota.',
                              editable => 1,
                              defaultValue => 95,
                              min => 0,
                              max => 99,
                              size => 2,
                             ),
      );

    my $dataTable =
      {
       tableName          => 'Quota',
       printableTableName => __('Quota configuration settings'),
       defaultActions     => [ 'editField', 'changeView' ],
       tableDescription   => \@tableHeader,
       class              => 'dataForm',
       messages           => {
                              update => __('Zarafa server quota configuration settings updated.'),
                             },
       modelDomain        => 'Zarafa',
      };

    return $dataTable;
}

sub hardQuota
{
    my ($self) = @_;

    my $mailboxQuota = $self->row()->elementByName('mailboxQuota');
    if ($mailboxQuota->selectedType eq 'mailboxUnlimited') {
        # 0 means unlimited
        return 0;
    }

    my $size = $mailboxQuota->subtype()->value();
    return $size;
}

sub warnQuota
{
    my ($self) = @_;

    my $warn = $self->warnQuotaValue();

    my $warnQuota = $self->hardQuota * $warn / 100;

    return int($warnQuota);
}

sub softQuota
{
    my ($self) = @_;

    my $soft = $self->softQuotaValue();

    my $softQuota = $self->hardQuota * $soft / 100;

    return int($softQuota);
}

1;
