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

use HTML::Mason;
use HTML::Mason::Exceptions;
use CGI;
use EBox::Gettext;
use EBox;
use EBox::Global;
use EBox::CGI::Run;
use EBox::Html;
use EBox::Exceptions::Error;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::MissingArgument;
use EBox::Util::GPG;
use POSIX qw(setlocale LC_ALL);
use TryCatch::Lite;
use Encode qw(:all);
use Data::Dumper;
use Perl6::Junction qw(all);
use File::Temp qw(tempfile);
use File::Basename;
use JSON::XS;

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
        CGI::initialize_globals();
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

sub _print_error # (text)
{
    my ($self, $text) = @_;

    $text or return;
    ($text ne "") or return;
    my $filename = 'error.mas';
    my @params = ('error' => $text);
    my $response = $self->response();
    $response->body(EBox::Html::makeHtml($filename, @params));
}

sub _error #
{
    my ($self) = @_;

    if (defined $self->{olderror}) {
        $self->_print_error($self->{olderror});
    }
    if (defined $self->{error}) {
        $self->_print_error($self->{error});
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
    return unless (defined $self->{template});

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

sub _print
{
    my ($self) = @_;

    my $json = $self->{json};
    if ($json) {
        $self->JSONReply($json);
        return;
    }

    my $header = $self->_header;
    my $top = $self->_top;
    my $menu = $self->_menu;
    my $title = $self->_title;
    my $error = $self->_error;
    my $msg = $self->_msg;
    my $body = $self->_body;
    my $footer = $self->_footer;

    my $output = '';
    $output .= $header if ($header);
    $output .= $top if ($top);
    $output .= $menu if ($menu);
    $output .= "<div id=\"content\">\n";
    $output .= $title if ($title);
    $output .= $error if ($error);
    $output .= $msg if ($msg);
    $output .= $body if ($body);
    $output .= "</div>\n";
    $output .= $footer if ($footer);

    my $response = $self->response();
    $response->body($output);

}

# alternative print for CGI runs in popup
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

    foreach my $cgiparam (@{$self->params}){
        return if ($cgiparam =~ /^$param$/);
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
        } catch (EBox::Exceptions::Internal $e) {
            $e->throw();
        } catch (EBox::Exceptions::Base $e) {
            $self->setErrorFromException($e);
            if (defined($self->{redirect})) {
                $self->{chain} = $self->{redirect};
            }
        } catch ($e) {
            my $ex = new EBox::Exceptions::Error($e);
            $ex->throw();
        }
    }

    if (defined($self->{error})) {
        #only keep the parameters in paramsKept
        my $params = $self->params;
        foreach my $param (@{$params}) {
            unless (grep /^$param$/, @{$self->{paramsKept}}) {
                $self->{cgi}->delete($param);
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
            $chain->run;
            return;
        }
    }

    my $request = $self->request();
    my $response = $self->response();
    if (defined ($self->{redirect}) and not defined ($self->{error})) {
        my $referer = $request->referer();

        my ($protocol, $port);
        my $url;
        my $host = $request->env->{HTTP_HOST};
        if ($> == getpwnam('ebox')) {
            ($protocol, $port) = $referer =~ m{(.+)://.+:(\d+)/};
            $url = "$protocol://${host}";
            if ($port) {
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
        $self->_print_error($self->{error});
    # FIXME: Should we just remove this with Apache's mod_perl code removal?
    #} catch (APR::Error $e) {
    #    my $debug = EBox::Config::boolean('debug');
    #    my $error = $debug ? $e->confess() : $e->strerror();
    #    $self->_print_error($error);
    } catch ($e) {
        my $logger = EBox::logger;
        if (isa_mason_exception($e)) {
            $logger->error($e->as_text);
            my $error = __("An internal error related to ".
                           "a template has occurred. This is ".
                           "a bug, relevant information can ".
                           "be found in the logs.");
            $self->_print_error($error);
        } else {
            # will be logged in EBox::CGI::Run
            my $ex = new EBox::Exceptions::Error($e);
            $ex->throw();
        }
    }
}

# Method: unsafeParam
#
#     Get the CGI parameter value in an unsafe way allowing all
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
    my $cgi = $self->cgi;
    my @array;
    my $scalar;
    if (wantarray) {
        @array = $cgi->param($param);
        (@array) or return undef;
        foreach my $v (@array) {
            utf8::decode($v);
        }
        return @array;
    } else {
        $scalar = $cgi->param($param);
        #check if $param.x exists for input type=image
        unless (defined($scalar)) {
            $scalar = $cgi->param($param . ".x");
        }
        defined($scalar) or return undef;
        utf8::decode($scalar);
        return $scalar;
    }
}

sub param # (param)
{
    my ($self, $param) = @_;
    my $cgi = $self->cgi;
    my @array;
    my $scalar;
    if (wantarray) {
        @array = $cgi->param($param);
        (@array) or return undef;
        my @ret = ();
        foreach my $v (@array) {
            utf8::decode($v);
            $v =~ s/\t/ /g;
            $v =~ s/^ +//;
            $v =~ s/ +$//;
            $self->_checkForbiddenChars($v);
            push(@ret, $v);
        }
        return @ret;
    } else {
        $scalar = $cgi->param($param);
        #check if $param.x exists for input type=image
        unless (defined($scalar)) {
            $scalar = $cgi->param($param . ".x");
        }
        defined($scalar) or return undef;
        utf8::decode($scalar);
        $scalar =~ s/\t/ /g;
        $scalar =~ s/^ +//;
        $scalar =~ s/ +$//;
        $self->_checkForbiddenChars($scalar);
        return $scalar;
    }
}

# Method: params
#
#      Get the CGI parameters
#
# Returns:
#
#      array ref - containing the CGI parameters
#
sub params
{
    my ($self) = @_;

    my $cgi = $self->cgi;
    my @names = $cgi->param;

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

sub response
{
    my ($self) = @_;

    unless ($self->{response}) {
        $self->{response} = $self->request()->new_response(200);
    }
    return $self->{response};
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
    if (exists $env->{'psgix.session'}{user_id}) {
        return $env->{'psgix.session'}{user_id}
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
#   set the html template used by the CGI. The template can also be set in the constructor/
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
#   Process the CGI
#
# Default behaviour:
#
#   The default behaviour is intended to standarize and ease some common
#   operations so do not override it except for backward compability or special
#   reasons.
#   The default behaviour validate the peresence or absence or CGI parameters
#   using requiredParameters and optionalParameters method, then it calls the
#   method actuate, where the functionality of CGI resides,  and finally uses
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
#    set the error message eusing the description value found in a exception
#
# Parameters:
#  $ex - exception used to set the error attributer
sub setErrorFromException
{
    my ($self, $ex) = @_;

    my $dump = EBox::Config::configkey('dump_exceptions');
    if (defined ($dump) and ($dump eq 'yes')) {
        $self->{error} = $ex->stringify() if $ex->can('stringify');
        $self->{error} .= "<br/>\n";
        $self->{error} .= "<pre>\n";
        if ($ex->isa('HTML::Mason::Exception')) {
            $self->{error} .= $ex->as_text();
        } else {
            $self->{error} .= $ex->stacktrace();
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
                         f => '/var/log/zentyal/zentyal.log', oh => '<a href="http://trac.zentyal.org/newticket">', ch => '</a>');
    $self->{error} .= " $reportHelp";
}

# Method: setRedirect
#    sets the redirect attribute. If redirect is set to some value, the parent class will do an HTTP redirect after the _process method returns.
#
# An HTTP redirect makes the browser issue a new HTTP request, so all the status data in the old request gets lost, but there are cases when you want to keep that data for the new CGI. This could be done using the setChain method instead
#
# When an error happens you don't want redirects at all, as the error message would be lost. If an error happens and redirect has been set, then that value is used as if it was chain.
#
# Parameters:
#   $redirect - value for the redirect attribute
#
# See also:
#  setRedirect, setErrorchain
sub setRedirect
{
    my ($self, $redirect) = @_;
    $self->{redirect} = $redirect;
}

# Method: setChain
#    set the chain attribute. It works exactly the same way as redirect attribute but instead of sending an HTTP response to the browser, the parent class parses the url, instantiates the matching CGI, copies all data into it and runs it. Messages and errors are copied automatically, the parameters in the HTTP request are not, since an error caused by one of#  them could propagate to the next CGI.
#
# If you need to keep HTTP parameters you can use the keepParam method in the parent class. It takes the name of the parameter as an argument and adds it to the list of parameters that will be copied to the new CGI if a "chain" is performed.
#
#
# Parameters:
#   $chain - value for the chain attribute
#
# See also:
#  setRedirect, setErrorchain, keepParam
sub setChain
{
    my ($self, $chain) = @_;
    $self->{chain} = $chain;
}

# Method: setErrorchain
#    set the errorchain attribute. Sometimes you want to chain to a different CGI if there is an error, for example if the cause of the error is the absence of an input parameter necessary to show the page. If that's the case you can set the errorchain attribute, which will have a higher priority than chain and redirect if there's an error.
#
# Parameters:
#   $errorchain - value for the errorchain attribute
#
# See also:
#  setChain, setRedirect
sub setErrorchain
{
    my ($self, $errorchain) = @_;
    $self->{errorchain} = $errorchain;
}

# Method: paramsAsHash
#
# Returns: a reference to a hash which contains the CGI parameters and
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

sub _validateParams
{
    my ($self) = @_;
    my $params_r    = $self->params();
    $params_r       = $self->_validateRequiredParams($params_r);
    $params_r       = $self->_validateOptionalParams($params_r);

    my @paramsLeft = @{ $params_r };
    if (@paramsLeft) {
        EBox::error("Unallowed parameters found in CGI request: @paramsLeft");
        throw EBox::Exceptions::External( __('Your request could not be processed because it had some incorrect parameters'));
    }

    return 1;
}

sub _validateReferer
{
    my ($self) = @_;

    # Only check if the client sends params
    unless (@{$self->params()}) {
        return;
    }

    my $request = $self->request();
    my $referer = $request->referer();
    my $hostname = $request->env->{HTTP_HOST};

    my $rshostname = undef;
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        if ( $rs->eBoxSubscribed() ) {
            $rshostname = $rs->cloudDomain();
        }
    }

    # proxy is a valid subdomain of {domain}
    if ($referer =~ m/^https:\/\/$hostname(:[0-9]*)?\//) {
        return; # from another page
    } elsif ($rshostname and ($referer =~ m/^https:\/\/[^\/]*$rshostname(:[0-9]*)?\//)) {
        return; # allow remoteservices proxy access
    }
    throw EBox::Exceptions::External( __("Wrong HTTP referer detected, operation cancelled for security reasons"));
}

sub _validateRequiredParams
{
    my ($self, $params_r) = @_;

    my $matchResult_r = _matchParams($self->requiredParameters(), $params_r);
    my @requiresWithoutMatch = @{ $matchResult_r->{targetsWithoutMatch} };
    if (@requiresWithoutMatch) {
        EBox::error("Mandatory parameters not found in CGI request: @requiresWithoutMatch");
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
#       Get the optional CGI parameter list. Any
#   parameter that match with this list may be present or absent
#   in the CGI parameters.
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
#   Get the required CGI parameter list. Any
#   parameter that match with this list must be present in the CGI
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
#   This method is the workhouse of the CGI it must be overriden by the
#   different CGIs to achieve their objectives
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

# Method: upload
#
#  Upload a file from the client computer. The file is place in
#  the tmp directory (/tmp)
#
#
# Parameters:
#
#   uploadParam - String CGI parameter name which contains the path to the
#   file which will be uploaded. It is usually obtained from a HTML
#   file input
#
# Returns:
#
#   String - the path of the uploaded file
#
# Exceptions:
#
#   <EBox::Exceptions::Internal> - thrown if an error has happened
#   within the CGI or it is impossible to read the upload file or the
#   parameter does not pass on the request
#
#   <EBox::Exceptions::External> - thrown if there is no file to
#   upload or cannot create the temporally file
#
sub upload
{
    my ($self, $uploadParam) = @_;
    defined $uploadParam or throw EBox::Exceptions::MissingArgument();

    # upload parameter..
    my $uploadParamValue = $self->cgi->param($uploadParam);
    if (not defined $uploadParamValue) {
        if ($self->cgi->cgi_error) {
            throw EBox::Exceptions::Internal('Upload error: ' . $self->cgi->cgi_error);
        }
        throw EBox::Exceptions::Internal("The upload parameter $uploadParam does not "
                . 'pass on HTTP request');
    }

    # get upload contents file handle
    my $UPLOAD_FH = $self->cgi->upload($uploadParam);
    if (not $UPLOAD_FH) {
        throw EBox::Exceptions::External( __('Invalid uploaded file.'));
    }

    # destination file handle and path
    my ($FH, $filename) = tempfile("uploadXXXXX", DIR => EBox::Config::tmp());
    if (not $FH) {
        throw EBox::Exceptions::External( __('Cannot create a temporally file for the upload'));
    }

    try {
        #copy the uploaded data to file..
        my $readStatus;
        my $readData;
        my $readSize = 1024 * 8; # read in blocks of 8K
            while ($readStatus = read $UPLOAD_FH, $readData, $readSize) {
                print $FH $readData;
            }

        if (not defined $readStatus) {
            throw EBox::Exceptions::Internal("Error reading uploaded data: $!");
        }
    } catch ($e) {
        unlink $filename;
        close $UPLOAD_FH;
        close $FH;
        $e->throw();
    }
    close $UPLOAD_FH;
    close $FH;

    # return the created file in tmp
    return $filename;
}

# Method: setMenuNamespace
#
#   Set the menu namespace to help the menu code to find out
#   within which namespace this cgi is running.
#
#   Note that, this is useful only if you are using base CGIs
#   in modules different to ebox base. If you do not use this,
#   the namespace used will be the one the base cgi belongs to.
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
#   within which namespace this cgi is running.
#
#   Note that, this is useful only if you are using base CGIs
#   in modules different to ebox base. If you do not use this,
#   the namespace used will be the one the base cgi belongs to.
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

sub JSONReply
{
    my ($self, $data_r) = @_;

    my $response = $self->response();
    $response->content_type('application/JSON; charset=utf-8');

    my $error = $self->{error};
    if ($error and not $data_r->{error}) {
        $data_r->{error} = $error;
    }

    $response->body(JSON::XS->new->encode($data_r));
}

1;
