use Test::Tester;
use Test::More tests => 112;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            output_unlike(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/ERR/i,
                      qr/OUT/i,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT and STDOUT not matching success'
          );

check_test( sub {
            output_unlike(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      undef,
                      qr/OUT/i,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT and STDOUT not matching success'
          );

check_test( sub {
            output_unlike(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/ERR/i,
                      undef,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT and STDOUT not matching success'
          );

check_test( sub {
            output_unlike(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      'OUT',
                      qr/err/,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              depth => 2,
              name => 'output_unlike_STDOUT',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'STDOUT bad regex'
          );

check_test( sub {
            output_unlike(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/OUT/i,
                      'OUT',
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              depth => 2,
              name => 'output_unlike_STDERR',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'STDERR bad regex'
          );

check_test( sub {
            output_unlike(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/out/,
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDERR:\nTEST ERR\n\nmatches:\n(?i-xsm:ERR)\nnot expected\n",
            },'STDERR matching failure'
          );

check_test( sub {
            output_unlike(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/out/i,
                      qr/err/,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT:\nTEST OUT\n\nmatches:\n(?i-xsm:out)\nnot expected\n",
            },'STDOUT matching failure'
          );

check_test( sub {
            output_unlike(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/OUT/,
                      qr/ERR/,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT:\nTEST OUT\n\nmatches:\n(?-xism:OUT)\nnot expected\nSTDERR:\nTEST ERR\n\nmatches:\n(?-xism:ERR)\nnot expected\n",
            },'STDERR matching failure'
          );

check_test( sub {
            output_unlike {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/ERR/i,
                      qr/OUT/i,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT and STDOUT not matching success'
          );

check_test( sub {
            output_unlike {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      undef,
                      qr/OUT/i,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT and STDOUT not matching success'
          );

check_test( sub {
            output_unlike {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/ERR/i,
                      undef,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT and STDOUT not matching success'
          );

check_test( sub {
            output_unlike {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      'OUT',
                      qr/err/,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              depth => 2,
              name => 'output_unlike_STDOUT',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'STDOUT bad regex'
          );

check_test( sub {
            output_unlike {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/OUT/i,
                      'OUT',
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              depth => 2,
              name => 'output_unlike_STDERR',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'STDERR bad regex'
          );

check_test( sub {
            output_unlike {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/out/,
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDERR:\nTEST ERR\n\nmatches:\n(?i-xsm:ERR)\nnot expected\n",
            },'STDERR matching failure'
          );

check_test( sub {
            output_unlike {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/out/i,
                      qr/err/,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT:\nTEST OUT\n\nmatches:\n(?i-xsm:out)\nnot expected\n",
            },'STDOUT matching failure'
          );

check_test( sub {
            output_unlike {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/OUT/,
                      qr/ERR/,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT:\nTEST OUT\n\nmatches:\n(?-xism:OUT)\nnot expected\nSTDERR:\nTEST ERR\n\nmatches:\n(?-xism:ERR)\nnot expected\n",
            },'STDERR matching failure'
          );
