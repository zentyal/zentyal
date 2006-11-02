use Test::Tester;
use Test::More tests => 98;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            combined_is(sub {
                        print "TEST OUT\n";
                      },
                      "TEST OUT\n",
                      'Testing STDOUT'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT matches success'
          );

check_test( sub {
            combined_is(sub {
                        print STDERR "TEST OUT\n";
                      },
                      "TEST OUT\n",
                      'Testing STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'STDERR matches success'
          );

check_test( sub {
            combined_is(sub {
                        print "TEST OUT\n"; 
                        print STDERR "TEST ERR\n";
                        print "TEST AGAIN\n"; 
                      },
                      "TEST OUT\nTEST ERR\nTEST AGAIN\n",
                      'Testing STDOUT & STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR match success'
          );

check_test( sub {
            combined_is(sub {
                        printf("TEST OUT - %d\n",25);
                      },
                      "TEST OUT - 25\n",
                      'Testing STDOUT printf'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf match success'
          );

check_test( sub {
            combined_is(sub {
                        print "TEST OUT";
                      },
                      "TEST OUT STDOUT",
                      'Testing STDOUT failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT & STDERR are:\nTEST OUT\nnot:\nTEST OUT STDOUT\nas expected\n",
            },'STDOUT not matching failure'
          );

check_test( sub {
            combined_is(sub {
                      print STDERR "TEST OUT"},
                      "TEST OUT STDERR",
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT & STDERR are:\nTEST OUT\nnot:\nTEST OUT STDERR\nas expected\n",
            },'STDERR not matching failure'
          );

check_test( sub {
            combined_is(sub {
                      print "TEST ERR\n";
                      print STDERR "TEST OUT\n"},
                      "TEST ERR STDOUT\nTEST OUT STDERR\n",
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT & STDERR are:\nTEST ERR\nTEST OUT\n\nnot:\nTEST ERR STDOUT\nTEST OUT STDERR\n\nas expected\n",
            },'STDOUT and STDERR not matching failure'
          );

check_test( sub {
            combined_is {
                        print "TEST OUT\n";
                      }
                      "TEST OUT\n",
                      'Testing STDOUT'
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'codeblock STDOUT matches success'
          );

check_test( sub {
            combined_is {
                        print STDERR "TEST OUT\n";
                      }
                      "TEST OUT\n",
                      'Testing STDERR'
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'STDERR matches success'
          );

check_test( sub {
            combined_is {
                        print "TEST OUT\n"; 
                        print STDERR "TEST ERR\n";
                        print "TEST OUT AGAIN\n"; 
                      }
                      "TEST OUT\nTEST ERR\nTEST OUT AGAIN\n",
                      'Testing STDOUT & STDERR'
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR match success'
          );

check_test( sub {
            combined_is {
                        printf("TEST OUT - %d\n",25);
                      }
                      "TEST OUT - 25\n",
                      'Testing STDOUT printf'
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf match success'
          );

check_test( sub {
            combined_is {
                        print "TEST OUT";
                      }
                      "TEST OUT STDOUT",
                      'Testing STDOUT failure'
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT & STDERR are:\nTEST OUT\nnot:\nTEST OUT STDOUT\nas expected\n",
            },'STDOUT not matching failure'
          );

check_test( sub {
            combined_is {
                      print STDERR "TEST OUT"}
                      "TEST OUT STDERR",
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT & STDERR are:\nTEST OUT\nnot:\nTEST OUT STDERR\nas expected\n",
            },'STDERR not matching failure'
          );

check_test( sub {
            combined_is {
                      print "TEST ERR\n";
                      print STDERR "TEST OUT\n"}
                      "TEST ERR STDOUT\nTEST OUT STDERR\n",
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT & STDERR are:\nTEST ERR\nTEST OUT\n\nnot:\nTEST ERR STDOUT\nTEST OUT STDERR\n\nas expected\n",
            },'STDOUT and STDERR not matching failure'
          );

