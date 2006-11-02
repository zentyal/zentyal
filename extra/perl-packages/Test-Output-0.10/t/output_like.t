use Test::Tester;
use Test::More tests => 154;
use Test::Output;

use strict;
use warnings;

check_test( sub {
            output_like(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/OUT/i,
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT and STDOUT matching success'
          );

check_test( sub {
            output_like(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/OUT/i,
                      undef,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT matching STDERR ignored success'
          );

check_test( sub {
            output_like(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      undef,
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT ignored and STDERR matching success'
          );

check_test( sub {
            output_like(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      undef,
                      undef,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT is:\nTEST OUT\n\nnot:\n\nas expected\nSTDERR is:\nTEST ERR\n\nnot:\n\nas expected\n",
            },'STDOUT ignored and STDERR matching success'
          );

check_test( sub {
            output_like(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      'OUT',
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              depth => 2,
              name => 'output_like_STDOUT',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'STDOUT bad regex'
          );

check_test( sub {
            output_like(sub {
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
              name => 'output_like_STDERR',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'STDERR bad regex'
          );

check_test( sub {
            output_like(sub {
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
              diag => "STDOUT:\nTEST OUT\n\ndoesn't match:\n(?-xism:out)\nas expected\n",
            },'STDOUT not matching failure'
          );

check_test( sub {
            output_like(sub {
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
              diag => "STDERR:\nTEST ERR\n\ndoesn't match:\n(?-xism:err)\nas expected\n",
            },'STDERR not matching failure'
          );

check_test( sub {
            output_like(sub {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      },
                      qr/out/,
                      qr/err/,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT:\nTEST OUT\n\ndoesn't match:\n(?-xism:out)\nas expected\nSTDERR:\nTEST ERR\n\ndoesn't match:\n(?-xism:err)\nas expected\n",
            },'STDOUT & STDERR not matching failure'
          );

check_test( sub {
            output_like(sub {
                      },
                      undef,
                      undef,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT & STDERR undef matching success'
          );

check_test( sub {
            output_like(sub {
                        print STDERR "TEST OUT\n";
                      },
                      undef,
                      undef,
                      'Testing STDOUT and STDERR match'
                    )
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDERR is:\nTEST OUT\n\nnot:\n\nas expected\n",
            },'STDOUT & STDERR not matching failure'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/OUT/i,
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT and STDOUT matching success'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/OUT/i,
                      undef,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT matching STDERR ignored success'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      undef,
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT ignored and STDERR matching success'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      undef,
                      undef,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT is:\nTEST OUT\n\nnot:\n\nas expected\nSTDERR is:\nTEST ERR\n\nnot:\n\nas expected\n",
            },'STDOUT ignored and STDERR matching success'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      'OUT',
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              depth => 2,
              name => 'output_like_STDOUT',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'STDOUT bad regex'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/OUT/i,
                      'OUT',
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              depth => 2,
              name => 'output_like_STDERR',
              diag => "'OUT' doesn't look much like a regex to me.\n",
            },'STDERR bad regex'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/out/,
                      qr/ERR/i,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT:\nTEST OUT\n\ndoesn't match:\n(?-xism:out)\nas expected\n",
            },'STDOUT not matching failure'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/out/i,
                      qr/err/,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDERR:\nTEST ERR\n\ndoesn't match:\n(?-xism:err)\nas expected\n",
            },'STDERR not matching failure'
          );

check_test( sub {
            output_like {
                        print "TEST OUT\n";
                        print STDERR "TEST ERR\n";
                      }
                      qr/out/,
                      qr/err/,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDOUT:\nTEST OUT\n\ndoesn't match:\n(?-xism:out)\nas expected\nSTDERR:\nTEST ERR\n\ndoesn't match:\n(?-xism:err)\nas expected\n",
            },'STDOUT & STDERR not matching failure'
          );

check_test( sub {
            output_like {
                      }
                      undef,
                      undef,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 1,
              name => 'Testing STDOUT and STDERR match',
              diag => '',
            },'STDOUT & STDERR undef matching success'
          );

check_test( sub {
            output_like {
                        print STDERR "TEST OUT\n";
                      }
                      undef,
                      undef,
                      'Testing STDOUT and STDERR match'
            },{
              ok => 0,
              name => 'Testing STDOUT and STDERR match',
              diag => "STDERR is:\nTEST OUT\n\nnot:\n\nas expected\n",
            },'STDOUT & STDERR not matching failure'
          );
