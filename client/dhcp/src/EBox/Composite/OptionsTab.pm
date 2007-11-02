# Copyright (C) 2007 Warp Networks S.L.
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

# Class: EBox::DHCP::Composite::OptionsTab
#
#   This class is used to manage dhcp server general options
#   configuration on a given interface. It stores two models for
#   simple options and advanced ones indexed by interface
#
package EBox::DHCP::Composite::OptionsTab;

use base 'EBox::Model::Composite';

use strict;
use warnings;

# eBox uses
use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Constructor: new
#
#         Constructor for the options tab
#
#
# Parameters:
#
#       interface - String the interface attached to do the
#       configuration on the DHCP server
#
#       - Named parameters
#
# Returns:
#
#       <EBox::DHCP:::Model::OptionsTab> - an options tab
#        composite
#
sub new
{

   my ($class, @params) = @_;

   my $self = $class->SUPER::new(@params);

   return $self;

}

# Method: index
#
# Overrides:
#
#     <EBox::Model::Composite::index>
#
sub index
{
    my ($self) = @_;

    return $self->{interface};

}

# Method: printableIndex
#
# Overrides:
#
#     <EBox::Model::Composite::printableIndex>
#
sub printableIndex
{
    my ($self) = @_;

    return __x('interface {iface}',
               iface => $self->{interface});

}


# Group: Protected methods

# Method: _description
#
# Overrides:
#
#     <EBox::Model::Composite::_description>
#
sub _description
{

    my ($self) = @_;

    my $gl = EBox::Global->getInstance();
    my $dhcp = $gl->modInstance('dhcp');

    my $description =
      {
       components      => [
                           '/' . $dhcp->name() . '/Options/' . $self->{interface},
                           '/' . $dhcp->name() . '/AdvancedOptions/' . $self->{interface},
                          ],
       layout          => 'tabbed',
       name            => 'OptionsTab',
       compositeDomain => 'DHCP',
      };

    return $description;

}

1;
