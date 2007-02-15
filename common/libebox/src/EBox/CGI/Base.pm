# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::CGI::Base;
use strict;
use warnings;

use HTML::Mason;
use HTML::Mason::Exceptions; 
use CGI;
use EBox::Gettext;
use EBox;
use EBox::Exceptions::Base;
use EBox::Exceptions::Internal;
use EBox::Exceptions::External;
use EBox::Exceptions::DataMissing;
use POSIX qw(setlocale LC_ALL);
use Error qw(:try);
use Encode qw(:all);
use Data::Dumper;
use Perl6::Junction qw(all);


## arguments
##		title [optional]
##		error [optional]
##		msg [optional]
##		cgi   [optional]
##		template [optional]
sub new # (title=?, error=?, msg=?, cgi=?, template=?)
{
	my $class = shift;
	my %opts = @_;
	my $self = {};
	$self->{title} = delete $opts{title};
	$self->{olderror} = delete $opts{error};
	$self->{msg} = delete $opts{msg};
	$self->{cgi} = delete $opts{cgi};
	$self->{template} = delete $opts{template};
	unless (defined($self->{cgi})) {
		$self->{cgi} = new CGI;
	}
	$self->{domain} = 'ebox';
	$self->{paramsKept} = ();
	bless($self, $class);
	return $self;
}

sub _header
{}

sub _top
{}

sub _menu
{}

sub _title
{
	my $self = shift;
	my $filename = EBox::Config::templates . '/title.mas';
	my $interp = $self->_masonInterp();
	my $comp = $interp->make_component(comp_file => $filename);
	my @params = ();
	
	my $title = $self->{title}; 
	if (defined($title) and (length($title) > 0)) {
		$title = __($title);
	} else {
		$title = "";
	}
	push(@params, 'title' => $title);

	settextdomain('ebox');
	$interp->exec($comp, @params);
	settextdomain($self->{domain});
}

sub _print_error # (text)
{
	my ($self, $text) = @_;
	$text or return;
	($text ne "") or return;
	my $filename = EBox::Config::templates . '/error.mas';
	my $interp = $self->_masonInterp();
	my $comp = $interp->make_component(comp_file => $filename);
	my @params = ();
	push(@params, 'error' => $text);
	$interp->exec($comp, @params);
}

sub _error #
{
	my $self = shift;
	defined($self->{olderror}) and $self->_print_error($self->{olderror});
	defined($self->{error}) and $self->_print_error($self->{error});
}

sub _msg
{
	my $self = shift;
	defined($self->{msg}) or return;
	my $filename = EBox::Config::templates . '/msg.mas';
	my $interp = $self->_masonInterp();
	my $comp = $interp->make_component(comp_file => $filename);
	my @params = ();
	push(@params, 'msg' => $self->{msg});
	$interp->exec($comp, @params);
}

sub _body
{
	my $self = shift;
	defined($self->{template}) or return;

	my $filename = EBox::Config::templates . $self->{template};
	my $interp = $self->_masonInterp();
	my $comp = $interp->make_component(comp_file => $filename);
	$interp->exec($comp, @{$self->{params}});
}



MASON_INTERP: {
  my $masonInterp;

  sub _masonInterp
    {
      my ($self) = @_;
     
      return $masonInterp if defined $masonInterp;

      $masonInterp = HTML::Mason::Interp->new(
					      comp_root => EBox::Config::templates,
#					      default_escape_flags => 'h',
					     );

      return $masonInterp;
    }

};

sub _footer
{}

sub _print
{
	my $self = shift;
	settextdomain('ebox');
	$self->_header;
	$self->_top;
	$self->_menu;
	print "</div><div id='limewrap'><div id='content'>";
	$self->_title;
	$self->_error;
	$self->_msg;
	settextdomain($self->{'domain'});
	$self->_body;
	settextdomain('ebox');
	print "</div></div>";
	$self->_footer;
}


sub _checkForbiddenChars
{
	my ($self, $value) = @_;
	POSIX::setlocale(LC_ALL, EBox::locale());

	_utf8_on($value);
	unless ( $value =~ m{^[\w /.?&+:\-\@]*$} ) {
		my $logger = EBox::logger;
		$logger->info("Invalid characters in param value $value.");
		$self->{error} ='The input contains invalid characters';
		throw EBox::Exceptions::External(__d("The input contains invalid " .
			"characters. All alphanumeric characters, plus these non " .
			"alphanumeric chars: /.?&+:-\@ and spaces are allowed.",'libebox'));
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

sub _urlToChain # (url) 
{
	my $str = shift;
	$str =~ s/\?.*//g;
	$str =~ s/\//::/g;
	$str =~ s/::$//g;
	$str =~ s/^:://g;
	return "EBox::CGI::" . $str;
}

# arguments
# 	- name of the required parameter
# 	- display name for the parameter (as seen by the user)
sub _requireParam # (param, display) 
{
	my ($self, $param, $display) = @_;

	unless (defined($self->param($param)) && $self->param($param) ne "") {
		throw EBox::Exceptions::DataMissing(data => $display);
	}
}

# arguments
# 	- name of the required parameter
# 	- display name for the parameter (as seen by the user)
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
	my $self = shift;

	if (not $self->_loggedIn) {
		$self->{redirect} = "/ebox/Login/Index";
	}
	else { 
	  try {
	    settextdomain($self->domain());
	    $self->_process();
	  } 
	  catch EBox::Exceptions::Base with {
	    my $e = shift;
	    $self->setErrorFromException($e);
	    if (defined($self->{redirect})) {
	      $self->{chain} = $self->{redirect};
	    }
	  } 
	  otherwise {
	    my $e = shift;
	    $self->setErrorFromException($e);	 
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
		my $classname = _urlToChain($self->{chain});
		if (not $self->isa($classname)) {
		  eval "use $classname";
		  if ($@) {
		    throw EBox::Exceptions::Internal("Cannot load $classname. Error: $@");
		  }
		  my $chain = $classname->new('error' => $self->{error},
					      'msg' => $self->{msg},
					      'cgi'   => $self->{cgi});
		  $chain->run;
		  return;
		}
	} 

	if ((defined($self->{redirect})) && (!defined($self->{error}))) {
		print($self->cgi()->redirect("/ebox/" . $self->{redirect}));
		EBox::debug("redirect: " . $self->{redirect});
		return;
	} 

	

	try  { 
	  settextdomain('ebox');
	  $self->_print 
	} catch EBox::Exceptions::Internal with {
	  my $error = __("An internal error has ocurred. " . 
			 "This is most probably a bug, relevant ". 
			 "information can be found in the logs.");
	  $self->_print_error($error);
	} 
	otherwise {
	    my $ex = shift;
	    my $logger = EBox::logger;
	    if (isa_mason_exception($ex)) {
	      $logger->error($ex->as_text);
	      my $error = __("An internal error related to ".
			     "a template has occurred. This is ". 
			     "a bug, relevant information can ".
			     "be found in the logs.");
	      $self->_print_error($error);
	    } else {
	      if ($ex->can('text')) {
		$logger->error('Exception: ' . $ex->text());
	      } else {
		$logger->error("Unknown exception");			    
	      }

	      throw $ex;
	    }
	  };

}





sub unsafeParam # (param) 
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
			_utf8_on($v);
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
		_utf8_on($scalar);
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
			$v =~ s/\t/ /g;
			$v =~ s/^ +//;
			$v =~ s/ +$//;
			$self->_checkForbiddenChars($v);
			_utf8_on($v);
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
		$scalar =~ s/\t/ /g;
		$scalar =~ s/^ +//;
		$scalar =~ s/ +$//;
		$self->_checkForbiddenChars($scalar);
		_utf8_on($scalar);
		return $scalar;
	}
}

sub params
{
	my $self = shift;
	my $cgi = $self->cgi;
	my @names = $cgi->param;
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

sub cgi
{
	my $self = shift;
	return $self->{cgi};
}

sub domain
{
	my $self = shift;
	return $self->{domain};
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
#  process the CGI
#
# Default behaviour:
#     the default behaviour is intended to standarize and ease some common operations so do not override it except for backward compability or special reasons.
#     The default behaviour validate the peresence or absence or CGI parameters using requiredParameters and optionalParameters method, then it calls the method actuate, where the functionality of CGI resides,  and finally uses masonParameters to get the parameters needed by the html template invocation.
sub _process
{
    my ($self) = @_;

    try {
	$self->_validateParams();
	$self->actuate();
    }
    otherwise {
	my $e = shift;
	$self->setErrorFromException($e);

    };

  try {
      $self->{params} = $self->masonParameters();
    }
    otherwise {
      my $e = shift;
      
      EBox::error("Error in masonParameters");
      $self->setErrorFromException($e) if !exists $self->{error};

    };
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
    my $debug = EBox::Config::configkey('debug');

    if ($debug eq 'yes') {
      $self->{error} = $ex->stringify() if $ex->can('stringify');
      $self->{error} .= '<br/>\n';
      $self->{error} .= '<pre>\n';
      $self->{error} .= Dumper($ex);
      $self->{error} .= '</pre>\n';
      $self->{error} .= '<br/>\n';
    } 
    elsif ($ex->isa('EBox::Exceptions::External')) {
      $self->{error} = $ex->stringify();
    }
    elsif ($ex->isa('EBox::Exceptions::Internal')) {
      $self->{error} = __("An internal error has ".
			  "ocurred. This is most probably a ".
			  "bug, relevant information can be ".
			  "found in the logs.");
    }
    elsif ($ex->isa('EBox::Exceptions::Base')) {
      $self->{error} = __("An unexpected internal ".
			  "error has ocurred. This is a bug, ".
			  "relevant information can be found ".
			  "in the logs.");
    }
    else {
	$self->{error} = __("You have just hit a bug ".
			    "in eBox. Please seek technical ".
			    "support.");
    }
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
# Returns:
#    a reference to a hash wich contains the CGI parameters and his values as keys and values of the hash	
# 
# Possible implentation improvements:
#  maybe it will be good idea cache this in some field of the instance
sub paramsAsHash
{
    my ($self) = @_;

    my @names = @{ $self->params() };
    my %params = map { 
      my $value = $self->param($_) ;
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
    if (@paramsLeft ) {
      EBox::error("Unallowed parameters found in CGI request: @paramsLeft");
      throw EBox::Exceptions::External ( __('Your request could not be processed because it had some incorrect parameters'));
    }

    return 1;
}


sub _validateRequiredParams
{
    my ($self, $params_r) = @_;

    my $matchResult_r = _matchParams($self->requiredParameters(), $params_r);
    my @requiresWithoutMatch =  @{ $matchResult_r->{targetsWithoutMatch} };
    if (@requiresWithoutMatch) {
      EBox::error("Mandatory parameters not found in CGI request: @requiresWithoutMatch");
      throw EBox::Exceptions::External ( __('Your request could not be processed because it lacked some required parameters'));
    }
    else {

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
	}
	else {
	    push @targetsWithoutMatch, $targetParam;
	}
    }

    return { matches => \@matchedParams, targetsWithoutMatch => \@targetsWithoutMatch };
}

# Method:  optionalParameters
#  	get the optional CGI parameter list. Any parameter that match with this list may be present or absent in the CGI parameters. 	
#
# Returns:
#	the list of matching parameters, it may be a names or a regular expression, in the last case it can not contain the metacharacters ^ and $
# 
sub optionalParameters
{
    return [];
}

# Method:  requiredParameters
#  	get the required CGI parameter list. Any parameter that match with this list must be present  in the CGI parameters. 	
#
# Returns:
#	the list of matching parameters, it may be a names or a regular expression, in the last case it can not contain the metacharacters ^ and $
# 
sub requiredParameters
{
    return [];
}




# Method:  actuate
#  		
#  This method is the workhouse of the CGI it must be overriden by the different CGIs to achieve their objectives
sub actuate
{}

# Method: masonParameters
#   This method must be overriden by the different child to return the adequate template parameter for his state. 
#
# Returns:
#  a  reference to a list which contains the names and values of the different mason parameters
# 
sub masonParameters
{
  my ($self) = @_;

  if (exists $self->{params}) {
    return $self->{params};
  }

  return [];
}

1;
