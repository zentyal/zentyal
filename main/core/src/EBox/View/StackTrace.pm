# Copyright (C) 2014 Zentyal S.L.
#
# Based on Devel::StackTrace::AsHTML by Tatsuhiko Miyagawa <miyagawa@bulknews.net> and Shawn M Moore
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

package EBox::View::StackTrace;

use EBox::Config;
use EBox::Gettext;
use EBox::Global;

use Data::Dumper;
use Devel::StackTrace;
use File::Slurp qw(read_file);

no warnings 'qw';
my %enc = qw( & &amp; > &gt; < &lt; " &quot; ' &#39; );
my $SHOW_TRACE_URL = '/ShowTrace';

# Method encode_html
#
# We assume the text will be UTF-8 encoded.
#
sub encode_html {
    my $str = shift;
    $str =~ s/([^\x00-\x21\x23-\x25\x28-\x3b\x3d\x3f-\xff])/$enc{$1} || '&#' . ord($1) . ';' /ge;
    utf8::downgrade($str);
    $str;
}

sub Devel::StackTrace::as_html {
    __PACKAGE__->render(@_);
}

sub Devel::StackTrace::as_html_snippet {
    __PACKAGE__->renderSnippet(@_);
}

sub Devel::StackTrace::redirect_html {
    qq{<script type="text/javascript">window.location.href="$SHOW_TRACE_URL"</script>};
}

sub renderSnippet
{
    my($class, $trace, %opt) = @_;

    my $snippet = '';
    my $errorTitle = encode_html($trace->frame(0)->as_string(1));
    $snippet .= "<h1>Error trace</h1><pre class=\"message\">$errorTitle</pre><ol>";

    my $i = 0;
    while (my $frame = $trace->next_frame) {
        $i++;
        my $next_frame = $trace->frame($i); # peek next
        $snippet .= join(
            '',
            '<li class="frame">',
            ($next_frame && $next_frame->subroutine) ? encode_html("in " . $next_frame->subroutine) : '',
            ' at ',
            $frame->filename ? encode_html($frame->filename) : '',
            ' line ',
            $frame->line,
            q(<pre class="context"><code>),
            _build_context($frame) || '',
            q(</code></pre>),
            _build_arguments($i, $next_frame),
            $frame->can('lexicals') ? _build_lexicals($i, $frame->lexicals) : '',
            q(</li>),
        );
    }
    $snippet .= qq{</ol>};

    return $snippet;
}

sub render
{
    my($class, $trace, %opt) = @_;

    my $theme = EBox::Global::_readTheme();
    my $headerTemplateFile = 'psgiErrorHeader.html';
    my $templateFile;
    my $params = {};
    # header template params
    $params->{page_title} = __('Zentyal');
    # common template params
    $params->{image_title} = $theme->{image_title};
    $params->{actions} = __('Actions');
    $params->{go_back} = __('Go back');
    $params->{title} = __('Sorry, an unexpected error has occurred');
    $params->{stacktrace_html} = renderSnippet($class, $trace, %opt);
    $params->{error} = encode_html($trace->frame(0)->as_string(1));

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
        $templateFile = 'psgiErrorBrokenPackages.html';
    } else {
        my $stacktrace = $trace->as_string();
        $stacktrace =~ s/"/'/g;
        $params->{stacktrace} = $stacktrace;
        $params->{show_details} = __('Show technical details');
        $params->{report} = __('Report the problem');
        $params->{cancel} = __('Cancel');
        $params->{email} = __('Email (you will receive updates on the report)');
        $params->{description} = __('Describe in English what you were doing');
        $params->{newticket_url} = 'https://tracker.zentyal.org/projects/zentyal/issues/new';
        $params->{report_error} = __("Couldn't send the report");
        $params->{report_sent} = __(
            'The report has been successfully sent, you can keep track of it in the following ticket:');

        my $instructions = '<strong>' . __(
            'To do a manual report, please follow these instructions:') . '</strong>';
        $instructions .= '<li>' . __('Create a new ticket in the Zentyal bug tracker by clicking ');
        $instructions .= '<a class="nvac" href="#" onclick="window.open(\'https://tracker.zentyal.org/projects/zentyal/issues/new\')">';
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

    # Fill HTML template values
    my $html = read_file(EBox::Config::templates . $headerTemplateFile);
    $html .= read_file(EBox::Config::templates . $templateFile);

    foreach my $key (%{$params}) {
        my $value = $params->{$key};
        $html =~ s/\Q{{ $key }}\E/$value/g;
    }

    $html .= "</body></html>";

    return $html;
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

my $dumper = sub {
    my $value = shift;
    $value = $$value if ref $value eq 'SCALAR' or ref $value eq 'REF';
    my $d = Data::Dumper->new([ $value ]);
    $d->Indent(1)->Terse(1)->Deparse(1);
    chomp(my $dump = $d->Dump);
    $dump;
};

sub _build_arguments {
    my($id, $frame) = @_;
    my $ref = "arg-$id";

    return '' unless $frame && $frame->args;

    my @args = $frame->args;

    my $html = qq(<p><a class="toggle" id="toggle-$ref" href="javascript:toggleArguments('$ref')">Show function arguments</a></p><table class="arguments" id="arguments-$ref">);

    # Don't use while each since Dumper confuses that
    for my $idx (0 .. @args - 1) {
        my $value = $args[$idx];
        my $dump = $dumper->($value);
        $html .= qq{<tr>};
        $html .= qq{<td class="variable">\$_[$idx]</td>};
        $html .= qq{<td class="value">} . encode_html($dump) . qq{</td>};
        $html .= qq{</tr>};
    }
    $html .= qq(</table>);

    return $html;
}

sub _build_lexicals {
    my($id, $lexicals) = @_;
    my $ref = "lex-$id";

    return '' unless keys %$lexicals;

    my $html = qq(<p><a class="toggle" id="toggle-$ref" href="javascript:toggleLexicals('$ref')">Show lexical variables</a></p><table class="lexicals" id="lexicals-$ref">);

    # Don't use while each since Dumper confuses that
    for my $var (sort keys %$lexicals) {
        my $value = $lexicals->{$var};
        my $dump = $dumper->($value);
        $dump =~ s/^\{(.*)\}$/($1)/s if $var =~ /^\%/;
        $dump =~ s/^\[(.*)\]$/($1)/s if $var =~ /^\@/;
        $html .= qq{<tr>};
        $html .= qq{<td class="variable">} . encode_html($var)  . qq{</td>};
        $html .= qq{<td class="value">}    . encode_html($dump) . qq{</td>};
        $html .= qq{</tr>};
    }
    $html .= qq(</table>);

    return $html;
}

sub _build_context {
    my $frame = shift;
    my $file    = $frame->filename;
    my $linenum = $frame->line;
    my $code;
    if (-f $file) {
        my $start = $linenum - 3;
        my $end   = $linenum + 3;
        $start = $start < 1 ? 1 : $start;
        open my $fh, '<', $file
            or die "cannot open $file:$!";
        my $cur_line = 0;
        while (my $line = <$fh>) {
            ++$cur_line;
            last if $cur_line > $end;
            next if $cur_line < $start;
            $line =~ s|\t|        |g;
            my @tag = $cur_line == $linenum
                ? (q{<strong class="match">}, '</strong>')
                    : ('', '');
            $code .= sprintf(
                '%s%5d: %s%s', $tag[0], $cur_line, encode_html($line),
                $tag[1],
            );
        }
        close $file;
    }
    return $code;
}

1;

