use Test::Tester;
use Test::More tests => 49;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            combined_unlike(sub {
                        print "TEST OUT\n";
                      },
                      qr/out/,
                      'Testing STDOUT'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT not matching success'
          );

check_test( sub {
            combined_unlike(sub {
                        print "TEST OUT\n";
                        print "TEST ERR\n";
                      },
                      qr/err/,
                      'Testing STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'STDERR not matching success'
          );

check_test( sub {
            combined_unlike(sub {
                        print "TEST OUT\n";
                      },
                      'OUT',
                      'Testing STDOUT'
                    )
            },{
              ok => 0,
              depth => 2,
              name => 'combined_unlike',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'bad regex'
          );

check_test( sub {
            combined_unlike(sub {
                        print "TEST OUT\n";
                      },
                      qr/OUT/,
                      'Testing STDOUT'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT',
              diag => "STDOUT & STDERR:\nTEST OUT\n\nmatching:\n(?-xism:OUT)\nnot expected\n",
            },'STDOUT matching failure'
          );

check_test( sub {
            combined_unlike {
                        print "TEST OUT\n";
                      }
                      qr/out/,
                      'Testing STDOUT'
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'codeblock STDOUT not matching success'
          );

check_test( sub {
            combined_unlike {
                        print "TEST OUT\n";
                      }
                      'OUT',
                      'Testing STDOUT'
            },{
              ok => 0,
              depth => 2,
              name => 'combined_unlike',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'codeblock bad regex'
          );

check_test( sub {
            combined_unlike {
                        print "TEST OUT\n";
                      }
                      qr/OUT/,
                      'Testing STDOUT'
            },{
              ok => 0,
              name => 'Testing STDOUT',
              diag => "STDOUT & STDERR:\nTEST OUT\n\nmatching:\n(?-xism:OUT)\nnot expected\n",
            },'codeblock STDOUT matching failure'
          );

