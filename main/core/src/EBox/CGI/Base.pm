# Copyright (C) 2004-2007 Warp Networks S.L.
# Copyright (C) 2008-2014 Zentyal S.L.
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

package EBox::CGI::Base;

use EBox::Gettext;
use EBox;
use EBox::Global;
use EBox::CGI::Run;
use EBox::Html;
use EBox::Exceptions::Base;
use EBox::Exceptions::Error;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::WrongHTTPReferer;
use EBox::Util::GPG;

use CGI;
use Encode qw(:all);
use File::Basename;
use File::Temp qw(tempfile);
use HTML::Mason;
use HTML::Mason::Exceptions;
use JSON::XS;
use Perl6::Junction qw(all any);
use POSIX qw(setlocale LC_ALL);
use TryCatch;
use URI;

## arguments
##      title [optional]
##      error [optional]
##      msg [optional]
##      cgi   [optional]
##      template [optional]
sub new # (title=?, error=?, msg=?, cgi=?, template=?)
{
    my $class = shift;
    my %opts = @_;
    my $self = {};

    unless (defined $opts{request}) {
        throw EBox::Exceptions::MissingArgument('request');
    }

    $self->{title} = delete $opts{title};
    $self->{crumbs} = delete $opts{crumbs};
    $self->{olderror} = delete $opts{error};
    $self->{msg} = delete $opts{msg};
    $self->{cgi} = delete $opts{cgi};
    $self->{request} = delete $opts{request};
    $self->{template} = delete $opts{template};
    unless (defined($self->{cgi})) {
        $self->{cgi} = new CGI;
    }
    $self->{paramsKept} = ();
    $self->{response} = undef;

    bless($self, $class);
    return $self;
}

sub _header
{
}

sub _top
{
}

sub _menu
{
}

sub _title
{
    my ($self) = @_;

    my $title = $self->{title};
    my $crumbs = $self->{crumbs};

    my $filename = 'title.mas';
    my @params = (title => $title, crumbs => $crumbs);
    return EBox::Html::makeHtml($filename, @params);
}

sub _format_error # (text)
{
    my ($self, $text) = @_;

    $text or return;
    ($text ne "") or return;
    my $filename = 'error.mas';
    my @params = ('error' => $text);
    return EBox::Html::makeHtml($filename, @params);
}

sub _error #
{
    my ($self) = @_;

    if (defined $self->{olderror}) {
        return $self->_format_error($self->{olderror});
    }
    if (defined $self->{error}) {
        return $self->_format_error($self->{error});
    }
}

sub _msg
{
    my ($self) = @_;

    defined($self->{msg}) or return;
    my $filename = 'msg.mas';
    my @params = ('msg' => $self->{msg});
    return EBox::Html::makeHtml($filename, @params);
}

sub _body
{
    my ($self) = @_;
    if (not defined $self->{template}) {
        return;
    } elsif ($self->{wrongReferer}) {
        delete $self->{wrongReferer};
        return;
    }

    my $filename = $self->{template};
    if (-f (EBox::Config::templates() . "/$filename.custom")) {
        # Check signature
        if (EBox::Util::GPG::checkSignature("$filename.custom")) {
            $filename = "$filename.custom";
            EBox::info("Using custom $filename");
        } else {
            EBox::warn("Invalid signature in $filename");
        }

    }
    return EBox::Html::makeHtml($filename, @{ $self->{params} });
}

sub _footer
{
}

sub _openDivContent
{
    return  "<div id=\"content\">\n";
}

sub _closeDivContent
{
    return  "</div>\n";
}

sub _print
{
    my ($self) = @_;

    my $json = $self->{json};
    if ($json) {
        $self->JSONReply($json);
        return;
    }

    my $output = '';
    my @printMethods = qw(
                             _header
                             _top
                             _menu
                             _openDivContent
                             _title
                             _error
                             _msg
                             _body
                             _closeDivContent
                             _footer
                        ) ;
    foreach my $method (@printMethods) {
        try {
            my $sectionOutput = $self->$method();
            $output .= $sectionOutput if $sectionOutput;
        } catch (EBox::Exceptions::Internal $e) {
            my $response = $self->response();
            $response->redirect('/SysInfo/ComponentNotFound');
            return;
        } catch (EBox::Exceptions::External $e) {
            EBox::error("Error printing method section $method");
            $output .= $self->_format_error("$e");
        };
    }

    my $response = $self->response();
    $response->body($output);
}

# alternative print for request runs in popup
# it has been to explicitly called instead of
# the regular print. For example, overlaoding print and calling this
sub _printPopup
{
    my ($self) = @_;

    my $json = $self->{json};
    if ($json) {
        $self->JSONReply($json);
        return;
    }

    my $response = $self->response();
    $response->content_type('text/html; charset=utf-8');

    my $error = $self->_error;
    my $msg = $self->_msg;
    my $body = $self->_body;

    my $output = '';
    $output .= '<div>';
    $output .= $error if ($error);
    $output .= $msg if ($msg);
    $output .= $body if ($body);
    $output .= '</div>';

    utf8::encode($output);
    $response->body($output);
}

sub _checkForbiddenChars
{
    my ($self, $value) = @_;
    POSIX::setlocale(LC_ALL, EBox::locale());

    unless ( $value =~ m{^[\w /.?&+:\-\@,=\{\}]*$} ) {
        my $logger = EBox::logger;
        $logger->info("Invalid characters in param value $value.");
        $self->{error} ='The input contains invalid characters';
        throw EBox::Exceptions::External(__("The input contains invalid " .
            "characters. All alphanumeric characters, plus these non " .
           "alphanumeric chars: ={},/.?&+:-\@ and spaces are allowed."));
        if (defined($self->{redirect})) {
            $self->{chain} = $self->{redirect};
        }
        return undef;
    }
    no locale;
}

sub _loggedIn
{
    my $self = shift;
    # TODO
    return 1;
}

# arguments
#   - name of the required parameter
#   - display name for the parameter (as seen by the user)
sub _requireParam # (param, display)
{
    my ($self, $param, $display) = @_;

    unless (defined($self->unsafeParam($param)) && $self->unsafeParam($param) ne "") {
        $display or
            $display = $param;
        throw EBox::Exceptions::DataMissing(data => $display);
    }
}

# arguments
#   - name of the required parameter
#   - display name for the parameter (as seen by the user)
sub _requireParamAllowEmpty # (param, display)
{
    my ($self, $param, $display) = @_;

    foreach my $reqParam (@{$self->params}){
        return if ($reqParam =~ /^$param$/);
    }

    throw EBox::Exceptions::DataMissing(data => $display);
}

sub run
{
    my ($self) = @_;

    if (not $self->_loggedIn) {
        $self->{redirect} = "/Login/Index";
    } else {
        try {
            $self->_validateReferer();
            $self->_process();
        } catch (EBox::Exceptions::WrongHTTPReferer $e) {
            $self->setErrorFromException($e);
            $self->{wrongReferer} = 1;
        } catch (EBox::Exceptions::External $e) {
            $self->setErrorFromException($e);
            if (defined($self->{redirect})) {
                $self->{chain} = $self->{redirect};
            }
        }
    }

    my $request = $self->request();
    if (defined($self->{error})) {
        #only keep the parameters in paramsKept
        my $reqParam = $request->parameters();
        my $params = $self->params;
        foreach my $param (@{$params}) {
            unless (grep /^$param$/, @{$self->{paramsKept}}) {
                $reqParam->remove($param);
            }
        }
        if (defined($self->{errorchain})) {
            if ($self->{errorchain} ne "") {
                $self->{chain} = $self->{errorchain};
            }
        }
    }

    if (defined($self->{chain})) {
        my $classname = EBox::CGI::Run->urlToClass($self->{chain});
        if (not $self->isa($classname)) {
            eval "use $classname";
            if ($@) {
                throw EBox::Exceptions::Internal("Cannot load $classname. Error: $@");
            }
            my $chain = $classname->new('error' => $self->{error},
                                        'msg' => $self->{msg},
                                        'cgi' => $self->{cgi},
                                        'request' => $self->{request});
            $chain->run();
            $self->setResponse($chain->response());
            return;
        }
    }

    my $response = $self->response();
    if (defined ($self->{redirect}) and not defined ($self->{error})) {
        my $referer = $request->referer();

        my ($protocol, $port);
        my $url;
        my $host = $request->env->{HTTP_HOST};
        if ($referer) {
            my $parsedURL = new URI($referer);
            $protocol = $parsedURL->scheme();
            $port = $parsedURL->port();
            $url = "$protocol://${host}";
            if ($port and not ($host =~ /:/)) {
                $url .= ":$port";
            }
            $url .= "/$self->{redirect}";
        } else {
            $protocol = $request->scheme();
            $url = "$protocol://${host}/" . $self->{redirect};
        }

        $response->redirect($url);
        return;
    }

    try  {
        $self->_print();
    } catch (EBox::Exceptions::Base $e) {
        $self->setErrorFromException($e);
        $self->_format_error($self->{error});
    } catch ($e) {
        if (isa_mason_exception($e)) {
            throw EBox::Exceptions::Internal($e->as_text());
        } else {
            # will be logged in EBox::CGI::Run
            my $ex = new EBox::Exceptions::Error($e);
            $ex->throw();
        }
    }
}

# Method: unsafeParam
#
#     Get the request parameter value in an unsafe way allowing all
#     character
#
#     This is a security risk and it must be used with caution
#
# Parameters:
#
#     param - String the parameter's name to get the value from
#
# Returns:
#
#     string - the parameter's value without any security check if the
#     context is scalar
#
#     array - containing the string values for the given parameter if
#     the context is an array
#
sub unsafeParam # (param)
{
    my ($self, $param) = @_;
    my $request = $self->request();
    my $parameters = $request->parameters();

    my @array;
    my $scalar;
    if (wantarray) {
        @array = $parameters->get_all($param);
        return () unless (@array);
        foreach my $v (@array) {
            utf8::decode($v);
        }
        return @array;
    } else {
        $scalar = $parameters->{$param};
        #check if $param.x exists for input type=image
        unless (defined $scalar) {
            $scalar = $parameters->{$param . ".x"};
        }
        return undef unless (defined $scalar);
        utf8::decode($scalar);
        return $scalar;
    }
}

# Method: param
#
#     Get the request parameter value and sanitize it. It should be safe to used given it passed data validation.
#
# Parameters:
#
#     param - String the parameter's name to get the value from
#
# Returns:
#
#     string - the parameter's value that passed security check if the
#     context is scalar
#
#     array - containing the string values for the given parameter if
#     the context is an array
#
sub param # (param)
{
    my ($self, $param) = @_;

    if (wantarray) {
        my @unsafeValue = $self->unsafeParam($param);
        return () unless (@unsafeValue);
        my @ret = ();
        foreach my $v (@unsafeValue) {
            $v =~ s/\t/ /g;
            $v =~ s/^ +//;
            $v =~ s/ +$//;
            $self->_checkForbiddenChars($v);
            push(@ret, $v);
        }
        return @ret;
    } else {
        my $scalar = $self->unsafeParam($param);
        return undef unless (defined $scalar);
        $scalar =~ s/\t/ /g;
        $scalar =~ s/^ +//;
        $scalar =~ s/ +$//;
        $self->_checkForbiddenChars($scalar);
        return $scalar;
    }
}

# Method: params
#
#      Get the request parameters
#
# Returns:
#
#      array ref - containing the request parameters
#
sub params
{
    my ($self) = @_;

    my $request = $self->request();
    my $parameters = $request->parameters();
    my @names = keys %{$parameters};

    # Prototype adds a '_' empty param to Ajax POST requests when the agent is
    # webkit based
    @names = grep { !/^_$/ } @names;

    foreach (@names) {
        $self->_checkForbiddenChars($_);
    }

    return \@names;
}

sub keepParam # (param)
{
    my ($self, $param) = @_;
    push(@{$self->{paramsKept}}, $param);
}

sub request
{
    my ($self) = @_;

    return $self->{request};
}

# Method: response
#
# Returns:
#
#    <Plack::Response> - the response from this handler. If there is
#                        none, then a new response is created with 200
#                        as status code based on the handler request.
sub response
{
    my ($self) = @_;

    unless ($self->{response}) {
        $self->{response} = $self->request()->new_response(200);
    }
    return $self->{response};
}

# Method: setResponse
#
#     Set a new response for the handler
#
# Parameters:
#
#     newResponse - <Plack::Response> the new response for this
#                   handler
#
# Exceptions:
#
#     <EBox::Exceptions::MissingArgument> - thrown if the newResponse
#     is not passed
#
sub setResponse
{
    my ($self, $newResponse) = @_;

    unless ($newResponse) {
        throw EBox::Exceptions::MissingArgument('newResponse');
    }

    $self->{response} = $newResponse;
}

# Method: user
#
#   Return the logged in user
#
# Returns:
#   string - The user logged in the webadmin or undef.
#
sub user
{
    my ($self) = @_;

    my $request = $self->request();
    my $session = $request->session();
    if (exists $session->{user_id}) {
        return $session->{user_id};
    } else {
        return undef;
    }
}

sub cgi
{
    my $self = shift;
    return $self->{cgi};
}

# Method: setTemplate
#   set the html template used by the request. The template can also be set in the constructor/
#
# Parameters:
#   $template - the template path relative to the template root
#
# See also:
#    new
sub setTemplate
{
    my ($self, $template) = @_;
    $self->{template} = $template;
}

# Method: _process
#
#   Process the request
#
# Default behaviour:
#
#   The default behaviour is intended to standarize and ease some common
#   operations so do not override it except for backward compability or special
#   reasons.
#   The default behaviour validate the peresence or absence or request parameters
#   using requiredParameters and optionalParameters method, then it calls the
#   method actuate, where the functionality of request resides,  and finally uses
#   masonParameters to get the parameters needed by the html template
#   invocation.
sub _process
{
    my ($self) = @_;

    $self->_validateParams();
    $self->actuate();
    $self->{params} = $self->masonParameters();
}

# Method: setMsg
#   sets the message attribute
#
# Parameters:
#   $msg - message to be setted
sub setMsg
{
    my ($self, $msg) = @_;
    $self->{msg} = $msg;
}

# Method: setError
#   set the error message
#
# Parameters:
#   $error - message to be setted
sub setError
{
    my ($self, $error) = @_;
    $self->{error} = $error;
}

# Method: setErrorFromException
#
#    Set the error message using the description value found in the exception
#
# Parameters:
#
#    ex - exception used to set the error attribute
#
sub setErrorFromException
{
    my ($self, $ex) = @_;

    my $dump = EBox::Config::boolean('dump_exceptions');
    if ($dump) {
        if ($ex->can('stringify')) {
            $self->{error} = $ex->stringify();
        } else {
            $self->{error} = "$ex";
        }

        $self->{error} .= "<br/>\n";
        $self->{error} .= "<pre>\n";
        if ($ex->isa('HTML::Mason::Exception')) {
            $self->{error} .= $ex->as_text();
        } elsif ($ex->can('stacktrace')) {
            $self->{error} .= $ex->stacktrace();
        } else {
            $self->{error} .= __('No trace available for this error');
        }
        $self->{error} .= "</pre>\n";
        $self->{error} .= "<br/>\n";

        return;
    }

    if ($ex->isa('EBox::Exceptions::External')) {
        $self->{error} = $ex->stringify();
        return;
    }

    if ($ex->isa('EBox::Exceptions::Internal')) {
        $self->{error} = __("An internal error has ".
                "occurred. This is most probably a ".
                "bug, relevant information can be ".
                "found in the logs.");
    } elsif ($ex->isa('EBox::Exceptions::Base')) {
        $self->{error} = __("An unexpected internal ".
                "error has occurred. This is a bug, ".
                "relevant information can be found ".
                "in the logs.");
    } else {
        $self->{error} = __('Sorry, you have just hit a bug in Zentyal.');
        EBox::error($ex);
    }

    my $reportHelp = __x('Please look for the details in the {f} file and take a minute to {oh}submit a bug report{ch} so we can fix the issue as soon as possible.',
                         f => '/var/log/zentyal/zentyal.log', oh => '<a href="https://tracker.zentyal.org/projects/zentyal/issues/new">', ch => '</a>');
    $self->{error} .= " $reportHelp";
}

# Method: setRedirect
#
#   Sets the redirect attribute. If redirect is set to some value, the parent class will do an HTTP redirect after
#   the _process method returns.
#
#   An HTTP redirect makes the browser issue a new HTTP request, so all the status data in the old request gets lost,
#   but there are cases when you want to keep that data for the new request. This could be done using the setChain
#   method instead.
#
#   When an error happens you don't want redirects at all, as the error message would be lost. If an error happens
#   and redirect has been set, then that value is used as if it was chain.
#
# Parameters:
#   $redirect - value for the redirect attribute
#
# See also:
#  setRedirect, setErrorchain
#
sub setRedirect
{
    my ($self, $redirect) = @_;
    $self->{redirect} = $redirect;
}

# Method: setChain
#
#   Set the chain attribute. It works exactly the same way as redirect attribute but instead of sending an HTTP
#   response to the browser, the parent class parses the url, instantiates the matching request, copies all data into
#   it and runs it. Messages and errors are copied automatically, the parameters in the HTTP request are not, since
#   an error caused by one of them could propagate to the next request.
#
#   If you need to keep HTTP parameters you can use the keepParam method in the parent class. It takes the name of
#   the parameter as an argument and adds it to the list of parameters that will be copied to the new request if a
#   "chain" is performed.
#
# Parameters:
#   $chain - value for the chain attribute
#
# See also:
#  setRedirect, setErrorchain, keepParam
#
sub setChain
{
    my ($self, $chain) = @_;
    $self->{chain} = $chain;
}

# Method: setErrorchain
#
#   Set the errorchain attribute. Sometimes you want to chain to a different request if there is an error, for
#   example if the cause of the error is the absence of an input parameter necessary to show the page. If that's the
#   case you can set the errorchain attribute, which will have a higher priority than chain and redirect if there's
#   an error.
#
# Parameters:
#   $errorchain - value for the errorchain attribute
#
# See also:
#  setChain, setRedirect
#
sub setErrorchain
{
    my ($self, $errorchain) = @_;
    $self->{errorchain} = $errorchain;
}

# Method: paramsAsHash
#
# Returns: a reference to a hash which contains the request parameters and
#    its values as keys and values of the hash
#
# Possible implentation improvements:
#  maybe it will be good idea cache this in some field of the instance
#
# Warning:
#   there is not unsafe parameters check there, do it by hand if you need it
sub paramsAsHash
{
    my ($self) = @_;

    my @names = @{ $self->params() };
    my %params = map {
      my $value =  $self->unsafeParam($_);
      $_ => $value
    } @names;

    return \%params;
}

# Method: redirectOnNoParams
#
# If this method return a true value, it will be used as path to redirection in
# case the CGI has no parameters. This is needed in some CGIs to avoid accidentally
# call them on page reloads
#
# By default it returns undef and thus has not effect
sub redirectOnNoParams
{
    return undef;
}

sub _validateParams
{
    my ($self) = @_;
    my $params_r    = $self->params();
    if (not @{$params_r }) {
        my $redirect = $self->redirectOnNoParams();
        if ($redirect) {
            # no check becuase we will redirect
            $self->{redirect} = $redirect;
            return 1;
        }
    }

    $params_r       = $self->_validateRequiredParams($params_r);
    $params_r       = $self->_validateOptionalParams($params_r);

    my @paramsLeft = @{ $params_r };
    if (@paramsLeft) {
        EBox::error("Unallowed parameters found in the request: @paramsLeft");
        throw EBox::Exceptions::External( __('Your request could not be processed because it had some incorrect parameters'));
    }

    return 1;
}

sub _validateReferer
{
    my ($self) = @_;

    # Only check if the client sends params that can trigger actions
    # It is assumed that the meaning of the accepted parameters does
    # no change in CGIs
    my $hasActionParam = 0;
    my $noActionParams = any('directory', 'page', 'pageSize', 'backview');
    foreach my $param (@{ $self->params() }) {
        if ($param eq $noActionParams) {
            next;
        } else {
            $hasActionParam = 1;
            last;
        }
    }
    if (not $hasActionParam) {
        return;
    }

    my $request = $self->request();
    my $referer = $request->referer();
    my $hostname = $request->env->{HTTP_HOST};

    my $rshostname = undef;

    if ($referer) {
        # proxy is a valid subdomain of {domain}
        if ($referer =~ m/^https:\/\/$hostname(:[0-9]*)?\//) {
            return; # from another page
        }
    }

    throw EBox::Exceptions::WrongHTTPReferer();
}

sub _validateRequiredParams
{
    my ($self, $params_r) = @_;

    my $matchResult_r = _matchParams($self->requiredParameters(), $params_r);
    my @requiresWithoutMatch = @{ $matchResult_r->{targetsWithoutMatch} };
    if (@requiresWithoutMatch) {
        EBox::error("Mandatory parameters not found in the request: @requiresWithoutMatch");
        throw EBox::Exceptions::External ( __('Your request could not be processed because it lacked some required parameters'));
    } else {
        my $allMatches = all  @{ $matchResult_r->{matches} };
        my @newParams = grep { $_ ne $allMatches } @{ $params_r} ;
        return \@newParams;
    }
}

sub _validateOptionalParams
{
    my ($self, $params_r) = @_;

    my $matchResult_r = _matchParams($self->optionalParameters(), $params_r);

    my $allMatches = all  @{ $matchResult_r->{matches} };
    my @newParams = grep { $_ ne $allMatches } @{ $params_r} ;
    return \@newParams;
}

sub _matchParams
{
    my ($targetParams_r, $actualParams_r) = @_;
    my @targets = @{ $targetParams_r };
    my @actualParams = @{ $actualParams_r};

    my @targetsWithoutMatch;
    my @matchedParams;
    foreach my $targetParam ( @targets ) {
        my $targetRe = qr/^$targetParam$/;
        my @matched = grep { $_ =~ $targetRe } @actualParams;
        if (@matched) {
            push @matchedParams, @matched;
        } else {
            push @targetsWithoutMatch, $targetParam;
        }
    }

    return { matches => \@matchedParams, targetsWithoutMatch => \@targetsWithoutMatch };
}

# Method: optionalParameters
#
#   Get the optional request parameter list. Any parameter that match with this list may be present or absent
#   in the request parameters.
#
# Returns:
#
#       array ref - the list of matching parameters, it may be a names or
#       a regular expression, in the last case it cannot contain the
#       metacharacters ^ and $
#
sub optionalParameters
{
    return [];
}

# Method: requiredParameters
#
#   Get the required request parameter list. Any
#   parameter that match with this list must be present in the request
#   parameters.
#
# Returns:
#
#   array ref - the list of matching parameters, it may be a names
#   or a regular expression, in the last case it can not contain
#   the metacharacters ^ and $
#
sub requiredParameters
{
    return [];
}

# Method:  actuate
#
#   This method is the workhouse of the request it must be overriden by the
#   different request handlers to achieve their objectives
#
sub actuate
{
}

# Method: masonParameters
#
#  This method must be overriden by the different child to return the adequate
#   template parameter for its state.
#
# Returns:
#
#   A reference to a list which contains the names and values of the different
#   mason parameters
#
sub masonParameters
{
    my ($self) = @_;

    if (exists $self->{params}) {
        return $self->{params};
    }

    return [];
}

# Method: setMenuNamespace
#
#   Set the menu namespace to help the menu code to find out
#   within which namespace this request is running.
#
#   Note that, this is useful only if you are using base request handlers
#   in modules different to ebox base. If you do not use this,
#   the namespace used will be the one the base request belongs to.
#
# Parameters:
#
#   (POSITIONAL)
#   namespace - string represeting the namespace in URL format. Example:
#           "EBox/Network"
#
sub setMenuNamespace
{
    my ($self, $namespace) = @_;

    $self->{'menuNamespace'} = $namespace;
}

# Method: menuNamespace
#
#   Return menu namespace to help the menu code to find out
#   within which namespace this request is running.
#
#   Note that, this is useful only if you are using base request handlers
#   in modules different to ebox base. If you do not use this,
#   the namespace used will be the one the base request belongs to.
#
# Returns:
#
#   namespace - string represeting the namespace in URL format. Example:
#           "EBox/Network"
#
sub menuNamespace
{
    my ($self) = @_;

    if (exists $self->{'menuNamespace'}) {
        return $self->{'menuNamespace'};
    } else {
        return $self->{'url'};
    }
}

# Method: JSONReply
#
#     Set the body with JSON-encoded body
#
# Parameters:
#
#     data_r - Hash ref with the data to encode in JSON
#
sub JSONReply
{
    my ($self, $data_r) = @_;

    my $response = $self->response();
    $response->content_type('application/json; charset=utf-8');

    my $error = $self->{error};
    if ($error and not $data_r->{error}) {
        $data_r->{error} = $error;
    }

    $response->body(JSON::XS->new->encode($data_r));
}

1;
