#!/usr/bin/perl
# Copyright (C) 2010-2012 eBox Technologies S.L.
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
use POSIX qw(:signal_h setlocale LC_ALL LC_NUMERIC);

try {
    use EBox::CGI::Run;
    use EBox;
    EBox::initLogger('usercorner-log.conf');
    POSIX::setlocale(LC_ALL, EBox::locale());
    POSIX::setlocale(LC_NUMERIC, 'C');

    # Workaround to clear Apache2's process mask
    my $sigset = POSIX::SigSet->new();
    $sigset->fillset();
    sigprocmask(SIG_UNBLOCK, $sigset);

    binmode(STDOUT, ':utf8');
    EBox::CGI::Run->run($ENV{'script'}, 'EBox::UserCorner');
} otherwise  {
    my $ex = shift;
    use Devel::StackTrace;
    use CGI qw/:standard/;
    use Data::Dumper;
    use File::Slurp qw(read_file);

    my $trace = Devel::StackTrace->new;
    print STDERR $trace->as_string;
    print STDERR Dumper($ex);

    print header;
    print start_html(-title => __('Zentyal'),
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
    );

    # template params
    my $theme = EBox::Global::_readTheme();
    my $templateFile;
    my $params = {};
    $params->{image_title} = $theme->{image_title};
    $params->{actions} = __('Actions');
    $params->{go_back} = __('Go back');
    $params->{title} = __('Sorry, an unexpected error has occurred');
    if ($theme->{hide_bug_report}) {
        $params->{title} .= '. ' . __('Please contact support.');
        $templateFile = 'cgiErrorNoReport.html';
    } else {
        $params->{show_details} = __('Show technical details');
        $params->{report} = __('Report the problem');
        $params->{cancel} = __('Cancel');
        $params->{email} = __('Email (you will receive updates on the report)');
        $params->{description} = __('Describe in English what you where doing');
        $params->{newticket_url} = 'http://trac.zentyal.org/newticket';
        $params->{report_error} = __("Couldn't send the report");
        $params->{report_sent} = __('The report has been successfully sent, you can keep track of it in the following ticket:');

        my $instructions = '<strong>' . __('To do a manual report, please follow these instructions:') . '</strong>';
        $instructions .= '<li>' . __('Create a new ticket in the Zentyal trac by clicking ') . '<a class="nvac" href="#" onclick="window.open(\'http://trac.zentyal.org/newticket\')">' . __('here') . "</a>.</li>";
        $instructions .= '<li>' . __('Write a short description of the problem in the summary field') . '.</li>';
        $instructions .= '<li>' . __('Write a detailed report of what you were doing before this problem ocurred in the description field') . '.</li>';
        $instructions .= '<li>' . __('Download the log file with additional information by clicking') . ' <a class="nvac" href="/SysInfo/Log" id="log">' . __('here') . '</a>.</li>';
        $instructions .= '<li>' . __('Attach the downloaded file in the ticket') . '.</li></ol>';
        $instructions .= '<form action="Backup" method="POST" id="formreport"><input type="hidden" name="bugreport" value="a" /></form></div></div>';

        $params->{report_instructions} = $instructions;
        $templateFile = 'cgiError.html';
    }

    my $error;
    if ( $ex->can('text') ) {
        $error = $ex->text();
    } elsif ( $ex->can('as_text') ) {
        $error = $ex->as_text();
    }
    $error =~ s/"/'/g;
    $params->{error} = $error;

    my $stacktrace = $ex->stacktrace();
    $params->{stacktrace_html} = '<ul>';
    for my $line (split (/\n/, $stacktrace)) {
        $params->{stacktrace_html} .= "<li>$line</li>\n";
    }
    $params->{stacktrace_html} .= '</ul>';
    $stacktrace =~ s/"/'/g;
    $params->{stacktrace} = $stacktrace;

    # Fill HTML template values
    my $html = read_file(EBox::Config::templates . $templateFile);
    foreach my $key (%{$params}) {
        my $value = $params->{$key};
        $html =~ s/{{ $key }}/$value/g;
    }
    print $html;

    print end_html;
};
