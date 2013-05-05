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

# Class:
#
#   <EBox::DNS::Model::Settings>
#
#   This class inherits from <EBox::Model::DataForm> and represents
#   the form which consists of general settings for DNS
#   server. The fields are the following ones:
#
#      - transparent
#
use strict;
use warnings;

package EBox::DNS::Model::Settings;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;

use EBox::Types::Boolean;

# Group: Public methods

# Constructor: new
#
#      Create a new Text model instance
#
# Returns:
#
#      <EBox::DNS::Model::Settings> - the newly created model
#      instance
#
sub new
{
    my ($class, %params) = @_;

    my $self = $class->SUPER::new(%params);
    bless($self, $class);

    return $self;
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
          new EBox::Types::Boolean(
              fieldName     => 'transparent',
              printableName => __('Enable transparent DNS cache'),
              editable      => \&isFWEnabled,
              unique        => 1,
             ),
      );

    my $dataTable =
        {
            tableName => 'Settings',
            printableTableName => __('Settings'),
            modelDomain     => 'DNS',
            defaultActions => [ 'editField',  'changeView' ],
            tableDescription => \@tableDesc,
            messages => { update => __('Settings changed') },
            help     => __('Every DNS query will be redirected to local '
                         . 'DNS server if transparent mode is enabled.'),
        };

    return $dataTable;
}

sub isFWEnabled
{
    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    my $fwEnabled = 0;
    if ($gl->modExists('firewall')) {
        $fwEnabled = $gl->modInstance('firewall')->isEnabled();
    }
    return $fwEnabled;
}

1;
