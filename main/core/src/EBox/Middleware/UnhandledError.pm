# Copyright (C) 2010-2014 Zentyal S.L.
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

package EBox::Middleware::UnhandledError;
use parent qw/Plack::Middleware/;

use EBox::Gettext;
use Devel::StackTrace;
use Devel::StackTrace::AsHTML;
use Plack::Util::Accessor qw( force no_print_errors );
use Data::Dumper;
use File::Slurp qw(read_file);
use TryCatch::Lite;

sub call {
    my($self, $env) = @_;

    my $trace;
    my $res;
    try {
        $res = $self->app->($env);
    } catch ($e) {
        $trace = Devel::StackTrace->new(
            indent => 1, message => munge_error($e, [ caller ]),
            ignore_package => __PACKAGE__,
        );
    }

    if ($trace) {
        my $traceAsText = $trace->as_string;
        my $traceAsHtml = $trace->as_html;

        $env->{'plack.unhandlederror.text'} = $traceAsText;
        $env->{'plack.unhandlederror.html'} = $traceAsHtml;
        $env->{'psgi.errors'}->print($traceAsText) unless $self->no_print_errors;

        # template params
        my $theme = EBox::Global::_readTheme();
        my $headerTemplateFile = 'psgiErrorHeader.html';
        my $templateFile;
        my $params = {};
        $params->{page_title} = __('Zentyal');
        $params->{image_title} = $theme->{image_title};
        $params->{actions} = __('Actions');
        $params->{go_back} = __('Go back');
        $params->{title} = __('Sorry, an unexpected error has occurred');
        $params->{stacktrace_html} = $traceAsHtml;

        my @brokenPackages = @{ _brokenPackages() };
        if ($theme->{hide_bug_report}) {
            $params->{title} .= '. ' . __('Please contact support.');
            $params->{brokenPackages} = '';
            if (@brokenPackages) {
                $params->{brokenPackages} = __x(
                    'The following software packages are not correctly installed: {pack}',
                    pack => join ', ', @brokenPackages);
            }
            $templateFile = 'psgiErrorNoReport.html';
        } elsif (@brokenPackages) {
            $params->{show_details} = __('Show technical details');
            $params->{main_text} = __x(
                'There are some software packages which are not correctly installed: {pack}.',
                pack => join ', ', @brokenPackages) . '<p>' .
                __('You should reinstall them and retry your operation.') . '</p>';
            # FIXME: This template does not exists!!
            $templateFile = 'psgiErrorBrokenPackages.html';
        } else {
            $params->{show_details} = __('Show technical details');
            $params->{report} = __('Report the problem');
            $params->{cancel} = __('Cancel');
            $params->{email} = __('Email (you will receive updates on the report)');
            $params->{description} = __('Describe in English what you where doing');
            $params->{newticket_url} = 'http://trac.zentyal.org/newticket';
            $params->{report_error} = __("Couldn't send the report");
            $params->{report_sent} = __(
                'The report has been successfully sent, you can keep track of it in the following ticket:');

            my $instructions = '<strong>' . __(
                'To do a manual report, please follow these instructions:') . '</strong>';
            $instructions .= '<li>' . __('Create a new ticket in the Zentyal trac by clicking ');
            $instructions .= '<a class="nvac" href="#" onclick="window.open(\'http://trac.zentyal.org/newticket\')">';
            $instructions .= __('here') . "</a>.</li>";
            $instructions .= '<li>' . __('Write a short description of the problem in the summary field') . '.</li>';
            $instructions .= '<li>' . __('Write a detailed report of what you were doing before this problem ocurred in the description field') . '.</li>';
            $instructions .= '<li>' . __('Write a valid email address to be notified of ticket updates') . '.</li>';
            $instructions .= '<li>' . __('Download the log file with additional information by clicking') . ' <a class="nvac" href="/SysInfo/Log" id="log">' . __('here') . '</a>.</li>';
            $instructions .= '<li>' . __('Attach the downloaded file in the ticket') . '.</li></ol>';
            $instructions .= '<form action="Backup" method="POST" id="formreport"><input type="hidden" name="bugreport" value="a" /></form>';

            $params->{report_instructions} = $instructions;
            $templateFile = 'psgiError.html';
        }

        $traceAsText =~ s/"/'/g;
        $params->{error} = $traceAsText;
        $params->{stacktrace} = $traceAsHtml;

        # Fill HTML template values
        my $html = read_file(EBox::Config::templates . $headerTemplateFile);
        $html .= read_file(EBox::Config::templates . $templateFile);

        foreach my $key (%{$params}) {
            my $value = $params->{$key};
            $html =~ s/\Q{{ $key }}\E/$value/g;
        }

        $res = [500, ['Content-Type' => 'text/html; charset=utf-8'], [ utf8_safe($html) ]];
    }

    # Allows garbage collection of it.
    undef $trace;
    return $res;
}

sub no_trace_error {
    my $msg = shift;
    chomp($msg);

    return <<EOF;
The application raised the following error:

  $msg

and the StackTrace middleware couldn't catch its stack trace, possibly because your application overrides \$SIG{__DIE__} by itself, preventing the middleware from working correctly. Remove the offending code or module that does it: known examples are CGI::Carp and Carp::Always.
EOF
}


sub munge_error {
    my($err, $caller) = @_;
    return $err if ref $err;

    # Ugly hack to remove " at ... line ..." automatically appended by perl
    # If there's a proper way to do this, please let me know.
    $err =~ s/ at \Q$caller->[1]\E line $caller->[2]\.\n$//;

    return $err;
}

sub utf8_safe {
    my $str = shift;

    # NOTE: I know messing with utf8:: in the code is WRONG, but
    # because we're running someone else's code that we can't
    # guarantee which encoding an exception is encoded, there's no
    # better way than doing this. The latest Devel::StackTrace::AsHTML
    # (0.08 or later) encodes high-bit chars as HTML entities, so this
    # path won't be executed.
    if (utf8::is_utf8($str)) {
        utf8::encode($str);
    }

    $str;
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

