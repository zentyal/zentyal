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

# Script:
#
#     This script tests the correct functionality from eBox. This
#     assumes eBox module is correctly installed in the first eBox
#     joined to this control center.
#

use Test::More qw(no_plan);
use Test::Exception;
use Data::Dumper;

BEGIN {
    use_ok ('EBox::ControlCenter::RemoteEBoxProxy' );
}

# Firstly get the list of eBoxes joined to the control center

my $eBoxes_ref;
lives_ok
  {
      $eBoxes_ref = EBox::ControlCenter::RemoteEBoxProxy->ListNames();
  } 'Getting the eBox list';

cmp_ok ( scalar(@{$eBoxes_ref}) , '>=', 1, 'There are at least an eBox' );
print 'The current list of eBoxes are: ' . join (', ', @{$eBoxes_ref}) . $/;

my ($remEBox, $remEBoxRO);
lives_ok
  {
      $remEBox = EBox::ControlCenter::RemoteEBoxProxy->GetEBoxByName($eBoxes_ref->[1]);
      # Get a read only
      $remEBoxRO = EBox::ControlCenter::RemoteEBoxProxy->GetEBoxByName($eBoxes_ref->[1], 1);
  } 'Getting an eBox';

isa_ok ($remEBox, 'EBox::ControlCenter::RemoteEBoxProxy');
isa_ok ($remEBoxRO, 'EBox::ControlCenter::RemoteEBoxProxy');

is ( $remEBox->isReadOnly(), undef, 'Not a read-only proxy');
ok ( $remEBoxRO->isReadOnly(), 'A read-only proxy');

is ( $remEBox->modExists('foobar'), undef, 'Asking for an inexistant module');
ok ( $remEBoxRO->modExists('sysinfo'), 'Asking for a real module');

my ($mods_ref, $modsRO_ref);
lives_ok
  {
      $mods_ref = $remEBox->modNames();
      $modsRO_ref = $remEBoxRO->modNames();
  } 'Getting the module names';

is_deeply ( $mods_ref, $modsRO_ref, 'Equal modules in rw and ro proxy instances');

throws_ok
  {
      $remEBox->modMethod('logs', 'foobar');
  } 'EBox::Exceptions::External', 'The method called does not exist';

throws_ok
  {
      $remEBox->modMethod('foobar', 'baz');
  } 'EBox::Exceptions::External', 'The module is not defined';

throws_ok
  {
      $remEBox->modMethod('ca', 'getCertificateMetadata');
  } 'EBox::Exceptions::Base', 'An exception launched by an eBox module';

lives_ok
  {
      print Dumper($remEBox->modMethod('logs', 'search',
                                        (
                                         '2007-6-20 2:22:0',
                                         '2007-6-22 2:22:0',
                                         'squid',
                                         15,
                                         0,
                                         'timestamp',
                                         undef
                                        )
                                      )
                  ) . '\n';
      print Dumper($remEBox->modMethod('ca', 'getCertificateMetadata', (cn => 'stc2')));
#      print Dumper($remEBox->testDebug());
  } 'Calling a right method from an standard module';


