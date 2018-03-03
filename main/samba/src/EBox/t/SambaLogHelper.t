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

package EBox::SambaLogHelper::Test;

use base 'Test::Class';

use Test::Differences;
use Test::Exception;
use Test::MockObject;
use Test::More tests => 7;

sub setUpDBEngine : Test(startup)
{
    my ($self) = @_;

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

    $self->{dbEngine} = $dbEngine;
}

sub test_log_helper_use_ok : Test(startup => 1)
{
    use_ok('EBox::SambaLogHelper') or die;
}

sub setUpLogHelper : Test(setup)
{
    my ($self) = @_;

    $self->{logHelper}  = new EBox::SambaLogHelper();
    $self->{syslogFile} = '/var/log/syslog';
}

sub test_no_insertions_access : Test(4)
{
    my ($self) = @_;

    my @cases = (
        {
            name => 'smbd',
            line => 'Jul  3 08:43:31 elektanss01 smbd[26452]: [2013/07/03 08:43:31.649938,  0] ../source3/smbd/server.c:1280(main)'
           },
        {
            name => '-D option',
            line => 'Jul  3 08:43:31 elektanss01 smbd[26452]:   standard input is not a socket, assuming -D option'
        },
       );

    $self->_testCases($self->{syslogFile}, 'samba_access', \@cases);
}

sub _testCases
{
    my ($self, $file, $table, $cases) = @_;

    foreach my $case (@{$cases}) {
        $self->{dbEngine}->_tmClearLastInsert();
        lives_ok {
            $self->{logHelper}->processLine($file, $case->{line}, $self->{dbEngine});
        } $case->{name};
        if (defined($case->{expected})) {
            is($self->{dbEngine}->_tmLastInsertTable(), $table, 'Check last insert target table');
            eq_or_diff($self->{dbEngine}->_tmLastInsert(),
                       $case->{expected},
                       'Check the last inserted data is the expected one');
        } else {
            use Data::Dumper; print Dumper($self->{dbEngine}->_tmLastInsert());
            is($self->{dbEngine}->_tmLastInsert(), undef, 'No insert was done');
        }
    }
}

1;

END {
    EBox::SambaLogHelper::Test->runtests();
}
