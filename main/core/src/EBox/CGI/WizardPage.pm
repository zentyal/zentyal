# Copyright (C) 2010-2013 Zentyal S.L.
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

#
# Wizard pages are used by modules to help user on initial configuration
# If a module implements some wizard it will be shown by zentyal-software to
# the user
#
# A wizard page handler has 2 types of calls differentiated by HTTP request method:
#
#   - GET - The page will show a form that the user must fill
#           This information is normally written in a template with the
#           parameters returned by <_masonParameters> method.
#
#   - POST - That form will sent to this handler for processing.
#            The <_processWizard> method should be overriden to perform
#            the action. If form processing fails, POST request must
#            response with an error code and print error messages
#            user will see (usually using an exception). If status is OK,
#            the wizard will step into next wizard page. You can
#            return a JSON response using json object property.
#

use strict;
use warnings;

package EBox::CGI::WizardPage;

use base 'EBox::CGI::Base';

use EBox::Exceptions::Base;
use EBox::Exceptions::DataInUse;
use EBox::Gettext;
use EBox::Html;

use HTML::Mason::Exceptions;
use TryCatch;

use constant ERROR_STATUS => '500';

## arguments
##              title [optional]
##              error [optional]
##              msg [optional]
##              cgi   [optional]
##              template [optional]
sub new # (title=?, error=?, msg=?, cgi=?, template=?)
{
    my $class = shift;
    my %opts = @_;

    my $self = $class->SUPER::new(@_);
    my $namespace = delete $opts{'namespace'};
    my $tmp = $class;
    $tmp =~ s/^EBox::(.*?)::CGI::.*$//;
    if(not $namespace) {
        $namespace = $1;
    }
    $self->{namespace} = $namespace;
    $self->{module} = lc $1;

    bless($self, $class);
    return $self;
}

# Method: _processWizard
#
# Processes form submission and configures module
#
sub _processWizard
{
    # Override this to process wizard page
}

# Method: _masonParameters
#
# Configures parameteres for mason template
#
# Returns
#   array ref to mason parameters
sub _masonParameters
{
    # Override this to set mason template params
}

sub _print
{
    my ($self) = @_;

    my $json = $self->{json};
    if ($json) {
        $self->JSONReply($json);
        return;
    }

    my $request = $self->request();
    if ($request->method() eq 'GET') {
        my $header = $self->_header();
        my $body = $self->_body();
        my $output = '';
        $output .= $header if ($header);
        $output .= $body if ($body);

        my $response = $self->response();
        $response->body($output);
    }
}

sub _process
{
    my ($self) = @_;

    $self->{params} = $self->_masonParameters();

    my $request = $self->request();
    if ($request->method() eq 'POST') {
        $self->_processWizard();
    }
}

sub _print_error
{
    my ($self, $text) = @_;
    $text or return;
    ($text ne "") or return;

    my $response = $self->response();
    # We send a ERROR_STATUS code. This is necessary in order to trigger
    # onFailure functions on Ajax code
    $response->status(ERROR_STATUS);
    $response->header('suppress-error-charset' => 1);
    $response->body($text);
}

sub run
{
    my $self = shift;

    if (not $self->_loggedIn) {
        $self->{redirect} = "/Login/Index";
    } else {
        try {
            $self->_validateReferer();
            if ($self->param('skip')) {
                $self->skipModule();
            } else {
                $self->_process();
            }

            $self->_print;
        } catch ($ex) {
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
                    $self->_print_error($ex->text());
                } else {
                    $logger->error("$ex");
                    $self->_print_error("$ex");
                }
            }
        }
    }
}

sub _title
{

}

sub _header
{
    my $self = shift;

    my $response = $self->response();
    $response->content_type('text/html; charset=utf-8');
}

sub _footer
{

}

sub _menu
{

}

sub skipModule
{
    my ($self) = @_;
    my $module = EBox::Global->getInstance()->modInstance($self->{module});
    if ($module->isa('EBox::Module::Config')) {
        my $state = $module->get_state();
        $state->{skipFirstTimeEnable} = 1;
        $module->set_state($state);
    }
}

1;
