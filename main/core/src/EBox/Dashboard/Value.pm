# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Dashboard::Value;
use base 'EBox::Dashboard::Item';

use EBox::Gettext;

# Constructor: new
#
#     Create a dashboard key:value
#
# Parameters:
#
#      name  - String the key name
#      value - String the value related to that key
#
#      value_type - String the value type to display in the UI accordingly,
#                   it could one of the following values:
#                       good, info, warning, error, ajax
#                   *(Optional)* Default value: info
#
#      ajax_url   - URL of the CGI if value_type == ajax,
#                   the CGI will return a json hash with value and type keys
#                   *(Optional)* (But mandatory if value_type == ajax)
#
# Returns:
#
#      <EBox::Dashboard::Value> - the newly created object instance
#
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new();
    $self->{key} = shift;
    $self->{value} = shift;
    $self->{value_type} = shift;
    $self->{ajax_url} = shift;
    $self->{value_type} = 'info' unless defined($self->{value_type});
    $self->{type} = 'value';
    bless ($self, $class);
    return $self;
}

sub HTMLViewer
{
    return '/dashboard/value.mas';
}

1;
