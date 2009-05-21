# Copyright (C) 2009 eBox Technologies
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


package EBox::Network::Composite::MultiGw;
use base 'EBox::Model::Composite';

## eBox uses
use EBox::Gettext;
use EBox::Global;

# Group: Public methods

# Constructor: new
#
#         Constructor for the general byte rate composite
#
# Returns:

sub new
  {

      my ($class, @params) = @_;

      my $self = $class->SUPER::new(@params);

      return $self;

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

      my $description =
        {
         components      => [
                             'MultiGwRulesOptions',
                             'MultiGwRulesDataTable',
                            ],
         layout          => 'top-bottom',
         printableName   => __('Multi gateway'),
         compositeDomain => 'Network',
         name            => 'MultiGw',
#         help            => __(''),
        };

      return $description;

  }


sub precondition
{
    my $network = EBox::Global->modInstance('network');
    my $nGateways = @{$network->gateways()};
    return $nGateways >= 2;
}

sub preconditionFailMsg
{
return   __('To be able to use this feature, you need, at least, two gateways. You can add them <a href="/ebox/Network/View/GatewayTable">here</a> first');
}

1;
