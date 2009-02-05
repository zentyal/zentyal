# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Squid::Types::WeightedPhrasesThreshold;


use strict;
use warnings;

use base 'EBox::Types::Select';


use EBox::Gettext;

sub new
{
    my ($class, %params) = @_;

    if (not exists $params{defaultValue}) {
        $params{defaultValue} = 0;
    }

    if (not exists $params{populate}) {
        $params{populate} =  \&_populateContentFilterThreshold;
    }

    if (not exists $params{help}) {
        $params{help} = _thresholdHelp();
    }


    my $self = $class->SUPER::new(%params);
    bless $self, $class;

    return $self;
}



sub _populateContentFilterThreshold
  {
      return [
      { value => 0, printableValue => __('Disabled'),  },
      { value => 200, printableValue => __('Very permissive'),  },
      { value => 160, printableValue => __('Permissive'),  },
      { value => 120, printableValue => __('Medium'),  },
      { value => 80, printableValue => __('Strict'),  },
      { value => 50, printableValue => __('Very strict'),  },
      ];

  }

sub _thresholdHelp
{
    return __('This specifies how strict the content filter is.');
}


1;
