use Test::Tester;
use Test::More tests => 98;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            combined_isnt(sub {
                        print "TEST OUT\n";
                      },
                      "TEST STDOUT\n",
                      'Testing STDOUT'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT not matching success'
          );

check_test( sub {
            combined_isnt(sub {
                        print STDERR "TEST OUT\n";
                      },
                      "TEST STDERR\n",
                      'Testing STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'STDERR not matching success'
          );

check_test( sub {
            combined_isnt(sub {
                        print "TEST STDOUT\n"; 
                        print STDERR "TEST STDERR\n";
                        print "TEST STDOUT AGAIN\n"; 
                      },
                      "TEST OUT\nTEST ERR\nTEST AGAIN\n",
                      'Testing STDOUT & STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR not matching success'
          );

check_test( sub {
            combined_isnt(sub {
                        printf("TEST OUT - %d\n",25);
                      },
                      "TEST OUT - 42\n",
                      'Testing STDOUT printf'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf not matching success'
          );

check_test( sub {
            combined_isnt(sub {
                        print "TEST OUT";
                      },
                      "TEST OUT",
                      'Testing STDOUT failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT & STDERR:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'STDOUT matching failure'
          );

check_test( sub {
            combined_isnt(sub {
                      print STDERR "TEST OUT"},
                      "TEST OUT",
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT & STDERR:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'STDERR matching failure'
          );

check_test( sub {
            combined_isnt(sub {
                      print "TEST ERR\n";
                      print STDERR "TEST OUT\n"},
                      "TEST ERR\nTEST OUT\n",
                      'Testing STDOUT & STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDOUT & STDERR failure',
              diag => "STDOUT & STDERR:\nTEST ERR\nTEST OUT\n\nmatching:\nTEST ERR\nTEST OUT\n\nnot expected\n",
            },'STDOUT and STDERR matching failure'
          );

check_test( sub {
            combined_isnt {
                        print "TEST OUT\n";
                      }
                      "TEST STDOUT\n",
                      'Testing STDOUT'
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'codeblock STDOUT not matching success'
          );

check_test( sub {
            combined_isnt {
                        print STDERR "TEST OUT\n";
                      }
                      "TEST STDERR\n",
                      'Testing STDERR'
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'codeblock STDERR not matching success'
          );

check_test( sub {
            combined_isnt {
                        print "TEST STDOUT\n"; 
                        print STDERR "TEST STDERR\n";
                        print "TEST STDOUT AGAIN\n"; 
                      }
                      "TEST OUT\nTEST ERR\nTEST OUT AGAIN\n",
                      'Testing STDOUT & STDERR'
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'codeblock STDOUT & STDERR not matching success'
          );

check_test( sub {
            combined_isnt {
                        printf("TEST OUT - %d\n",25);
                      }
                      "TEST OUT - 42\n",
                      'Testing STDOUT printf'
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'codeblock STDOUT printf not matching success'
          );

check_test( sub {
            combined_isnt {
                        print "TEST OUT";
                      }
                      "TEST OUT",
                      'Testing STDOUT failure'
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT & STDERR:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'codeblock STDOUT matching failure'
          );

check_test( sub {
            combined_isnt {
                      print STDERR "TEST OUT"}
                      "TEST OUT",
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT & STDERR:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'codeblock STDERR not matching failure'
          );

check_test( sub {
            combined_isnt {
                      print "TEST ERR\n";
                      print STDERR "TEST OUT\n"}
                      "TEST ERR\nTEST OUT\n",
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT & STDERR:\nTEST ERR\nTEST OUT\n\nmatching:\nTEST ERR\nTEST OUT\n\nnot expected\n",
            },'codeblock STDOUT and STDERR matching failure'
          );

