use Test::Tester;
use Test::More tests => 168;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            output_isnt(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST OUT"},
                      "TEST OUT STDOUT\n",
                      undef,
                      'Testing STDOUT'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT not equal success'
          );

check_test( sub {
            output_isnt(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST OUT\n";
                      },
                      undef,
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
            output_isnt(sub {
                        print "TEST OUT\n"; 
                        print STDERR "TEST ERR\n";
                      },
                      "TEST OUT STDOUT\n",
                      "TEST ERR STDERR\n",
                      'Testing STDOUT & STDERR'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR not equal success'
          );

check_test( sub {
            output_isnt(sub {
                        printf("TEST OUT - %d\n",25);
                        print STDERR "TEST OUT"},
                      "TEST OUT - 42\n",
                      undef,
                      'Testing STDOUT printf'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf not equal success'
          );

check_test( sub {
            output_isnt(sub {
                        printf STDERR ("TEST OUT - %d\n",25);
                      },
                      undef,
                      "TEST OUT - 42\n",
                      'Testing STDERR printf'
                    )
            },{
              ok => 1,
              name => 'Testing STDERR printf',
              diag => '',
            },'STDERR printf not equal success'
          );

check_test( sub {
            output_isnt(sub {
                        print "TEST OUT - 25";
                        printf STDERR "TEST OUT - 25";
                      },
                      "TEST OUT - 25",
                      "TEST OUT - 25",
                      'Testing STDOUT & STDERR print'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT & STDERR print',
              diag => "STDOUT:\nTEST OUT - 25\nmatching:\nTEST OUT - 25\nnot expected\nSTDERR:\nTEST OUT - 25\nmatching:\nTEST OUT - 25\nnot expected\n",
            },'STDOUT & STDERR matches failure'
          );

check_test( sub {
            output_isnt(sub {
                        print "TEST OUT";
                        print STDERR "TEST OUT"},
                      "TEST OUT",
                      '',
                      'Testing STDOUT failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'STDOUT matches failure'
          );

check_test( sub {
            output_isnt(sub {
                      print "TEST OUT";
                      print STDERR "TEST OUT"},
                      '',
                      "TEST OUT",
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDERR:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'STDERR matches failure'
          );

check_test( sub {
            output_isnt(sub {
                      print "TEST OUT";
                      print STDERR "TEST OUT"},
                      undef,
                      undef,
                      'Testing STDERR failure'
                    )
            }, {
              ok => 1,
              name => 'Testing STDERR failure',
              diag => '',
            },'STDOUT & STDERR not matching success'
          );

check_test( sub {
            output_isnt(sub {
                        print "TEST OUT";
                      },
                      undef,
                      undef,
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDERR:\n\nmatching:\n\nnot expected\n",
            },'STDERR matches failure'
          );

check_test( sub {
            output_isnt(sub {
                        print STDERR "TEST OUT";
                      },
                      undef,
                      undef,
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT:\n\nmatching:\n\nnot expected\n",
            },'STDOUT matches failure'
          );

check_test( sub {
            output_isnt(sub {
                      },
                      undef,
                      undef,
                      'Testing STDERR failure'
                    )
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT:\n\nmatching:\n\nnot expected\nSTDERR:\n\nmatching:\n\nnot expected\n",
            },'STDOUT & STDERR matches failure'
          );

check_test( sub {
            output_isnt {
                        print "TEST OUT\n";
                        print STDERR "TEST OUT"}
                      "TEST OUT STDOUT\n",
                      undef,
                      'Testing STDOUT'
            },{
              ok => 1,
              name => 'Testing STDOUT',
              diag => '',
            },'STDOUT not equal success'
          );

check_test( sub {
            output_isnt {
                        print "TEST OUT\n";
                        print STDERR "TEST OUT\n";
                      }
                      undef,
                      "TEST OUT STDERR\n",
                      'Testing STDERR'
            },{
              ok => 1,
              name => 'Testing STDERR',
              diag => '',
            },'STDERR not equal success'
          );

check_test( sub {
            output_isnt {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      "TEST OUT STDOUT\n",
                      "TEST ERR STDERR\n",
                      'Testing STDOUT & STDERR'
            },{
              ok => 1,
              name => 'Testing STDOUT & STDERR',
              diag => '',
            },'STDOUT & STDERR not equal success'
          );

check_test( sub {
            output_isnt {
                        printf("TEST OUT - %d\n",25);
                        print STDERR "TEST OUT"}
                      "TEST OUT - 42\n",
                      undef,
                      'Testing STDOUT printf'
            },{
              ok => 1,
              name => 'Testing STDOUT printf',
              diag => '',
            },'STDOUT printf not equal success'
          );

check_test( sub {
            output_isnt {
                        printf STDERR ("TEST OUT - %d\n",25);
                      }
                      undef,
                      "TEST OUT - 42\n",
                      'Testing STDERR printf'
            },{
              ok => 1,
              name => 'Testing STDERR printf',
              diag => '',
            },'STDERR printf not equal success'
          );

check_test( sub {
            output_isnt {
                        print "TEST OUT - 25";
                        printf STDERR "TEST OUT - 25";
                      }
                      "TEST OUT - 25",
                      "TEST OUT - 25",
                      'Testing STDOUT & STDERR print'
            },{
              ok => 0,
              name => 'Testing STDOUT & STDERR print',
              diag => "STDOUT:\nTEST OUT - 25\nmatching:\nTEST OUT - 25\nnot expected\nSTDERR:\nTEST OUT - 25\nmatching:\nTEST OUT - 25\nnot expected\n",
            },'STDOUT & STDERR matches failure'
          );

check_test( sub {
            output_isnt {
                        print "TEST OUT";
                        print STDERR "TEST OUT"}
                      "TEST OUT",
                      '',
                      'Testing STDOUT failure'
            }, {
              ok => 0,
              name => 'Testing STDOUT failure',
              diag => "STDOUT:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'STDOUT matches failure'
          );

check_test( sub {
            output_isnt {
                      print "TEST OUT";
                      print STDERR "TEST OUT"}
                      '',
                      "TEST OUT",
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDERR:\nTEST OUT\nmatching:\nTEST OUT\nnot expected\n",
            },'STDERR matches failure'
          );

check_test( sub {
            output_isnt {
                      print "TEST OUT";
                      print STDERR "TEST OUT"}
                      undef,
                      undef,
                      'Testing STDERR failure'
            }, {
              ok => 1,
              name => 'Testing STDERR failure',
              diag => '',
            },'STDOUT & STDERR not matching success'
          );

check_test( sub {
            output_isnt {
                        print "TEST OUT";
                      }
                      undef,
                      undef,
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDERR:\n\nmatching:\n\nnot expected\n",
            },'STDERR matches failure'
          );

check_test( sub {
            output_isnt {
                        print STDERR "TEST OUT";
                      }
                      undef,
                      undef,
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT:\n\nmatching:\n\nnot expected\n",
            },'STDOUT matches failure'
          );

check_test( sub {
            output_isnt {
                      }
                      undef,
                      undef,
                      'Testing STDERR failure'
            }, {
              ok => 0,
              name => 'Testing STDERR failure',
              diag => "STDOUT:\n\nmatching:\n\nnot expected\nSTDERR:\n\nmatching:\n\nnot expected\n",
            },'STDOUT & STDERR matches failure'
          );
