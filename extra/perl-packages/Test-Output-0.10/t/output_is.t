use Test::Tester;
use Test::More tests => 168;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            output_is(sub {
                        print "TEST OUT\n";
                      },
                      "TEST OUT\n",
                      '',
                      'Testing STDOUT'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT matches success'
          );

check_test( sub {
            output_is(sub {
                        print STDERR "TEST OUT\n";
                      },
                      '',
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
            output_is(sub {
                        print "TEST OUT\n"; 
                        print STDERR "TEST ERR\n";
                      },
                      "TEST OUT\n",
                      "TEST ERR\n",
                      'Testing STDOUT & STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR match success'
          );

check_test( sub {
            output_is(sub {
                        printf("TEST OUT - %d\n",25);
                      },
                      "TEST OUT - 25\n",
                      '',
                      'Testing STDOUT printf'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf match success'
          );

check_test( sub {
            output_is(sub {
                        print "TEST OUT";
                      },
                      "TEST OUT STDOUT",
                      '',
                      'Testing STDOUT failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT is:\nTEST OUT\nnot:\nTEST OUT STDOUT\nas expected\n",
            },'STDOUT not matching failure'
          );

check_test( sub {
            output_is(sub {
                      print STDERR "TEST OUT"},
                      '',
                      "TEST OUT STDERR",
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDERR is:\nTEST OUT\nnot:\nTEST OUT STDERR\nas expected\n",
            },'STDERR not matching failure'
          );

check_test( sub {
            output_is(sub {
                      print "TEST ERR";
                      print STDERR "TEST OUT"},
                      'TEST ERR STDOUT',
                      "TEST OUT STDERR",
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT is:\nTEST ERR\nnot:\nTEST ERR STDOUT\nas expected\nSTDERR is:\nTEST OUT\nnot:\nTEST OUT STDERR\nas expected\n",
            },'STDOUT and STDERR not matching failure'
          );

check_test( sub {
            output_is(sub {
                        print "TEST OUT\n"; 
                        print STDERR "TEST ERR\n";
                      },
                      undef,
                      "TEST ERR\n",
                      'Testing STDOUT & STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT undef match success'
          );

check_test( sub {
            output_is(sub {
                        print "TEST OUT\n"; 
                        print STDERR "TEST ERR\n";
                      },
                      "TEST OUT\n",
                      undef,
                      'Testing STDOUT & STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT match success STDERR undef'
          );

check_test( sub {
            output_is(sub {
                      },
                      undef,
                      undef,
                      'Testing STDOUT & STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR undef match success'
          );

check_test( sub {
            output_is(sub {
                      print "TEST ERR";
                      print STDERR "TEST OUT"},
                      undef,
                      undef,
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT is:\nTEST ERR\nnot:\n\nas expected\nSTDERR is:\nTEST OUT\nnot:\n\nas expected\n",
            },'STDOUT and STDERR not matching failure'
          );

check_test( sub {
            output_is(sub {
                      print STDERR "TEST OUT"},
                      undef,
                      undef,
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDERR is:\nTEST OUT\nnot:\n\nas expected\n",
            },'STDOUT undef and STDERR not matching failure'
          );

check_test( sub {
            output_is {
                        print "TEST OUT\n";
                      }
                      "TEST OUT\n",
                      '',
                      'Testing STDOUT'
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT matches success'
          );

check_test( sub {
            output_is {
                        print STDERR "TEST OUT\n";
                      }
                      '',
                      "TEST OUT\n",
                      'Testing STDERR'
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'STDERR matches success'
          );

check_test( sub {
            output_is {
                        print "TEST OUT\n"; 
                        print STDERR "TEST ERR\n";
                      }
                      "TEST OUT\n",
                      "TEST ERR\n",
                      'Testing STDOUT & STDERR'
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR match success'
          );

check_test( sub {
            output_is {
                        printf("TEST OUT - %d\n",25);
                      }
                      "TEST OUT - 25\n",
                      '',
                      'Testing STDOUT printf'
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf match success'
          );

check_test( sub {
            output_is {
                        print "TEST OUT";
                      }
                      "TEST OUT STDOUT",
                      '',
                      'Testing STDOUT failure'
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT is:\nTEST OUT\nnot:\nTEST OUT STDOUT\nas expected\n",
            },'STDOUT not matching failure'
          );

check_test( sub {
            output_is {
                      print STDERR "TEST OUT"}
                      '',
                      "TEST OUT STDERR",
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDERR is:\nTEST OUT\nnot:\nTEST OUT STDERR\nas expected\n",
            },'STDERR not matching failure'
          );

check_test( sub {
            output_is {
                      print "TEST ERR";
                      print STDERR "TEST OUT"}
                      'TEST ERR STDOUT',
                      "TEST OUT STDERR",
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT is:\nTEST ERR\nnot:\nTEST ERR STDOUT\nas expected\nSTDERR is:\nTEST OUT\nnot:\nTEST OUT STDERR\nas expected\n",
            },'STDOUT and STDERR not matching failure'
          );

check_test( sub {
            output_is {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      undef,
                      "TEST ERR\n",
                      'Testing STDOUT & STDERR'
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT undef match success'
          );

check_test( sub {
            output_is {
                        print "TEST OUT\n"; 
                        print STDERR "TEST ERR\n";
                      }
                      "TEST OUT\n",
                      undef,
                      'Testing STDOUT & STDERR'
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT match success STDERR undef'
          );

check_test( sub {
            output_is {
                      }
                      undef,
                      undef,
                      'Testing STDOUT & STDERR'
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR undef match success'
          );

check_test( sub {
            output_is {
                      print "TEST ERR";
                      print STDERR "TEST OUT"}
                      undef,
                      undef,
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT is:\nTEST ERR\nnot:\n\nas expected\nSTDERR is:\nTEST OUT\nnot:\n\nas expected\n",
            },'STDOUT and STDERR not matching failure'
          );

check_test( sub {
            output_is {
                      print STDERR "TEST OUT"}
                      undef,
                      undef,
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDERR is:\nTEST OUT\nnot:\n\nas expected\n",
            },'STDOUT undef and STDERR not matching failure'
          );

