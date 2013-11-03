#!/usr/bin/perl
# Copyright (C) 2010-2013 Zentyal S.L.
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
use TryCatch::Lite;
use POSIX qw(:signal_h);

try {
    use EBox::CGI::Run;
    use EBox;

    # Workaround to clear Apache2's process mask
    my $sigset = POSIX::SigSet->new();
    $sigset->fillset();
    sigprocmask(SIG_UNBLOCK, $sigset);

    EBox::init();
    binmode(STDOUT, ':utf8');

    EBox::CGI::Run->run($ENV{'script'});
} catch ($ex) {
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
             -src  => '/data/js/jquery.js'},
            {-type => 'text/javascript',
             -src  => '/data/js/common.js'},
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

    my @brokenPackages = @{ _brokenPackages() };
    if ($theme->{hide_bug_report}) {
        $params->{title} .= '. ' . __('Please contact support.');
        $params->{brokenPackages} = '';
        if (@brokenPackages) {
            $params->{brokenPackages} = __x('The following software packages are not correctly installed: {pack}',
                                            pack => join ', ', @brokenPackages);
        }
        $templateFile = 'cgiErrorNoReport.html';
    } elsif (@brokenPackages) {
        $params->{show_details} = __('Show technical details');
        $params->{main_text} = __x('There are some software packages which are not correctly installed: {pack}. <p>You should reinstall them and retry your operation.</p>',
                                    pack => join ', ', @brokenPackages
                                    );
        $templateFile = 'cgiErrorBrokenPackages.html';
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
        $instructions .= '<li>' . __('Write a valid email address to be notified of ticket updates') . '.</li>';
        $instructions .= '<li>' . __('Download the log file with additional information by clicking') . ' <a class="nvac" href="/SysInfo/Log" id="log">' . __('here') . '</a>.</li>';
        $instructions .= '<li>' . __('Attach the downloaded file in the ticket') . '.</li></ol>';
        $instructions .= '<form action="Backup" method="POST" id="formreport"><input type="hidden" name="bugreport" value="a" /></form>';

        $params->{report_instructions} = $instructions;
        $templateFile = 'cgiError.html';
    }

    my $error;
    if ($ex->can('text')) {
        $error = $ex->text();
    } elsif ($ex->can('as_text')) {
        $error = $ex->as_text();
    } else {
        $error = "$ex";
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
        $html =~ s/\Q{{ $key }}\E/$value/g;
    }

    print $html;
}

sub _brokenPackages
{
    my @pkgs;
    my @output = `dpkg -l | grep -i ^i[fFHh]`;
    foreach my $line (@output) {
        my ($status, $name, $other) = split '\s+', $line, 3;
        push @pkgs, $name;
    }

    return \@pkgs;
}

1;
