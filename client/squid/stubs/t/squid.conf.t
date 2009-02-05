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



#

use strict;
use warnings;

use lib '../../src';

use Test::More qw(no_plan);

use EBox::Test::Mason;

my @cases = (
             [
              'port',
              3128,
              'transparent',
              'no',
              'policy',
              'auth',
              'groupsPolicies',
              [],
              'objectsPolicies',
              [
               {
                'object' => 'obje4936',
                'addresses' => [
                                '192.168.9.0/24'
                               ],
                'time' => 'MTWHFAS',
                'policy' => 'authAndFilter',
                'groupsPolicies' => []
               },
               {
                'object' => 'obje8929',
                'addresses' => [
                                '192.168.9.0/24'
                               ],
                'time' => 'MTWHFAS',
                'policy' => 'deny',
                'groupsPolicies' => []
               }
              ],
              'memory',
              '100',
              'notCachedDomains',
              []
             ],

             [
              'port',
              3128,
              'transparent',
              'no',
              'policy',
              'filter',
              'groupsPolicies',
              [],
              'objectsPolicies',
              [
               {
                'object' => 'obje4936',
                'addresses' => [
                                '192.168.9.0/24'
                               ],
                'time' => 'MTWHFAS',
                'policy' => 'allow',
                'groupsPolicies' => []
               },
               {
                'object' => 'obje8929',
                'addresses' => [
                                '192.168.9.0/24'
                               ],
                'time' => 'MTWHFAS',
                'policy' => 'deny',
                'groupsPolicies' => []
               }
              ],
              'memory',
              '100',
              'notCachedDomains',
              []

             ],

             [
              'port',
              3128,
              'transparent',
              'no',
              'policy',
              'allow',
              'groupsPolicies',
              [],
              'objectsPolicies',
              [
               {
                'object' => 'obje9564',
                'addresses' => [
                                '192.168.9.0/24',
                                '192.168.45.0/24'
                               ],
                'policy' => 'allow',
                'groupsPolicies' => [
                                     {
                                      'timeDays' => 'MTWHAS',
                                      'group' => 'monos',
                                      'policy' => 'allow',
                                      'users' => [
                                                  'macaco',
                                                  'gibon'
                                                 ]
                                     }
                                    ]
               },
               {
                'object' => 'obje8845',
                'addresses' => [
                                '192.168.10.0/24'
                               ],
                'policy' => 'auth',
                'groupsPolicies' => [
                                     {
                                      'group' => 'insects',
                                      'policy' => 'allow',
                                      'users' => [
                                                  'bee'
                                                 ]
                                     }
                                    ]
               }
              ],
              'memory',
              '100',
              'notCachedDomains',
              []
             ],
            );


my $template = '../squid.conf.mas';
foreach my $case (@cases) {
    EBox::Test::Mason::checkTemplateExecution(
                              template => $template,
                              templateParams => $case
                                             );
 
}


1;
