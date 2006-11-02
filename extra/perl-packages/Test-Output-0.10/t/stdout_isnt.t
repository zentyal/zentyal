use Test::Tester;
use Test::More tests => 42;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            stdout_isnt(sub {
                        print "TEST OUT\n";
                      },
                      "TEST OUT STDOUT\n",
                      'Testing STDOUT'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT not equal success'
          );

check_test( sub {
            stdout_isnt(sub {
                        printf("TEST OUT - %d\n",42);
                      },
                      "TEST OUT - 25\n",
                      'Testing STDOUT printf'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf not equal success'
          );

check_test( sub {
            stdout_isnt(sub {
                        print "TEST OUT";
                      },
                      "TEST OUT",
                      'Testing STDOUT failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'STDOUT matches failure'
          );

check_test( sub {
            stdout_isnt {
                        print "TEST OUT\n";
                      }
                      "TEST OUT STDOUT\n",
                      'Testing STDOUT'
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT not equal success'
          );

check_test( sub {
            stdout_isnt {
                        printf("TEST OUT - %d\n",42);
                      }
                      "TEST OUT - 25\n",
                      'Testing STDOUT printf'
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf not equal success'
          );

check_test( sub {
            stdout_isnt {
                        print "TEST OUT";
                      }
                      "TEST OUT",
                      'Testing STDOUT failure'
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'STDOUT matches failure'
          );
