use Test::Tester;
use Test::More tests => 42;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            stdout_like(sub {
                        print "TEST OUT\n";
                      },
                      qr/OUT/i,
                      'Testing STDOUT'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT matching success'
          );

check_test( sub {
            stdout_like(sub {
                        print "TEST OUT\n";
                      },
                      'OUT',
                      'Testing STDOUT'
                    )
            },{
              ok => 0,
              depth => 2,
              name => 'stdout_like',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'bad regex'
          );

check_test( sub {
            stdout_like(sub {
                        print "TEST OUT\n";
                      },
                      qr/out/,
                      'Testing STDOUT'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT',
              diag => "STDOUT:\nTEST OUT\n\ndoesn't match:\n(?-xism:out)\nas expected\n",
            },'STDOUT not matching failure'
          );

check_test( sub {
            stdout_like {
                        print "TEST OUT\n";
                      }
                      qr/OUT/i,
                      'Testing STDOUT'
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT matching success'
          );

check_test( sub {
            stdout_like {
                        print "TEST OUT\n";
                      }
                      'OUT',
                      'Testing STDOUT'
            },{
              ok => 0,
              depth => 2,
              name => 'stdout_like',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'bad regex'
          );

check_test( sub {
            stdout_like {
                        print "TEST OUT\n";
                      }
                      qr/out/,
                      'Testing STDOUT'
            },{
              ok => 0,
              name => 'Testing STDOUT',
              diag => "STDOUT:\nTEST OUT\n\ndoesn't match:\n(?-xism:out)\nas expected\n",
            },'STDOUT not matching failure'
          );

