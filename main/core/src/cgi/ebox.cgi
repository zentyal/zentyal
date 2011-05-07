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
    use File::Slurp qw(read_file);

    my $trace = Devel::StackTrace->new;
    print STDERR $trace->as_string;
    print STDERR Dumper($ex);

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
    );

    # template params
    my $params = {};
    $params->{title} = __('Sorry, an unexpected error has occurred');
    $params->{show_details} = __('Show technical details');
    $params->{report} = __('Report the problem');
    $params->{cancel} = __('Cancel');
    $params->{go_back} = __('Go back');
    $params->{actions} = __('Actions');
    $params->{email} = __('Email (you will receive updates on the report)');
    $params->{description} = __('Describe in English what you where doing');
    $params->{newticket_url} = 'http://trac.zentyal.org/newticket';
    $params->{report_error} = __("Couldn't send the report");

    my $instructions = '<strong>' . __('To do it by hand follow this instructions') . '</strong>';
    $instructions .= '<li>' . __('Create a new ticket in the Zentyal trac by clicking ') . '<a class="nvac" href="#" onclick="window.open(\'http://trac.zentyal.org/newticket\')">' . __('here') . "</a>.</li>";
    $instructions .= '<li>' . __('Write a short description of the problem in the summary field') . '.</li>';
    $instructions .= '<li>' . __('Write a detailed report of what you were doing before this problem ocurred in the description field') . '.</li>';
    $instructions .= '<li>' . __('Download the log file with additional information by clicking') . ' <a class="nvac" href="/zentyal/EBox/Log" id="log">' . __('here') . '</a>.</li>';
    $instructions .= '<li>' . __('Attach the downloaded file in the ticket') . '.</li></ol>';
    $instructions .= '<form action="Backup" method="POST" id="formreport"><input type="hidden" name="bugreport" value="a" /></form></div></div>';

    $params->{report_instructions} = $instructions;

    if ( $ex->can('text') ) {
        $params->{error} = $ex->text();
    } elsif ( $ex->can('as_text') ) {
        $params->{error} = $ex->as_text();
    }

    $params->{stacktrace} = '<ul>';
    for my $line (split(/\n/,$ex->stacktrace())) {
        $params->{stacktrace} .= "<li>$line</li>\n";
    }
    $params->{stacktrace} .= '</ul>';


    # Fill HTML template values
    my $html = read_file(EBox::Config::templates . 'cgiError.html');
    foreach my $key (%{$params}) {
        my $value = $params->{$key};
        $html =~ s/{{ $key }}/$value/g;
    }
    print $html;

    print end_html;
};
