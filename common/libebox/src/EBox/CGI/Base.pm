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
	my $interp = HTML::Mason::Interp->new(comp_root => EBox::Config::templates);
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
	my $interp = HTML::Mason::Interp->new(comp_root => 
						EBox::Config::templates);
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
	my $interp = HTML::Mason::Interp->new(comp_root => EBox::Config::templates);
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
	my $interp = HTML::Mason::Interp->new(comp_root => EBox::Config::templates);
	my $comp = $interp->make_component(comp_file => $filename);
	$interp->exec($comp, @{$self->{params}});
}

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
	my $debug = EBox::Config::configkey('debug');
	if (not $self->_loggedIn) {
		$self->{redirect} = "/ebox/Login/Index";
	} else { 
		try {
			settextdomain($self->domain());
			$self->_process;
		} catch EBox::Exceptions::External with {
			my $ex = shift;
			$self->{error} = $ex->text;
			if (defined($self->{redirect})) {
				$self->{chain} = $self->{redirect};
			}
		} catch EBox::Exceptions::Internal with {
			my $e = shift;
			if ($debug eq 'yes') {
				$self->{error} = $e->text;
				$self->{error} .= '<br/>\n';
				$self->{error} .= '<pre>\n';
				$self->{error} .= Dumper($e);
				$self->{error} .= '</pre>\n';
				$self->{error} .= '<br/>\n';
			} else {
				$self->{error} = __("An internal error has ".
					"ocurred. This is most probably a ".
					"bug, relevant information can be ".
					"found in the logs.");
			}
			if (defined($self->{redirect})) {
				$self->{chain} = $self->{redirect};
			}
		} catch EBox::Exceptions::Base with {
			my $e = shift;
			if ($debug eq 'yes') {
				$self->{error} = $e->text;
				$self->{error} .= '<br/>\n';
				$self->{error} .= '<pre>\n';
				$self->{error} .= Dumper($e);
				$self->{error} .= '</pre>\n';
				$self->{error} .= '<br/>\n';
			} else {
				$self->{error} = __("An unknown internal ".
					"error has ocurred. This is a bug, ".
					"relevant information can be found ".
					"in the logs.");
			}
			if (defined($self->{redirect})) {
				$self->{chain} = $self->{redirect};
			}
		} otherwise {
			my $e = shift;
			my $logger = EBox::logger;
			$logger->error(Dumper($e));
			if ($debug eq 'yes') {
				$self->{error} = $e->text;
				$self->{error} .= '<br/>\n';
				$self->{error} .= '<pre>\n';
				$self->{error} .= Dumper($e);
				$self->{error} .= '</pre>\n';
				$self->{error} .= '<br/>\n';
			} else {
				$self->{error} = __("You have just hit a bug ".
					"in eBox. Please seek technical ".
					"support.");
			}
		};
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
		eval "use $classname";
		my $chain = $classname->new('error' => $self->{error},
					    'msg' => $self->{msg},
					    'cgi'   => $self->{cgi});
		$chain->run;
		return;
	} elsif ((defined($self->{redirect})) && (!defined($self->{error}))) {
		print($self->cgi()->redirect("/ebox/" . $self->{redirect}));
		return;
	} else {
		try  { 
			settextdomain('ebox');
			$self->_print 
		} catch EBox::Exceptions::Internal with {
			my $error = __("An internal error has ocurred. " . 
			  	  "This is most probably a bug, relevant ". 
				  "information can be found in the logs.");
			$self->_print_error($error);
		} otherwise {
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
				$logger->error("Unknown exception");
				throw $ex;
			}
		};
	}
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

    $self->{params} = $self->masonParameters();
}


sub setErrorFromException
{
    my ($self, $ex) = @_;

    if ($ex->can('text') ) {
	$self->{error} = $ex->text;
    }
    else {
	$self->{error} = $ex;
    }
}


# XXX maybe it will be good idea cache this in some field of the instance
sub paramsAsHash
{
    my ($self) = @_;

    my @names = @{ $self->params() };
    my %params = map { $_ => $self->param($_) } @names; 

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
	throw EBox::Exceptions::External ( __("Unallowed parameters found: ") .  "@paramsLeft");
    }

    return 1;
}


sub _validateRequiredParams
{
    my ($self, $params_r) = @_;

    my $matchResult_r = _matchParams($self->requiredParameters(), $params_r);
    my @requiresWithoutMatch =  @{ $matchResult_r->{targetsWithoutMatch} };
    if (@requiresWithoutMatch) {
	throw EBox::Exceptions::External ( __("Mandatory parameters not found: ") . "@requiresWithoutMatch");
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

sub optionalParameters
{
    return [];
}

sub requiredParameters
{
    return [];
}

sub setMsg
{
    my ($self, $msg) = @_;
    $self->{msg} = $msg;
}


# default actuate behaviour: do nothing
sub actuate
{}

# default : no mason parameters
sub masonParameters
{
    return [];
}

1;
