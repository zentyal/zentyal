#!/usr/bin/perl
# Copyright (C) 2010 eBox Technologies S.L.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use warnings;

use EBox::Gettext;
use Error qw(:try);
use POSIX qw(:signal_h);

try {
    use EBox::CGI::Run;
    use EBox::CGI::EBox::ConfigurationReport;
    use EBox;

    # Workaround to clear Apache2's process mask
    my $sigset = POSIX::SigSet->new();
    $sigset->fillset();
    sigprocmask(SIG_UNBLOCK, $sigset);

    EBox::init();
    EBox::CGI::Run->run($ENV{'script'}, 'EBox');
} otherwise  {
    my $ex = shift;
    use Devel::StackTrace;
    use CGI qw/:standard/;
    use Data::Dumper;

    my $trace = Devel::StackTrace->new;
    print STDERR $trace->as_string;
    print STDERR Dumper($ex);

    eval {
        my $backup = EBoc::Backup->new();
        $backup->makeBugReport();
    };

    my $backupReportError = $@;
    print header;
    print start_html(-title => 'Zentyal',
       -script => [
            {-type => 'text/javascript',
             -src  => '/data/js/common.js'},
            {-type => 'text/javascript',
             -src  => '/data/js/prototype.js'},
            {-type => 'text/javascript',
             -src  => '/data/js/scriptaculous/scriptaculous.js'}
            ],
       -head => Link({-rel=>'stylesheet',
            -href => '/dynamic-data/css/public.css',
            -type => 'text/css'
            }),
       -onload => 'document.getElementById("details").hide();document.getElementById("report").hide()'
    );
    print '<div id="top"></div><div id="header"><a href="/ebox"><img src="/data/images/title.png" alt="title"/></a></div>';
    print '<div id="menu"><ul id="nav"><li id=""><div class="separator">' . __('Actions').'</div></li>';
    print '<li id="menu_0"><a href="#" class="nvac" onclick="document.getElementById(\'details\').show()">' . __('Show technical details').'</a></li>';
    print '<li id="menu_1"><a href="#" class="nvac" onclick="document.getElementById(\'report\').show(); document.getElementById(\'details\').hide()">' . __('Report this problem') . '</a></li>';
    print '<li id="menu_2"><a href="#" class="nvac" onclick="history.go(-1)">' . __('Go back') . '</a></li></ul>';
    print '</div>';
    print '<div><div id="limewrap"><div id="content"><div><span class="title">';
    print __('Sorry, an unexpected error has ocurred');
    print '</span></div>' . "\n\t" . '<div class="error">';
    if ( $ex->can('text') ) {
        print $ex->text();
    } elsif ( $ex->can('as_text') ) {
        print $ex->as_text();
    }
    print "\t" . '</div>' . "\n\t" . '<div><br>';
    print __('To show technical details click ');
    print '<a href="#" onclick="document.getElementById(\'details\').show()">';
    print __('here');
    print '</a>.</div><br><div id="details"><div><b> Trace </b></div><div>';
    for my $line (split(/\n/,$ex->stacktrace())) {
        print "$line<br/>";
    }
    print '</div><br/></div><div id="report"><div><b>' . __('How to report this problem') . '</b></div><br><div><ol>';
    if ($backupReportError) {
        print '<li>' . __('Download the log file with additional information by clicking') . ' <a class="nvac" href="/Log" id="log">' . __('here') . '</a>.</li>';
        print '<script>document.getElementById(\'log\').href="https://"+document.domain+"/ebox/EBox/Log"; </script>';
    } else {
        print '<li>' . __('Download a configuration report by clicking') . ' <a href="#" class="nvac" onclick=\'document.forms[0].action="https://"+document.domain+"/ebox/EBox/Backup"; document.forms[0].submit();\'>' . __('here') . '</a>.</li>';
    }

    print '<li>' . __('If the problem has ocurred right after installing or upgrading Zentyal, please') . ' <a class="nvac" href="/Software/Log" id="software_log">' . __('download this file') . '</a>.</li>';
    print '<script>document.getElementById(\'software_log\').href="https://"+document.domain+"/ebox/Software/Log"; </script>';

    print '<li>' . __('Create a new ticket in the Zentyal trac by clicking ') . '<a class="nvac" href="#" onclick="window.open(\'http://trac.zentyal.org/newticket\')">' . __('here') . "</a>.</li>";
    print '<li>' . __('Write a short description of the problem in the summary field') . '.</li>';
    print '<li>' . __('Write a detailed report of what you were doing before this problem ocurred in the description field') . '.</li>';
    print '<li>' . __('Do not forget to attach the downloaded file in the ticket') . '.</li></ol>';
    print '<form action="Backup" method="POST" id="formreport"><input type="hidden" name="bugreport" value="a" /></form></div></div>';
    print '<div><a href="#" onclick="history.go(-1)">' . __('Go back') . '</a></div>';
    print end_html;
};
