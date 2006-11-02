use Test::Tester;
use Test::More tests => 28;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            stderr_isnt(sub {
                        print STDERR "TEST OUT\n";
                      },
                      "TEST OUT STDERR\n",
                      'Testing STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'STDERR not equal success'
          );

check_test( sub {
            stderr_isnt(sub {
                        print STDERR "TEST OUT\n";
                      },
                      "TEST OUT\n",
                      'Testing STDERR'
                    )
            },{
              ok => 0,
              name => 'Testing STDERR',
              diag => "STDERR:\nTEST OUT\n\nmatches:\nTEST OUT\n\nnot expected\n",
            },'STDERR matches failure'
          );

check_test( sub {
            stderr_isnt {
                        print STDERR "TEST OUT\n";
                      }
                      "TEST OUT STDERR\n",
                      'Testing STDERR'
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'STDERR not equal success'
          );

check_test( sub {
            stderr_isnt {
                        print STDERR "TEST OUT\n";
                      }
                      "TEST OUT\n",
                      'Testing STDERR'
            },{
              ok => 0,
              name => 'Testing STDERR',
              diag => "STDERR:\nTEST OUT\n\nmatches:\nTEST OUT\n\nnot expected\n",
            },'STDERR matches failure'
          );
