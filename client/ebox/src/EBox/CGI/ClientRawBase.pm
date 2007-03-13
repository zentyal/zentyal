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

package EBox::CGI::ClientRawBase;
use strict;
use warnings;

use base 'EBox::CGI::Base';
use EBox::Gettext;
use EBox::Html;
use Apache;
use Error qw(:try);
use HTML::Mason::Exceptions;
use EBox::Exceptions::DataInUse;
use EBox::Exceptions::Base;

use constant ERROR_STATUS => '500';
use constant DATA_IN_USE_STATUS => '501';

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

	my $self = $class->SUPER::new(@_);
	my $tmp = $class;
	$tmp =~ s/^.*?::.*?::(.*?)::(.*)//;
	$self->{module} = $1;
	$self->{cginame} = $2;
	if (defined($self->{cginame})) {
		$self->{url} = $self->{module} . "/" . $self->{cginame};
	} else {
		$self->{url} = $self->{module} . "/Index";
	}

	bless($self, $class);
	return $self;
}

sub _title
{

}

sub _header
{

}

sub _footer
{

}

sub _menu
{

}
sub _print
{
	my $self = shift;
	settextdomain($self->{'domain'});
	$self->_body();
	settextdomain('ebox');
}

sub _print_error
{
	my ($self, $text) = @_;
	$text or return;
	($text ne "") or return;

	# We send a ERROR_STATUS code. This is necessary in order to trigger
	# onFailure functions on Ajax code
	my $r = Apache->request();
	$r->status(ERROR_STATUS);
	$r->custom_response(ERROR_STATUS, "");

	my $filename = EBox::Config::templates . '/error.mas';
	my $interp = HTML::Mason::Interp->new(comp_root => 
						EBox::Config::templates);
	my $comp = $interp->make_component(comp_file => $filename);
	my @params = ();
	push(@params, 'error' => $text);
	$interp->exec($comp, @params);
}

sub _print_warning
{
	my ($self, $text) = @_;
	$text or return;
	($text ne "") or return;

	# We send a WARNING_STATUS code. 
	my $r = Apache->request();
	$r->status(DATA_IN_USE_STATUS);
	$r->custom_response(DATA_IN_USE_STATUS, "");

	my $filename = EBox::Config::templates . '/dataInUse.mas';
	my $interp = HTML::Mason::Interp->new(comp_root => 
						EBox::Config::templates);
	my $comp = $interp->make_component(comp_file => $filename);
	my @params = ();
	push(@params, 'warning' => $text);
	push(@params, 'url' => _requestURL());
	push(@params, 'params' => $self->paramsAsHash());
	$interp->exec($comp, @params);

}

# TODO Refactor this stuff as it's used in the auth process too
sub _requestURL
{
	my $r = Apache->request();
	return unless($r);

	my $request = $r->the_request();
	my $method = $r->method();
	my $protocol = $r->protocol();

	my ($destination) = ($request =~ m/$method\s*(.*?)\s*$protocol/ );

	return $destination;
}

sub run
{
	my $self = shift;

	my $finish = 0;
	if (not $self->_loggedIn) {
		$self->{redirect} = "/ebox/Login/Index";
	}
	else { 
	  try {
	    settextdomain($self->domain());
	    $self->_process();

	  } catch EBox::Exceptions::DataInUse with {
	  	my $e = shift;
		$self->_print_warning($e->text());
		$finish = 1;
	  } catch EBox::Exceptions::Base with {
		  my $e = shift;
		  $self->setErrorFromException($e);	 
		  $self->_error();
	  	  $finish = 1;
	  } otherwise {
		  my $e = shift;
		  $self->setErrorFromException($e);	 
		  $self->_error();
		  $finish = 1;
	  };
	}
	
	return if ($finish == 1);

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
1;
