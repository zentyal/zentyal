package EBox::ThirdParty::Apache2::AuthCookie;

use strict;

use Carp;
use CGI '3.12';
use mod_perl2 '1.9922';

use EBox::ThirdParty::Apache2::AuthCookie::Util;
use Apache2::RequestRec;
use Apache2::RequestUtil;
use Apache2::Log;
use Apache2::Access;
use Apache2::Response;
use Apache2::Util;
use APR::Table;
use Apache2::Const qw(:common M_GET HTTP_FORBIDDEN HTTP_MOVED_TEMPORARILY);
use vars qw($VERSION);

# $Id: AuthCookie.pm 227 2008-04-16 14:59:56Z mschout $
$VERSION = '3.12';

sub recognize_user {
    my ($self, $r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    my $auth_type = $r->auth_type;
    my $auth_name = $r->auth_name;

    return DECLINED unless $auth_type and $auth_name;

    return DECLINED unless $r->headers_in->get('Cookie');

    my $cookie = $self->key($r);
    my $cookie_name = $self->cookie_name($r);

    $r->server->log_error("cookie $cookie_name is $cookie")
        if $debug >= 2;

    return DECLINED unless $cookie;

    my ($user,@args) = $auth_type->authen_ses_key($r, $cookie);

    if ($user and scalar @args == 0) {
        $r->server->log_error("user is $user") if $debug >= 2;

        # send cookie with update expires timestamp if session timeout is on
        if (my $expires = $r->dir_config("${auth_name}SessionTimeout")) {
            $self->send_cookie($r, $cookie, {expires => $expires});
        }

        $r->user($user);
    }
    elsif (scalar @args > 0 and $auth_type->can('custom_errors')) {
        return $auth_type->custom_errors($r, $user, @args);
    }

    return OK;
}

sub cookie_name {
    my ($self, $r) = @_;

    my $auth_type = $r->auth_type;
    my $auth_name = $r->auth_name;

    my $cookie_name = $r->dir_config("${auth_name}CookieName") ||
                      "${auth_type}_${auth_name}";

    return $cookie_name;
}

sub handle_cache {
    my ($self, $r) = @_;

    my $auth_name = $r->auth_name;

    return unless $auth_name;

    unless ($r->dir_config("${auth_name}Cache")) {
        $r->no_cache(1);
        $r->err_headers_out->set(Pragma => 'no-cache');
    }
}

sub remove_cookie {
    my ($self, $r) = @_;

    my $cookie_name = $self->cookie_name($r);

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    my $str = $self->cookie_string(
        request => $r,
        key     => $cookie_name,
        value   => '',
        expires => 'Mon, 21-May-1971 00:00:00 GMT'
    );

    $r->err_headers_out->add("Set-Cookie" => "$str");
    $r->server->log_error("removed_cookie ".
                          $r->err_headers_out->get("Set-Cookie"))
        if $debug >= 2;
}

# convert current request to GET
sub _convert_to_get {
    my ($self, $r, $args) = @_;

    return unless $r->method eq 'POST';

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    $r->server->log_error("Converting POST -> GET") if $debug >= 2;

    my @pairs =();
    while (my ($name, $value) = each %$args) {
        # we dont want to copy login data, only extra data
        next if $name eq 'destination'
             or $name =~ /^credential_\d+$/;

        $value = '' unless defined $value;
        for my $v (split /\0/, $value) {
            push @pairs, escape_uri($r, $name) . '=' . escape_uri($r, $v);
        }
    }

    $r->args(join '&', @pairs) if scalar(@pairs) > 0;

    $r->method('GET');
    $r->method_number(M_GET);
    $r->headers_in->unset('Content-Length');
}

sub escape_uri {
    my ($r, $string) = @_;
    return EBox::ThirdParty::Apache2::AuthCookie::Util::escape_path($string, $r->pool);
}

# get GET or POST data and return hash containing the data.
sub _get_form_data {
    my ($self, $r) = @_;

    my $data = '';

    my $cgi = CGI->new($r);

    return $cgi->Vars();
}

sub login {
    my ($self, $r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    my $auth_type = $r->auth_type;
    my $auth_name = $r->auth_name;

    my %args = $self->_get_form_data($r);

    if ($r->method eq 'POST') {
        $self->_convert_to_get($r, \%args);
    }

    unless (exists $args{'destination'}) {
        $r->server->log_error("No key 'destination' found in form data");
        $r->subprocess_env('AuthCookieReason', 'no_cookie');
        return $auth_type->login_form($r);
    }

    # Get the credentials from the data posted by the client
    my @credentials;
    for (my $i = 0; exists $args{"credential_$i"}; $i++) {
        my $key = "credential_$i";
        $r->server->log_error("$key $args{$key}") if $debug >= 2;
        push @credentials, $args{$key};
    }

    # save creds in pnotes so login form script can use them if it wants to
    $r->pnotes("${auth_name}Creds", \@credentials);

    # Exchange the credentials for a session key.
    my $ses_key = $self->authen_cred($r, @credentials);
    unless ($ses_key) {
        $r->server->log_error("Bad credentials") if $debug >= 2;
        $r->subprocess_env('AuthCookieReason', 'bad_credentials');
        $r->uri($args{'destination'});
        return $auth_type->login_form($r);
    }

    if ($debug >= 2) {
        defined $ses_key ? $r->server->log_error("ses_key $ses_key")
                         : $r->server->log_error("ses_key undefined");
    }

    $self->send_cookie($r, $ses_key);

    $self->handle_cache($r);

    if ($debug >= 2) {
        $r->server->log_error("redirect to $args{destination}");
    }

    $r->headers_out->set(
        "Location" => $self->untaint_destination($args{'destination'}));

    return HTTP_MOVED_TEMPORARILY;
}

sub untaint_destination {
    my ($self, $dest) = @_;

    return EBox::ThirdParty::Apache2::AuthCookie::Util::escape_destination($dest);
}

sub logout {
    my ($self,$r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    $self->remove_cookie($r);

    $self->handle_cache($r);
}

sub authenticate {
    my ($auth_type, $r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    $r->server->log_error("auth_type " . $auth_type) if ($debug >= 3);

    unless ($r->is_initial_req) {
        if (defined $r->prev) {
            # we are in a subrequest.  Just copy user from previous request.
            $r->user( $r->prev->user );
        }
        return OK;
    }

    if ($debug >= 3) {
        $r->server->log_error("r=$r authtype=". $r->auth_type);
    }

    if ($r->auth_type ne $auth_type) {
        # This location requires authentication because we are being called,
        # but we don't handle this AuthType.
        $r->server->log_error("AuthType mismatch: $auth_type =/= ".$r->auth_type) if $debug >= 3;
        return DECLINED;
    }

    # Ok, the AuthType is $auth_type which we handle, what's the authentication
    # realm's name?
    my $auth_name = $r->auth_name;
    $r->server->log_error("auth_name $auth_name") if $debug >= 2;
    unless ($auth_name) {
        $r->server->log_error("AuthName not set, AuthType=$auth_type", $r->uri);
        return SERVER_ERROR;
    }

    # Get the Cookie header. If there is a session key for this realm, strip
    # off everything but the value of the cookie.
    my $ses_key_cookie = $auth_type->key($r) || '';

    $r->server->log_error("ses_key_cookie " . $ses_key_cookie) if $debug >= 1;
    $r->server->log_error("uri " . $r->uri) if $debug >= 2;

    if ($ses_key_cookie) {
        my ($auth_user, @args) = $auth_type->authen_ses_key($r, $ses_key_cookie);

        if ($auth_user and scalar @args == 0) {
            # We have a valid session key, so we return with an OK value.
            # Tell the rest of Apache what the authentication method and
            # user is.

            $r->ap_auth_type($auth_type);
            $r->user($auth_user);
            $r->server->log_error("user authenticated as $auth_user")
                if $debug >= 1;

            # send new cookie if SessionTimeout is on
            if (my $expires = $r->dir_config("${auth_name}SessionTimeout")) {
                $auth_type->send_cookie($r, $ses_key_cookie,
                                        {expires => $expires});
            }

            return OK;
        }
        elsif (scalar @args > 0 and $auth_type->can('custom_errors')) {
            return $auth_type->custom_errors($r, $auth_user, @args);
        }
        else {
            # There was a session key set, but it's invalid for some reason. So,
            # remove it from the client now so when the credential data is posted
            # we act just like it's a new session starting.
            $auth_type->remove_cookie($r);
            $r->subprocess_env('AuthCookieReason', 'bad_cookie');
        }
    }
    else {
        $r->subprocess_env('AuthCookieReason', 'no_cookie');
    }

    # This request is not authenticated, but tried to get a protected
    # document.  Send client the authen form.
    return $auth_type->login_form($r);
}

sub login_form {
    my ($self, $r) = @_;

    my $auth_name = $r->auth_name;

    my %args = $self->_get_form_data($r);

    if ($r->method eq 'POST') {
        $self->_convert_to_get($r, \%args);
    }

    # There should be a PerlSetVar directive that gives us the URI of
    # the script to execute for the login form.

    my $authen_script;
    unless ($authen_script = $r->dir_config($auth_name . "LoginScript")) {
        $r->server->log_error("PerlSetVar '${auth_name}LoginScript' not set", $r->uri);
        return SERVER_ERROR;
    }

    $r->custom_response(HTTP_FORBIDDEN, $authen_script);

    return HTTP_FORBIDDEN;
}

sub satisfy_is_valid {
    my ($auth_type, $r, $satisfy) = @_;

    $satisfy = lc $satisfy;

    if ($satisfy eq 'any' or $satisfy eq 'all') {
        return 1;
    }
    else {
        my $auth_name = $r->auth_name;
        $r->server->log_error("PerlSetVar ${auth_name}Satisfy $satisfy invalid",$r->uri);
        return 0;
    }
}

sub get_satisfy {
    my ($auth_type, $r) = @_;

    my $auth_name = $r->auth_name;

    return lc $r->dir_config("${auth_name}Satisfy") || 'all';
}

sub authorize {
    my ($auth_type, $r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    $r->server->log_error('authorize() for '.$r->uri()) if $debug >= 3;

    return OK unless $r->is_initial_req; #only the first internal request

    if ($r->auth_type ne $auth_type) {
        $r->server->log_error("auth type mismatch $auth_type != ".$r->auth_type)
            if $debug >= 3;
        return DECLINED;
    }

    my $reqs_arr = $r->requires or return DECLINED;

    my $user = $r->user;

    $r->server->log_error("authorize user=$user type=$auth_type") if $debug >=3;

    unless ($user) {
        # user is either undef or =0 which means the authentication failed
        $r->server->log_error("No user authenticated", $r->uri);
        return HTTP_FORBIDDEN;
    }

    my $satisfy = $auth_type->get_satisfy($r);
    return SERVER_ERROR unless $auth_type->satisfy_is_valid($r,$satisfy);
    my $satisfy_all = $satisfy eq 'all';

    my ($forbidden);
    foreach my $req (@$reqs_arr) {
        my ($requirement, $args) = split /\s+/, $req->{requirement}, 2;
        $args = '' unless defined $args;
        $r->server->log_error("requirement := $requirement, $args") if $debug >= 2;

        if (lc($requirement) eq 'valid-user') {
            if ($satisfy_all) {
                next;
            }
            else {
                return OK;
            }
        }

        if ($requirement eq 'user') {
            if ($args =~ m/\b$user\b/) {
                next if $satisfy_all;
                return OK; # satisfy any
            }

            $forbidden = 1;
            next;
        }

        # Call a custom method
        my $ret_val = $auth_type->$requirement($r, $args);
        $r->server->log_error("$auth_type->$requirement returned $ret_val") if $debug >= 3;
        if ($ret_val == OK) {
            next if $satisfy_all;
            return OK; # satisfy any
        }

        # Nothing succeeded, deny access to this user.
        $forbidden = 1;
    }

    return $forbidden ? HTTP_FORBIDDEN : OK;
}

sub send_cookie {
    my ($self, $r, $ses_key, $cookie_args) = @_;

    $cookie_args = {} unless defined $cookie_args;

    my $cookie_name = $self->cookie_name($r);

    my $cookie = $self->cookie_string(
        request => $r,
        key     => $cookie_name,
        value   => $ses_key,
        %$cookie_args
    );

    my $auth_name = $r->auth_name;

    # add a P3P header if user has configured it.
    if (my $p3p = $r->dir_config("${auth_name}P3P")) {
        $r->err_headers_out->set(P3P => $p3p);
    }

    $r->err_headers_out->add("Set-Cookie" => $cookie);
}


# cookie_string takes named parameters:
#    request
#    key
#    value
#    expires
#
sub cookie_string {
    my $self = shift;
    my %p = @_;
    for (qw/request key/) {
        croak "missing required parameter $_" unless defined $p{$_};
    }
    # its okay if value is undef here.

    my $r = $p{request};

    $p{value} = '' unless defined $p{value};

    my $string = sprintf '%s=%s', @p{'key','value'};

    my $auth_name = $r->auth_name;

    if (my $expires = $p{expires} || $r->dir_config("${auth_name}Expires")) {
        $expires = EBox::ThirdParty::Apache2::AuthCookie::Util::expires($expires);
        $string .= "; expires=$expires";
    }

    $string .= '; path=' . ( $self->get_cookie_path($r) || '/' );

    if (my $domain = $r->dir_config("${auth_name}Domain")) {
        $string .= "; domain=$domain";
    }

    if ($r->dir_config("${auth_name}Secure")) {
        $string .= '; secure';
    }

    # HttpOnly is an MS extension.  See
    # http://msdn.microsoft.com/workshop/author/dhtml/httponly_cookies.asp
    if ($r->dir_config("${auth_name}HttpOnly")) {
        $string .= '; HttpOnly';
    }

    return $string;
}

sub key {
    my ($self, $r) = @_;

    my $cookie_name = $self->cookie_name($r);

    my $allcook = ($r->headers_in->get("Cookie") || "");

    return ($allcook =~ /(?:^|\s)$cookie_name=([^;]*)/)[0];
}

sub get_cookie_path {
    my ($self, $r) = @_;

    my $auth_name = $r->auth_name;

    return $r->dir_config("${auth_name}Path");
}

1;
package EBox::ThirdParty::Apache2::AuthCookie;

use strict;

use Carp;
use CGI '3.12';
use mod_perl2 '1.9922';

use EBox::ThirdParty::Apache2::AuthCookie::Util;
use Apache2::RequestRec;
use Apache2::RequestUtil;
use Apache2::Log;
use Apache2::Access;
use Apache2::Response;
use Apache2::Util;
use APR::Table;
use Apache2::Const qw(:common M_GET HTTP_FORBIDDEN HTTP_MOVED_TEMPORARILY);
use vars qw($VERSION);

# $Id: AuthCookie.pm 227 2008-04-16 14:59:56Z mschout $
$VERSION = '3.12';

sub recognize_user {
    my ($self, $r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    my $auth_type = $r->auth_type;
    my $auth_name = $r->auth_name;

    return DECLINED unless $auth_type and $auth_name;

    return DECLINED unless $r->headers_in->get('Cookie');

    my $cookie = $self->key($r);
    my $cookie_name = $self->cookie_name($r);

    $r->server->log_error("cookie $cookie_name is $cookie")
        if $debug >= 2;

    return DECLINED unless $cookie;

    my ($user,@args) = $auth_type->authen_ses_key($r, $cookie);

    if ($user and scalar @args == 0) {
        $r->server->log_error("user is $user") if $debug >= 2;

        # send cookie with update expires timestamp if session timeout is on
        if (my $expires = $r->dir_config("${auth_name}SessionTimeout")) {
            $self->send_cookie($r, $cookie, {expires => $expires});
        }

        $r->user($user);
    }
    elsif (scalar @args > 0 and $auth_type->can('custom_errors')) {
        return $auth_type->custom_errors($r, $user, @args);
    }

    return OK;
}

sub cookie_name {
    my ($self, $r) = @_;

    my $auth_type = $r->auth_type;
    my $auth_name = $r->auth_name;

    my $cookie_name = $r->dir_config("${auth_name}CookieName") ||
                      "${auth_type}_${auth_name}";

    return $cookie_name;
}

sub handle_cache {
    my ($self, $r) = @_;

    my $auth_name = $r->auth_name;

    return unless $auth_name;

    unless ($r->dir_config("${auth_name}Cache")) {
        $r->no_cache(1);
        $r->err_headers_out->set(Pragma => 'no-cache');
    }
}

sub remove_cookie {
    my ($self, $r) = @_;

    my $cookie_name = $self->cookie_name($r);

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    my $str = $self->cookie_string(
        request => $r,
        key     => $cookie_name,
        value   => '',
        expires => 'Mon, 21-May-1971 00:00:00 GMT'
    );

    $r->err_headers_out->add("Set-Cookie" => "$str");
    $r->server->log_error("removed_cookie ".
                          $r->err_headers_out->get("Set-Cookie"))
        if $debug >= 2;
}

# convert current request to GET
sub _convert_to_get {
    my ($self, $r, $args) = @_;

    return unless $r->method eq 'POST';

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    $r->server->log_error("Converting POST -> GET") if $debug >= 2;

    my @pairs =();
    while (my ($name, $value) = each %$args) {
        # we dont want to copy login data, only extra data
        next if $name eq 'destination'
             or $name =~ /^credential_\d+$/;

        $value = '' unless defined $value;
        for my $v (split /\0/, $value) {
            push @pairs, escape_uri($r, $name) . '=' . escape_uri($r, $v);
        }
    }

    $r->args(join '&', @pairs) if scalar(@pairs) > 0;

    $r->method('GET');
    $r->method_number(M_GET);
    $r->headers_in->unset('Content-Length');
}

sub escape_uri {
    my ($r, $string) = @_;
    return EBox::ThirdParty::Apache2::AuthCookie::Util::escape_path($string, $r->pool);
}

# get GET or POST data and return hash containing the data.
sub _get_form_data {
    my ($self, $r) = @_;

    my $data = '';

    my $cgi = CGI->new($r);

    return $cgi->Vars();
}

sub login {
    my ($self, $r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    my $auth_type = $r->auth_type;
    my $auth_name = $r->auth_name;

    my %args = $self->_get_form_data($r);

    if ($r->method eq 'POST') {
        $self->_convert_to_get($r, \%args);
    }

    unless (exists $args{'destination'}) {
        $r->server->log_error("No key 'destination' found in form data");
        $r->subprocess_env('AuthCookieReason', 'no_cookie');
        return $auth_type->login_form($r);
    }

    # Get the credentials from the data posted by the client
    my @credentials;
    for (my $i = 0; exists $args{"credential_$i"}; $i++) {
        my $key = "credential_$i";
        $r->server->log_error("$key $args{$key}") if $debug >= 2;
        push @credentials, $args{$key};
    }

    # save creds in pnotes so login form script can use them if it wants to
    $r->pnotes("${auth_name}Creds", \@credentials);

    # Exchange the credentials for a session key.
    my $ses_key = $self->authen_cred($r, @credentials);
    unless ($ses_key) {
        $r->server->log_error("Bad credentials") if $debug >= 2;
        $r->subprocess_env('AuthCookieReason', 'bad_credentials');
        $r->uri($args{'destination'});
        return $auth_type->login_form($r);
    }

    if ($debug >= 2) {
        defined $ses_key ? $r->server->log_error("ses_key $ses_key")
                         : $r->server->log_error("ses_key undefined");
    }

    $self->send_cookie($r, $ses_key);

    $self->handle_cache($r);

    if ($debug >= 2) {
        $r->server->log_error("redirect to $args{destination}");
    }

    $r->headers_out->set(
        "Location" => $self->untaint_destination($args{'destination'}));

    return HTTP_MOVED_TEMPORARILY;
}

sub untaint_destination {
    my ($self, $dest) = @_;

    return EBox::ThirdParty::Apache2::AuthCookie::Util::escape_destination($dest);
}

sub logout {
    my ($self,$r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    $self->remove_cookie($r);

    $self->handle_cache($r);
}

sub authenticate {
    my ($auth_type, $r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    $r->server->log_error("auth_type " . $auth_type) if ($debug >= 3);

    unless ($r->is_initial_req) {
        if (defined $r->prev) {
            # we are in a subrequest.  Just copy user from previous request.
            $r->user( $r->prev->user );
        }
        return OK;
    }

    if ($debug >= 3) {
        $r->server->log_error("r=$r authtype=". $r->auth_type);
    }

    if ($r->auth_type ne $auth_type) {
        # This location requires authentication because we are being called,
        # but we don't handle this AuthType.
        $r->server->log_error("AuthType mismatch: $auth_type =/= ".$r->auth_type) if $debug >= 3;
        return DECLINED;
    }

    # Ok, the AuthType is $auth_type which we handle, what's the authentication
    # realm's name?
    my $auth_name = $r->auth_name;
    $r->server->log_error("auth_name $auth_name") if $debug >= 2;
    unless ($auth_name) {
        $r->server->log_error("AuthName not set, AuthType=$auth_type", $r->uri);
        return SERVER_ERROR;
    }

    # Get the Cookie header. If there is a session key for this realm, strip
    # off everything but the value of the cookie.
    my $ses_key_cookie = $auth_type->key($r) || '';

    $r->server->log_error("ses_key_cookie " . $ses_key_cookie) if $debug >= 1;
    $r->server->log_error("uri " . $r->uri) if $debug >= 2;

    if ($ses_key_cookie) {
        my ($auth_user, @args) = $auth_type->authen_ses_key($r, $ses_key_cookie);

        if ($auth_user and scalar @args == 0) {
            # We have a valid session key, so we return with an OK value.
            # Tell the rest of Apache what the authentication method and
            # user is.

            $r->ap_auth_type($auth_type);
            $r->user($auth_user);
            $r->server->log_error("user authenticated as $auth_user")
                if $debug >= 1;

            # send new cookie if SessionTimeout is on
            if (my $expires = $r->dir_config("${auth_name}SessionTimeout")) {
                $auth_type->send_cookie($r, $ses_key_cookie,
                                        {expires => $expires});
            }

            return OK;
        }
        elsif (scalar @args > 0 and $auth_type->can('custom_errors')) {
            return $auth_type->custom_errors($r, $auth_user, @args);
        }
        else {
            # There was a session key set, but it's invalid for some reason. So,
            # remove it from the client now so when the credential data is posted
            # we act just like it's a new session starting.
            $auth_type->remove_cookie($r);
            $r->subprocess_env('AuthCookieReason', 'bad_cookie');
        }
    }
    else {
        $r->subprocess_env('AuthCookieReason', 'no_cookie');
    }

    # This request is not authenticated, but tried to get a protected
    # document.  Send client the authen form.
    return $auth_type->login_form($r);
}

sub login_form {
    my ($self, $r) = @_;

    my $auth_name = $r->auth_name;

    my %args = $self->_get_form_data($r);

    if ($r->method eq 'POST') {
        $self->_convert_to_get($r, \%args);
    }

    # There should be a PerlSetVar directive that gives us the URI of
    # the script to execute for the login form.

    my $authen_script;
    unless ($authen_script = $r->dir_config($auth_name . "LoginScript")) {
        $r->server->log_error("PerlSetVar '${auth_name}LoginScript' not set", $r->uri);
        return SERVER_ERROR;
    }

    $r->custom_response(HTTP_FORBIDDEN, $authen_script);

    return HTTP_FORBIDDEN;
}

sub satisfy_is_valid {
    my ($auth_type, $r, $satisfy) = @_;

    $satisfy = lc $satisfy;

    if ($satisfy eq 'any' or $satisfy eq 'all') {
        return 1;
    }
    else {
        my $auth_name = $r->auth_name;
        $r->server->log_error("PerlSetVar ${auth_name}Satisfy $satisfy invalid",$r->uri);
        return 0;
    }
}

sub get_satisfy {
    my ($auth_type, $r) = @_;

    my $auth_name = $r->auth_name;

    return lc $r->dir_config("${auth_name}Satisfy") || 'all';
}

sub authorize {
    my ($auth_type, $r) = @_;

    my $debug = $r->dir_config("AuthCookieDebug") || 0;

    $r->server->log_error('authorize() for '.$r->uri()) if $debug >= 3;

    return OK unless $r->is_initial_req; #only the first internal request

    if ($r->auth_type ne $auth_type) {
        $r->server->log_error("auth type mismatch $auth_type != ".$r->auth_type)
            if $debug >= 3;
        return DECLINED;
    }

    my $reqs_arr = $r->requires or return DECLINED;

    my $user = $r->user;

    $r->server->log_error("authorize user=$user type=$auth_type") if $debug >=3;

    unless ($user) {
        # user is either undef or =0 which means the authentication failed
        $r->server->log_error("No user authenticated", $r->uri);
        return HTTP_FORBIDDEN;
    }

    my $satisfy = $auth_type->get_satisfy($r);
    return SERVER_ERROR unless $auth_type->satisfy_is_valid($r,$satisfy);
    my $satisfy_all = $satisfy eq 'all';

    my ($forbidden);
    foreach my $req (@$reqs_arr) {
        my ($requirement, $args) = split /\s+/, $req->{requirement}, 2;
        $args = '' unless defined $args;
        $r->server->log_error("requirement := $requirement, $args") if $debug >= 2;

        if (lc($requirement) eq 'valid-user') {
            if ($satisfy_all) {
                next;
            }
            else {
                return OK;
            }
        }

        if ($requirement eq 'user') {
            if ($args =~ m/\b$user\b/) {
                next if $satisfy_all;
                return OK; # satisfy any
            }

            $forbidden = 1;
            next;
        }

        # Call a custom method
        my $ret_val = $auth_type->$requirement($r, $args);
        $r->server->log_error("$auth_type->$requirement returned $ret_val") if $debug >= 3;
        if ($ret_val == OK) {
            next if $satisfy_all;
            return OK; # satisfy any
        }

        # Nothing succeeded, deny access to this user.
        $forbidden = 1;
    }

    return $forbidden ? HTTP_FORBIDDEN : OK;
}

sub send_cookie {
    my ($self, $r, $ses_key, $cookie_args) = @_;

    $cookie_args = {} unless defined $cookie_args;

    my $cookie_name = $self->cookie_name($r);

    my $cookie = $self->cookie_string(
        request => $r,
        key     => $cookie_name,
        value   => $ses_key,
        %$cookie_args
    );

    my $auth_name = $r->auth_name;

    # add a P3P header if user has configured it.
    if (my $p3p = $r->dir_config("${auth_name}P3P")) {
        $r->err_headers_out->set(P3P => $p3p);
    }

    $r->err_headers_out->add("Set-Cookie" => $cookie);
}


# cookie_string takes named parameters:
#    request
#    key
#    value
#    expires
#
sub cookie_string {
    my $self = shift;
    my %p = @_;
    for (qw/request key/) {
        croak "missing required parameter $_" unless defined $p{$_};
    }
    # its okay if value is undef here.

    my $r = $p{request};

    $p{value} = '' unless defined $p{value};

    my $string = sprintf '%s=%s', @p{'key','value'};

    my $auth_name = $r->auth_name;

    if (my $expires = $p{expires} || $r->dir_config("${auth_name}Expires")) {
        $expires = EBox::ThirdParty::Apache2::AuthCookie::Util::expires($expires);
        $string .= "; expires=$expires";
    }

    $string .= '; path=' . ( $self->get_cookie_path($r) || '/' );

    if (my $domain = $r->dir_config("${auth_name}Domain")) {
        $string .= "; domain=$domain";
    }

    if ($r->dir_config("${auth_name}Secure")) {
        $string .= '; secure';
    }

    # HttpOnly is an MS extension.  See
    # http://msdn.microsoft.com/workshop/author/dhtml/httponly_cookies.asp
    if ($r->dir_config("${auth_name}HttpOnly")) {
        $string .= '; HttpOnly';
    }

    return $string;
}

sub key {
    my ($self, $r) = @_;

    my $cookie_name = $self->cookie_name($r);

    my $allcook = ($r->headers_in->get("Cookie") || "");

    return ($allcook =~ /(?:^|\s)$cookie_name=([^;]*)/)[0];
}

sub get_cookie_path {
    my ($self, $r) = @_;

    my $auth_name = $r->auth_name;

    return $r->dir_config("${auth_name}Path");
}

1;
