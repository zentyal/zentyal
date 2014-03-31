# Copyright (C) 2006-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::Test::CGI;

use base 'Exporter';

our @EXPORT_OK   = qw(runCgi setCgiParams cgiErrorOk cgiErrorNotOk  checkCgiError checkMasonParameters muteHtmlOutput);
our %EXPORT_TAGS = (all => \@EXPORT_OK  );

use Test::Differences;
use Test::Builder;
my $Test = Test::Builder->new;

sub runCgi
{
    my ($cgi, @params) = @_;

    setCgiParams($cgi, @params);

    $cgi->run();
}

sub setCgiParams
{
    my ($cgi, %params) = @_;

    my $request = $cgi->request();
    my $parameters = $request->parameters();
    while (my ($paramName, $paramValue) = each %params) {
        $parameters->set($paramName, $paramValue);
    }
}

# there are 3 subs to check error because i am not sure what style/name is better
sub cgiErrorOk
{
    my ($cgi, $name) = @_;
    my $errorFound = _errorInCgi($cgi);

    $Test->ok($errorFound, $name);
}

sub cgiErrorNotOk
{
    my ($cgi, $name) = @_;
    my $errorNotFound = not _errorInCgi($cgi);

    $Test->ok($errorNotFound, $name);
}

sub checkCgiError
{
    my ($cgi, $wantError, $name) = @_;
    if ($wantError) {
        cgiErrorOk($cgi, $name);
    }
    else {
        cgiErrorNotOk($cgi, $name);
    }
}

sub _errorInCgi
{
    my ($cgi) = @_;
    return defined ($cgi->{error}) or defined ($cgi->{olderror});
}

sub muteHtmlOutput
{
    my ($class) = @_;

    my $mutePrintHtmlCode = "no warnings; package $class; sub _print {}; ";
    eval $mutePrintHtmlCode;
    if ($@) {
        die "Error when overriding _printHtml with a muted version: $@";
    }
}

sub checkMasonParameters
{
    my ($cgi, %params) = @_;

    exists $params{wantedParameters} or die "wantedParameters argument not found";
    my $wantedParameters = $params{wantedParameters};

    my $testName = exists $params{testName} ? $params{testName} : 'Checking mason parameters';

    # we convert to hash to eliminate order issues
    my $masonParameters = $cgi->{params};
    my $params = defined $masonParameters ?  { @{ $masonParameters } } : {};

    eq_or_diff $params, $wantedParameters, $testName;
}

1;
