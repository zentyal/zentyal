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

package EBox::CGI::Run;

use EBox;
use EBox::Global;
use EBox::Model::Manager;
use EBox::CGI::Controller::Composite;
use EBox::CGI::Controller::DataTable;
use EBox::CGI::Controller::Modal;
use EBox::CGI::View::DataTable;
use EBox::CGI::View::Tree;
use EBox::CGI::View::Composite;
use EBox::Exceptions::Internal;
use EBox::Exceptions::InvalidArgument;

use TryCatch;
use File::Slurp;
use Perl6::Junction qw(any);
use Scalar::Util;

use constant URL_ALIAS_FILTER => '/usr/share/zentyal/urls/*.urls';

my %urlAlias;

# Method: run
#
#    Run the given URL and returns the HTML output. This is the Zentyal
#    Web UI core indeed.
#
# Parameters:
#
#    request    - Plack::Request object.
#    htmlblocks - *optional* Custom HtmlBlocks package
#
sub run
{
    my ($self, $request, $htmlblocks) = @_;

    unless (defined $request) {
        throw EBox::Exceptions::InvalidArgument('request');
    }

    my $global = EBox::Global->getInstance();
    $global->setRequest($request);

    my $redis = EBox::Global->modInstance('global')->redis();
    $redis->begin();

    my $url = $self->urlFromRequest($request);
    try {
        my $effectiveUrl = _urlAlias($url);
        my @extraParams = (request => $request);
        if ($htmlblocks) {
            push (@extraParams, htmlblocks => $htmlblocks);
        }

        my $handler = $self->_instanceModelCGI($effectiveUrl, @extraParams);

        unless ($handler) {
            my $classname = $self->urlToClass($effectiveUrl);
            eval "use $classname";

            if ($@) {
                my $log = EBox::logger();
                $log->error("Unable to load CGI: URL=$effectiveUrl CLASS=$classname ERROR: $@");

                my $error_handler = 'EBox::SysInfo::CGI::ComponentNotFound';
                eval "use $error_handler";
                $handler = new $error_handler(@extraParams);
            } else {
                $handler = new $classname(@extraParams);
            }
        }
        $handler->run();
        $redis->commit();
        return $handler->response()->finalize();
    } catch ($ex) {
        # Base exceptions are already logged, log the other ones
        unless (ref ($ex) and $ex->isa('EBox::Exceptions::Base')) {
            EBox::error("Exception trying to access $url: $ex");
        }

        $redis->rollback();
        if (Scalar::Util::blessed($ex) and $ex->isa('EBox::Exceptions::Base')) {
            $ex->throw();
        } else {
            die $ex;
        }
    }
}

# Method: modelFromlUrl
#
#  Returns model instance for the given URL
#
sub modelFromUrl
{
    my ($self, $url) = @_;

    my ($model, $namespace, $type) = _parseModelUrl($url);
    return undef unless ($model and $namespace);
    my $path = lc ($namespace) . "/$model";
    return $self->_instanceComponent($path, $type);
}

# Method: urlToClass
#
#  Returns CGI class for the given URL
#
sub urlToClass
{
    my ($self, $url) = @_;
    unless ($url) {
        return "EBox::Dashboard::CGI::Index";
    }

    my @parts = split('/', $url);
    # filter '' and undef
    @parts = grep { $_ } @parts;

    my $module = shift @parts;
    if (@parts) {
        return "EBox::${module}::CGI::" . join ('::', @parts);
    } else {
        return "EBox::CGI::${module}";
    }
}


# Helper functions

# Method: _parseModelUrl
#
#   Get model path, type and action from the given URL if it's a MVC one
#
#   It checks the *.urls files to check if the given URL is an alias
#   in order to get the real URL of the CGI
#
# Parameters:
#
#   url - URL to parse
#
# Returns:
#
#   list  - (model, namespace, type, action) if valid model URL
#   undef - if regular CGI url
#
sub _parseModelUrl
{
    my ($url) = @_;

    unless (defined ($url)) {
        throw EBox::Exceptions::Internal("No URL provided");
    }

    my ($namespace, $type, $model, $action) = split ('/', $url);

    # Special case for ModalController urls with different format
    # TODO: try to rewrite modal controller code in order to use
    #       regular URLs to avoid this workaround
    if ((defined $model) and ($model eq 'ModalController')) {
        my $module = EBox::Global->modInstance($type);
        unless ($module) {
            return undef;
        }
        $type = 'ModalController';
        $model = $action;
        $namespace = $module->name();
    }

    if ($type eq any(qw(Composite View Controller ModalController Tree Template))) {
        return ($model, $namespace, $type, $action);
    }

    return undef;
}

sub urlFromRequest
{
    my ($self, $request) = @_;

    my $url = $request->path();
    $url =~ s/^\///s;

    return $url;
}

sub _urlAlias
{
    my ($url) = @_;

    unless (keys %urlAlias) {
        _readUrlAliases();
    }

    if (exists $urlAlias{$url}) {
        return $urlAlias{$url};
    } else {
        return $url;
    }
}

sub _readUrlAliases
{
    foreach my $file (glob (URL_ALIAS_FILTER)) {
        my @lines = read_file($file);
        foreach my $line (@lines) {
            my ($alias, $url) = split (/\s/, $line);
            $urlAlias{$alias} = $url;
        }
    }
}

sub _instanceComponent
{
    my ($self, $path, $type) = @_;

    my $manager = EBox::Model::Manager->instance();
    my $model = undef;
    if ($type eq 'Composite') {
        $model = $manager->composite($path);
    } else {
        $model = $manager->model($path);
    }

    return $model;
}

sub _instanceModelCGI
{
    my ($self, $url, @extraParams) = @_;

    my ($handler, $menuNamespace) = (undef, undef);

    my ($modelName, $namespace, $type, $action) = _parseModelUrl($url);

    return undef unless ($modelName and $namespace and $type);

    my $manager = EBox::Model::Manager->instance();
    my $path = lc ($namespace) . "/$modelName";
    return undef unless $manager->componentExists($path);

    my $model = $self->_instanceComponent($path, $type);

    if ($model) {
        $menuNamespace = $model->menuNamespace();
        if ($type eq 'View') {
            $handler = EBox::CGI::View::DataTable->new('tableModel' => $model, 'namespace' => $namespace, @extraParams);
        } elsif ($type eq 'Tree' or $type eq 'Template') {
            $handler = EBox::CGI::View::Tree->new('model' => $model, 'namespace' => $namespace, @extraParams);
        } elsif ($type eq 'Controller') {
            $handler = EBox::CGI::Controller::DataTable->new('tableModel' => $model, 'namespace' => $namespace, @extraParams);
        } elsif ($type eq 'ModalController') {
            $handler = EBox::CGI::Controller::Modal->new('tableModel' => $model, 'namespace' => $namespace, @extraParams);
        } elsif ($type eq 'Composite') {
            if (defined ($action)) {
                $handler = new EBox::CGI::Controller::Composite(
                    composite => $model,
                    action    => $action,
                    namespace => $namespace,
                    @extraParams);
            } else {
                $handler = new EBox::CGI::View::Composite(
                    composite => $model,
                    namespace => $namespace,
                    @extraParams);
            }
        }

        if (defined ($handler) and defined ($menuNamespace)) {
            $handler->setMenuNamespace($menuNamespace);
        }
    }

    return $handler;
}

1;
