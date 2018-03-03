# Copyright (C) 2007 Warp Networks S.L.
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

package EBox::CGI::ClientRawBase;

use base 'EBox::CGI::Base';

use EBox::Exceptions::Base;
use EBox::Exceptions::DataInUse;
use EBox::Gettext;
use EBox::Html;

use HTML::Mason::Exceptions;
use TryCatch;

use constant ERROR_STATUS => '500';
use constant DATA_IN_USE_STATUS => '501';

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

    my $self = $class->SUPER::new(@_);
    my $namespace = delete $opts{'namespace'};
    my $tmp = $class;
    $tmp =~ s/^(.*?)::CGI::(.*?)(?:::)?(.*)//;
    if(not $namespace) {
        $namespace = $1;
    }
    $self->{namespace} = $namespace;
    $self->{module} = $2;
    $self->{cginame} = $3;
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
    my $self = shift;

    my $response = $self->response();
    $response->content_type('text/html; charset=utf-8');

    return '';
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
    my $json = $self->{json};
    if ($json) {
        $self->JSONReply($json);
        return;
    }
    my $header = $self->_header();
    my $body = $self->_body();

    my $output = '';
    $output .= $header if ($header);
    $output .= $body if ($body);

    my $response = $self->response();
    $response->body($output);
}

sub _print_error
{
    my ($self, $text) = @_;
    $text or return;
    ($text ne "") or return;

    my $filename = 'error.mas';
    my @params =  ('error' => $text);
    my $output = EBox::Html::makeHtml($filename, @params);

    my $response = $self->response();
    # We send a ERROR_STATUS code. This is necessary in order to trigger
    # onFailure functions on Ajax code
    $response->status(ERROR_STATUS);
    $response->header('suppress-error-charset' => 1);
    $response->body($output);
}

sub _print_warning
{
    my ($self, $text) = @_;
    $text or return;
    ($text ne "") or return;

    my $request = $self->request();
    my $filename = 'dataInUse.mas';
    my @params = ();
    push(@params, 'warning' => $text);
    push(@params, 'url' => $request->env->{REQUEST_URI});
    push(@params, 'params' => $self->paramsAsHash());
    my $output = EBox::Html::makeHtml($filename, @params);

    my $response = $self->response();
    # We send a WARNING_STATUS code.
    $response->status(DATA_IN_USE_STATUS);
    $response->header('suppress-error-charset' => 1);
    $response->body($output);
}

sub run
{
    my $self = shift;

    my $finish = 0;
    if (not $self->_loggedIn) {
        $self->{redirect} = "/Login/Index";
    }
    else {
        try {
            $self->_validateReferer();
            $self->_process();
        } catch (EBox::Exceptions::DataInUse $e) {
            if ($self->{json}) {
                $self->setErrorFromException($e);
            } else {
                $self->_print_warning($e->text());
            }

            $finish = 1;
        } catch (EBox::Exceptions::External $e) {
            $self->setErrorFromException($e);
            if (not $self->{json}) {
                $self->_print_error($self->{error});
            }
            $finish = 1;
        }
    }

    if ($self->{json}) {
        $self->JSONReply($self->{json});
        return;
    }

    return if ($finish == 1);

    try  {
        $self->_print;
    } catch ($ex) {
        my $logger = EBox::logger();
        if (ref($ex) and $ex->can('text')) {
            $logger->error('Exception: ' . $ex->text());
        } else {
            $logger->error("Unknown exception: $ex");
        }

        throw $ex;
    }
}

1;
