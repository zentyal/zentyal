#!/usr/bin/perl
use strict;
use warnings;

use EBox::Gettext;
use Error qw(:try);
use POSIX qw(:signal_h);

try {
    use EBox::CGI::Run;
    use EBox;

    # Workaround to clear Apache2's process mask
    my $sigset = POSIX::SigSet->new();
    $sigset->fillset();
    sigprocmask(SIG_UNBLOCK, $sigset);

    EBox::init();
    EBox::CGI::Run->run($ENV{'script'});
} otherwise  {
    my $ex = shift;
    use Devel::StackTrace;
    use CGI qw/:standard/;
    use Data::Dumper;

    my $trace = Devel::StackTrace->new;
    print STDERR $trace->as_string;
    print STDERR Dumper($ex);

    print header;
    print start_html(-title=>'EBox', -style=>{'src'=>'/data/css/public.css'});
    print h1(__('A really nasty bug has occurred'));
    print h2(__('Exception'));
    print $ex->text();
    print h2(__('Trace'));
    for my $line (split(/\n/, $ex->stacktrace())) {
       print "$line<br/>";	
    }


    print end_html;
};
