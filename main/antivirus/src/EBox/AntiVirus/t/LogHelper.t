# Copyright (C) 2013 Zentyal S.L.
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
use Test::More tests => 9;
use Test::MockObject;
use Test::Exception;
use Test::Differences;

BEGIN {
    diag('A unit test for EBox::AntiVirus::LogHelper');
    use_ok('EBox::AntiVirus::LogHelper')
      or die;
}

my $dbEngine = Test::MockObject->new();
$dbEngine->{lastInsert} = undef;
$dbEngine->mock('insert' => sub { my ($self, $table, $data) = @_;
                                    $self->{table} = $table;
                                    $self->{lastInsert} = $data;
                               });
$dbEngine->mock('_tmLastInsert' => sub { my ($self) = @_;
                                    return $self->{lastInsert};
                               });
$dbEngine->mock('_tmLastInsertTable' => sub { my ($self) = @_;
                                    return $self->{table};
                               });

$dbEngine->mock('_tmClearLastInsert' => sub { my ($self) = @_;
                                    $self->{lastInsert} = undef;
                                    $self->{table}      = undef;
                               });

my @cases = (
    {
        name  => 'Valid AV update',
        lines =>
          [
              "date,1366472429,update,1,error,0,outdated,0",
             ],
        expected => {
            timestamp => '2013-04-20 17:40:29',
            event     => 'success',
            source    => 'freshclam',
        }
       },
    {
        name  => 'Error AV update',
        lines =>
          [
              "date,1366472430,update,0,error,1,outdated,0",
             ],
        expected => {
            timestamp => '2013-04-20 17:40:30',
            event     => 'failure',
            source    => 'freshclam',
        }
       },
    {
        name  => 'No AV update outdated version',
        lines =>
          [
              "date,1366473002,update,0,error,0,outdated,0.97.7",
             ],
        expected => undef,
       },
   );

my $logHelper = new EBox::AntiVirus::LogHelper();
my $file = '/var/lib/clamav/freshclam.state';

foreach my $case (@cases) {
    $dbEngine->_tmClearLastInsert();

    lives_ok {
        local $SIG{__WARN__} = sub { die @_ };  # die on warnings we don't want
                                                # bad interpolation when parsing lines
        foreach my $line (@{$case->{lines}}) {
            $logHelper->processLine($file, $line, $dbEngine);
        }
    } $case->{name};
    if (defined($case->{expected})) {
        is($dbEngine->_tmLastInsertTable(), 'av_db_updates', 'Check last insert table');
    }
    eq_or_diff($dbEngine->_tmLastInsert(), $case->{expected}, 'Check inserted data is the expected one');
}

1;
