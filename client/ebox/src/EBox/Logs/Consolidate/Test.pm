package EBox::Logs::Consolidate::Test;

use strict;
use warnings;

use base 'EBox::Test::Class';

use EBox::Test;

use Perl6::Junction qw(any all);

use Test::Exception;
use Test::More;
use Test::MockObject;

use Data::Dumper;

use lib '../../..';

use EBox::Logs::Consolidate;
use EBox::TestStubs;

sub weeklyDateTest #: Test(6)
{
    my %cases = (
                 "2008-01-02 13:42:12" => "2007-12-31 00:00:00", # year leap
                 "2008-03-01 12:12:00" => "2008-2-25 00:00:00", # month leap
                 "2008-02-17 12:12:00" => "2008-2-11 00:00:00", # sunday  
                 "2008-02-18 12:12:00" => "2008-2-18 00:00:00", # monday
                 "2008-02-27 12:12:00" => "2008-2-25 00:00:00", # thursday
                 "2008-02-29 12:12:00" => "2008-2-25 00:00:00", # friday
                );

    while (my ($timeStamp, $expectedDate) = each %cases) {
        my $date = EBox::Logs::Consolidate->_weeklyDate($timeStamp);
        is $date, $expectedDate,
            "checking weekly date for time stam $timeStamp";
    }

}



# XXX DELETE operation is not tested


my %tableInfoByMod;

sub fakeTableInfoFromMod
{
    my ($self, $modName) = @_;
    return $tableInfoByMod{$modName};
}

sub setFakeTableInfoForMod
{
    my ($modName, $tableInfo) = @_;
    $tableInfoByMod{$modName} = $tableInfo;
}


sub fakeConsolidate : Test(startup)
{
    Test::MockObject->fake_module(
                                  'EBox::Logs::Consolidate',
                                  _tableInfoFromMod => \&fakeTableInfoFromMod,
                                  _sourceRows => \&fakeSourceRows,
                                  _cleanRows => sub {},

                                  # we donot test last consolidation dates for
                                  # now
                                 _lastConsolidationDate => sub {  return undef },
                                  _updateLastConsolidationDate => sub {   },

                                 );

}

sub fakeDBEngineFactory : Test(startup)
{
    Test::MockObject->fake_module(
                                  'EBox::DBEngineFactory',
                                    DBEngine => \&fakeDBEngine,
                                 );

}



my %fakeDB = ();
my $dbengine;


sub fakeDBEngine
{
    if ($dbengine) {
        return $dbengine;
    }


    $dbengine = Test::MockObject->new();
    $dbengine->mock('insert' => sub {
                        my ($self, $table, $row) = @_;
                        
                        if (not exists $fakeDB{$table}) {
                            $fakeDB{$table} = [];
                        }

                        
                        push @{ $fakeDB{$table} },  $row; 
                    }
                   );
    $dbengine->mock('do' => sub {
                        my ($self, $query) = @_;
                        
                        if (not $query =~ /^UPDATE/) {
                            if ($query =~ /^DELETE/) {
                                return;
                            }

                            die "Not mocked query $query";
                        }

                        $query =~ m/UPDATE\s+(.*?)\s+SET\s+(.*)\s+WHERE/;
                        my $table = $1;
                        my $setPortion = $2;

                        if (not exists $fakeDB{$table}) {
                            # table is empty, not update
                            return 0;
                        }


                        my %accummulator;
                        foreach my $part (split ',', $setPortion) {
                            $part =~ m/= (.*) \+ (.*)/;
                            my ($col, $inc) = ($1, $2);
                            $accummulator{$col} = $inc;
                        }



                        $query =~ s/^UPDATE.*WHERE.*\(//;
                        $query =~ s/\).*$//;
                     
                        
                        my %row;

                        foreach my $pair (split ' AND ', $query) {
                            my ($name, $v) = split ' = ', $pair;
                            $v =~ s/^\'//g;
                            $v =~ s/'$//g;
                            $row{$name} = $v;
                        }

                        my $updated = 0;

                        foreach my $row_r (@{ $fakeDB{$table} }) {
                            my %dbRow = %{ $row_r  };

                            my $notSame = 0;
                            while (my ($key, $value) = each %row) {
                                my $v = delete $dbRow{$key};

                                if ((not defined $v) or  ($v ne $value)) {
                                    $notSame = 1;
                                    keys %row; # to reset  internal counter
                                    last;
                                }
                            }

                            if ($notSame) {
                                next;
                            }

                            while (my ($col, $inc) = each %accummulator) {
                                $row_r->{$col} += $inc;
                            }

                            $updated += 1;
                        }


                        return $updated;
                    }
                   );


    return $dbengine;
}



sub fakeSourceRows
{
    my ($self, $dbengine, $table, $dateCol) = @_;


    return $fakeDB{$table};
}


sub setFakeDB
{
    my ($table, $columns_r,) = @_;

    %fakeDB = (
               $table => $columns_r
             );
}




# Method : modNameAndClass
#
#   must be overriden return the modName and class of the module tested.
#   default: returns undef, that means to use default values for a general test
sub modNameAndClass
{
    return (undef, undef);
}


sub _setupDB
{
    my ($self, $dbRows_r, $consolidate) = @_;


    my ($modName, $modClass) =  $self->modNameAndClass();
    if (not defined $modName) {
        $modName =  'testMod';
        EBox::TestStubs::fakeEBoxModule(
                                       name => $modName,
                                       subs => [
                                                isEnabled => sub { return 1  },
                                                tableInfo => sub {
                                                    my ($mock) = @_;
                                                    return
                                                      $self->fakeTableInfoFromMod($mock->name);

                                                }
#                                                name => sub {  return $modName },
                                               ],
                                        isa => ['EBox::LogObserver'],
                                      );
    }



    my $tableInfo;

    if (defined $modClass) {
        $tableInfo = $modClass->tableInfo();
    }
    else {
#        my %titles =  map {  $_ => $_ } @{ $dbColumns_r };
        my %titles = ();

  
        $tableInfo = {
                     name => $modName,
                     index => $modName,

                     titles => \%titles,
                     order => [  keys %titles ],
                     
                     tablename => 'testTable',

                     timecol => 'date',
                     filter => [],
                      
                     events => { eventOne => 'eventOne', eventTwo => 'eventTwo'},
                     eventcol => 'event',

                     consolidate => $consolidate, 
                      
                     };
    }
    
    my @dbRows    = @{ $dbRows_r };


    setFakeDB($tableInfo->{tablename}, \@dbRows);

    setFakeTableInfoForMod($modName => $tableInfo);
}




sub _standardDbContent
{
    return   [
              {
               date => '2008-08-24 13:12:36', 
               event => 'eventOne',
               sender => 'bee@insects.com',
               recipient => 'macaco@monos.org',
               size => 321,
              },
              { date => '2008-08-24 13:21:36',
                event => 'eventTwo',
                sender => 'bee@insects.com',
                recipient => 'macaco@monos.org',
                size => 341,
              },
              { date => '2008-08-24 13:21:36',
                event => 'eventTwo',
                sender => 'snake@reptiles.net',
                recipient => 'macaco@monos.org', 
                size => 21,
              },
              { date => '2008-08-24 14:21:12',
                event => 'eventOne',
                sender => 'wasp@insects.com',
                recipient => 'macaco@monos.org', 
                size => 521,
              },
              { date => '2008-08-24 19:12:36',
                event => 'eventOne',
                sender => 'bee@insects.com',
                recipient => 'macaco@monos.org', 
                size => 821,
              },
                                
              { date => '2008-08-25 13:12:36',
                event => 'eventOne',
                sender => 'bee@insects.com',
                recipient => 'macaco@monos.org', 
                size => 121,
              },
                                
              { date => '2008-08-26 19:12:36',
                event => 'eventOne',
                sender => 'bee@insects.com',
                recipient => 'macaco@monos.org', 
                size => 321,
              },
              { date => '2008-08-26 20:12:36',
                event => 'eventOne',
                sender => 'bee@insects.com',
                recipient => 'mandrill@monos.org', 
                size => 721,
              },
              { date => '2008-08-26 20:12:36',
                event => 'eventOne',
                sender => 'bee@insects.com',
                recipient => 'macaco@monos.org', 
                size => 121,
              },
             ];

}

#  Method: consolidateTest
#
# override in client cases to provide a different test count!
# it needs only to call runCases to run the tests
sub consolidateTest : Test(32)
{
    my ($self) = @_;
    $self->runCases();
}







sub runCases
{
    my ($self) = @_;
    
    my $cases = $self->cases();

    foreach my $case_r (@{ $cases }) {
        $self->_checkConsolidate($case_r);
    }

}

sub _checkConsolidate 
{
     my ($self, $case) = @_;


     diag $case->{name};

    $self->_setupDB(
             $case->{dbRows},
             $case->{consolidate}
            );


     my ($modName) = $self->modNameAndClass();
     defined $modName or
         $modName = 'testMod';

    lives_ok {
        EBox::Logs::Consolidate->consolidate($modName);
    } 'consolidate method does not raise any error';

    my $dbEngine = fakeDBEngine();
    $dbEngine->called_ok('insert');
    $dbEngine->called_ok('do');


     my @expectedRows = @{ $case->{expectedConsolidatedRows} };
     my %expectedTables;
     foreach  ( @expectedRows ) {
         my $table = $_->{table};
         $expectedTables{$table} = 1;
     }




    my @dbRows;
     foreach my $table (keys %expectedTables) {
         if (not exists $fakeDB{$table}) {
             die "Expected table was not existent: $table";
         }

         foreach my $row  (@{ $fakeDB{$table}  }  ) {
             push @dbRows, {  table => $table, value => $row, };
         }

     }

     use Data::Dumper;
#     diag Dumper \@dbRows;


    is_deeply(
                _rowsToCompare(\@dbRows),
                _rowsToCompare(\@expectedRows),
                'Checking database rows'
               );


    $dbEngine->clear();
    $dbEngine->{rows} = [];
}


sub _rowsToCompare
{
    my ($rows_r) = @_;

    my %rtc = map {
        my @val = ($_->{table}, sort values %{ $_->{value} } );
        my $valStr = join '-', @val;
        
        ($valStr => $_)
    } @{ $rows_r };

    return \%rtc;
}


#   Method: cases
#
#  Provides runCases with cases to run
# override in client classes to provide other cases
sub cases
{
    my @cases = (
                 {
                  name => 'simple case',
                  dbColumns =>  [qw(date event sender recipient comments)],
                  dbRows =>    [
                                { 
                                 date => '2008-08-24 13:12:36', 
                                 event => 'eventOne', 
                                 sender => 'bee@insects.com', 
                                 recipient => 'macaco@monos.org', 
                                 comments => '11faas sfa aa4 ge eqf efw4 w',
                                },
                                { 
                                 date => '2008-08-24 13:21:36', 
                                 event => 'eventTwo', 
                                 sender => 'bee@insects.com', 
                                 recipient => 'macaco@monos.org', 
                                 comments => '222faas sfa aa4 ge eqf efw4 w',
                                },
                                { 
                                 date => '2008-08-24 14:21:12',
                                 event => 'eventOne',
                                 sender => 'wasp@insects.com',
                                 recipient => 'macaco@monos.org', 
                                 comments => '33faas sfa aa4 ge eqf efw4 w',
                                },
                                { 
                                 date => '2008-08-24 19:12:36',
                                 event => 'eventOne',
                                 sender => 'bee@insects.com', 
                                 recipient => 'macaco@monos.org', 
                                 comments => '444faas sfa aa4 ge eqf efw4 w',
                                },
                                
                                {
                                 date => '2008-08-25 13:12:36', 
                                 event => 'eventOne', 
                                 sender => 'bee@insects.com', 
                                 recipient => 'macaco@monos.org', 
                                 comments => '55faas sfa aa4 ge eqf efw4 w',
                                },
                                { 
                                  date => '2008-08-26 19:12:36',
                                  event => 'eventOne',
                                  sender => 'bee@insects.com',
                                  recipient => 'macaco@monos.org',
                                  comments => '666faas sfa aa4 ge eqf efw4 w',
                                },
                                { 
                                 date => '2008-08-26 20:12:36',
                                 event => 'eventOne',
                                 sender => 'bee@insects.com',
                                 recipient => 'madrill@monos.org',
                                 comments => '777faas sfa aa4 ge eqf efw4 w',
                                },
                                { 
                                 date => '2008-08-26 20:12:36',
                                 event => 'eventOne',
                                 sender => 'bee@insects.com',
                                 recipient => 'macaco@monos.org',
                                  comments => '888faas sfa aa4 ge eqf efw4 w',
                                },
                               ],
                  consolidate => {
                                  testTable => {
                                                consolidateColumns => {
                                                                       event => 1,
                                                                       sender => 1,
                                                                      },
                                               },
                                 },
                  expectedConsolidatedRows => [
                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          event => 'eventOne',
                                                          sender => 'bee@insects.com',
                                                          count => 2,
                                                         },

                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          event => 'eventTwo',
                                                          sender => 'bee@insects.com',
                                                          count => 1,
                                                         },
                           
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          event => 'eventOne',
                                                           sender => 'wasp@insects.com',
                                                          count => 1,
                                                         },
                                               },


                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          event => 'eventOne',
                                                          sender => 'bee@insects.com',
                                                          count => 1,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          event => 'eventOne',
                                                          sender => 'bee@insects.com',
                                                          count => 3,
                                                         },
                                               },
                                              ]
                 },
                 # end case

                {
                  name => 'case with a method to consolidate sender',
                  dbColumns =>  [qw(date event sender recipient comments)],
                  dbRows =>    [
                                {
                                 date => '2008-08-24 13:12:36', 
                                 event => 'eventOne',
                                 sender => 'bee@insects.com',
                                 recipient => 'macaco@monos.org',
                                 comments => '11faas sfa aa4 ge eqf efw4 w'
                                },
                                { date => '2008-08-24 13:21:36',
                                 event => 'eventTwo',
                                 sender => 'bee@insects.com',
                                 recipient => 'macaco@monos.org',
                                 comments => '222faas sfa aa4 ge eqf efw4 w'
                                },
                                { date => '2008-08-24 13:21:36',
                                  event => 'eventTwo',
                                  sender => 'snake@reptiles.net',
                                  recipient => 'macaco@monos.org', 
                                  comments => '222faas sfa aa4 ge eqf efw4 w'
                                },
                                { date => '2008-08-24 14:21:12',
                                  event => 'eventOne',
                                  sender => 'wasp@insects.com',
                                  recipient => 'macaco@monos.org', 
                                  comments => '33faas sfa aa4 ge eqf efw4 w'
                                },
                                { date => '2008-08-24 19:12:36',
                                  event => 'eventOne',
                                  sender => 'bee@insects.com',
                                  recipient => 'macaco@monos.org', 
                                  comments => '444faas sfa aa4 ge eqf efw4 w'
                                },
                                
                                { date => '2008-08-25 13:12:36',
                                  event => 'eventOne',
                                  sender => 'bee@insects.com',
                                  recipient => 'macaco@monos.org', 
                                  comments => '55faas sfa aa4 ge eqf efw4 w'
                                },
                                
                                { date => '2008-08-26 19:12:36',
                                  event => 'eventOne',
                                  sender => 'bee@insects.com',
                                  recipient => 'macaco@monos.org', 
                                  comments => '666faas sfa aa4 ge eqf efw4 w'
                                },
                                { date => '2008-08-26 20:12:36',
                                  event => 'eventOne',
                                  sender => 'bee@insects.com',
                                  recipient => 'madrill@monos.org', 
                                  comments => '777faas sfa aa4 ge eqf efw4 w'
                                },
                                { date => '2008-08-26 20:12:36',
                                  event => 'eventOne',
                                  sender => 'bee@insects.com',
                                  recipient => 'macaco@monos.org', 
                                  comments => '888faas sfa aa4 ge eqf efw4 w'
                                },
                               ],
                   consolidate => {
                                   testTable => {
                                                 consolidateColumns => {
                                                          event => 1,
                                                          sender => sub {
                                                              my ($value) = @_;
                                                              my ($addr, $domain) = split '@', $value;
                                                              return $domain;
                                                              
                                                          },
                                                         },
                                                },
                                  },
                  expectedConsolidatedRows => [
                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          event => 'eventOne',
                                                          sender => 'insects.com',
                                                                 count => 3,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          event => 'eventTwo',
                                                          sender => 'insects.com',
                                                                 count => 1,
                                                         },
                           
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          event => 'eventTwo',
                                                          sender => 'reptiles.net',
                                                                 count => 1,
                                                         },
                           
                                               },


                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          event => 'eventOne',
                                                          sender => 'insects.com',
                                                                 count => 1,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          event => 'eventOne',
                                                          sender => 'insects.com',
                                                                 count => 3,
                                                         },
                                               },
                                              ]
                 },
#                 end case


                {
                  name => 'case with accumulation (size by sender)',
                  dbColumns =>  [qw(date event sender recipient size)],
                  dbRows =>  _standardDbContent(),
                 
                 consolidate => {
                                 testTable => {
                                        accummulateColumns => {'size' => 0 },
                                         consolidateColumns => {
                                                        sender => 1,
                                                        size => {
                                                                 accummulate => 'size',
                                                                }
                                                       },
                                              },
                                },
                  expectedConsolidatedRows => [
                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 1483,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'wasp@insects.com',
                                                          size => 521,
                                                         },
                           
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'snake@reptiles.net',
                                                          size => 21,
                                                         },
                           
                                               },


                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 121,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 1163,
                                                         },
                                               },
                                              ]
                 },
#                 end case

                {
                  name => 'case with two accumulation (n messages and size by sender)',
                  dbColumns =>  [qw(date event sender recipient size)],
                  dbRows =>  _standardDbContent(),
                 
                 consolidate => {
                                 testTable => {
                                        accummulateColumns => {
                                                               'size' => 0,
                                                              'messages' => 1,
                                                              },
                                         consolidateColumns => {
                                                        sender => 1,
                                                        size => {
                                                                 accummulate => 'size',
                                                                }
                                                       },
                                              },
                                },
                  expectedConsolidatedRows => [
                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 1483,
                                                          messages => 3,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'wasp@insects.com',
                                                          size => 521,
                                                          messages => 1,
                                                         },
                           
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'snake@reptiles.net',
                                                          size => 21,
                                                          messages => 1,
                                                         },
                           
                                               },


                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 121,
                                                          messages => 1,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 1163,
                                                          messages => 3,
                                                         },
                                               },
                                              ]
                 },
#                 end case


               {
                  name => 'case with filtered out rows',
                  dbColumns =>  [qw(date event sender recipient size)],
                  dbRows =>  _standardDbContent(),
                 
                 consolidate => {
                                 testTable => {
                                       filter => sub {
                                         my ($row_r) = @_;
                                         return $row_r->{event} eq 'eventOne',
                                     },
                                     consolidateColumns => {
                                                            sender => 1,
                                                           },
                                              }
                                },
                  expectedConsolidatedRows => [
                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          count => 2,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'wasp@insects.com',
                                                          count => 1,
                                                         },
                           
                                               },




                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          count => 1,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          count => 3,
                                                         },
                                               },
                                              ]
                 },
#                 end case


                {
                  name => 'case with two tables',
                  dbColumns =>  [qw(date event sender recipient size)],
                  dbRows =>  _standardDbContent(),
                 
                 consolidate => {
                                 senderTable => {
                                      consolidateColumns => {
                                                            sender => 1,
                                                           },
                                              },
                                 recipientTable => {
                                      consolidateColumns => {
                                                            recipient => 1,
                                                           },
                                              },
                                },
                  expectedConsolidatedRows => [
                                               {
                                                table => 'senderTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          count => 3,
                                                         },
                                               },

                                               {
                                                table => 'senderTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'wasp@insects.com',
                                                          count => 1,
                                                         },
                           
                                               },

                                               {
                                                table => 'senderTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'snake@reptiles.net',
                                                          count => 1,
                                                         },
                                               },


                                               {
                                                table => 'recipientTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          recipient => 'macaco@monos.org',
                                                          count => 5,
                                                         },
                                               },


                                               {
                                                table => 'senderTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          count => 1,
                                                         },
                                               },

                                               {
                                                table => 'recipientTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          recipient => 'macaco@monos.org',
                                                          count => 1,
                                                         },
                                               },

                                               {
                                                table => 'senderTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          count => 3,
                                                         },
                                               },

                                               {
                                                table => 'recipientTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          recipient => 'macaco@monos.org',
                                                          count => 2,
                                                         },
                                               },


                                               {
                                                table => 'recipientTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          recipient => 'mandrill@monos.org',
                                                          count => 1,
                                                         },
                                               },

                                              ]
                 },
#                 end case
                 
                 {
                  name => 'case with two accumulation from the same columnn',
                  dbColumns =>  [qw(date event sender recipient size)],
                  dbRows =>  _standardDbContent(),
                 
                 consolidate => {
                                 testTable => {
                                        accummulateColumns => {
                                                               'eventOne' => 0,
                                                              'eventTwo' => 0,
                                                              },
                                         consolidateColumns => {
                                                        event => {
                                                                  conversor => sub {
                                                                      return 1;
                                                                  },
                                                                 accummulate => 
                                                                 sub {
                                                                     my ($v) = @_;
                                                                     return $v;

                                                                 },
                                                                }
                                                       },
                                              },
                                },
                  expectedConsolidatedRows => [
                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          eventOne => 3,
                                                          eventTwo => 2,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          eventOne => 1,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          eventOne => 3,
                                                         },
                                               },

                                              ],
                 },
#                 end case


                {
                  name => 'case with hourly consolodation and daily reconsolidation',
                  dbColumns =>  [qw(date event sender recipient size)],
                  dbRows =>  _standardDbContent(),
                 
                 consolidate => {
                                 testTable => {
                                         timePeriods => ['hourly', 'daily'],
                                        accummulateColumns => {'size' => 0 },
                                         consolidateColumns => {
                                                        sender => 1,
                                                        size => {
                                                                 accummulate => 'size',
                                                                }
                                                       },
                                              },
                                },
                  expectedConsolidatedRows => [
                                               # hourly table
                                               {
                                                table => 'testTable_hourly',
                                                value => {
                                                          date => '2008-08-24 13:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 662,
                                                         },
                                               },
                                               {
                                                table => 'testTable_hourly',
                                                value => {
                                                          date => '2008-08-24 19:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 821,
                                                         },
                                               },
                                               {
                                                table => 'testTable_hourly',
                                                value => {
                                                          date => '2008-08-24 13:00:00',
                                                          sender => 'snake@reptiles.net',
                                                          size => 21,
                                                         },
                                               },
                                               {
                                                table => 'testTable_hourly',
                                                value => {
                                                          date => '2008-08-24 14:00:00',
                                                          sender => 'wasp@insects.com',
                                                          size => 521,
                                                         },
                                               },
                                               {
                                                table => 'testTable_hourly',
                                                value => {
                                                          date => '2008-08-25 13:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 121,
                                                         },
                                               },
                                               {
                                                table => 'testTable_hourly',
                                                value => {
                                                          date => '2008-08-26 19:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 321,
                                                         },
                                               },
                                               {
                                                table => 'testTable_hourly',
                                                value => {
                                                          date => '2008-08-26 20:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 842,
                                                         },
                                               },


                                                # daily table
                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 1483,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'wasp@insects.com',
                                                          size => 521,
                                                         },
                           
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-24 00:00:00',
                                                          sender => 'snake@reptiles.net',
                                                          size => 21,
                                                         },
                           
                                               },


                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-25 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 121,
                                                         },
                                               },

                                               {
                                                table => 'testTable_daily',
                                                value => {
                                                          date => '2008-08-26 00:00:00',
                                                          sender => 'bee@insects.com',
                                                          size => 1163,
                                                         },
                                               },
                                              ]
                 },
#                 end case

                );


    return \@cases;
}


1;
