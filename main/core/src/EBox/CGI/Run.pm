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

use Error qw(:try);
use File::Slurp;
use Perl6::Junction qw(any);

use constant URL_ALIAS_FILTER => '/usr/share/zentyal/urls/*.urls';

my %urlAlias;

# Method: run
#
#    Run the given URL and prints out the returned HTML. This is the eBox
#    Web UI core indeed.
#
# Parameters:
#
#    url - String the URL to get the CGI from, it will transform
#    slashes to double colons
#
#    htmlblocks - *optional* Custom HtmlBlocks package
#
sub run
{
    my ($self, $url, $htmlblocks) = @_;

    my $redis = EBox::Global->modInstance('global')->redis();
    $redis->begin();

    try {
        my $effectiveUrl = _urlAlias($url);
        my @extraParams;
        if ($htmlblocks) {
            push (@extraParams, htmlblocks => $htmlblocks);
        }

        my $cgi = $self->_instanceModelCGI($effectiveUrl, @extraParams);

        unless ($cgi) {
            my $classname = $self->urlToClass($effectiveUrl);
            eval "use $classname";

            if ($@) {
                my $log = EBox::logger();
                $log->error("Unable to load CGI: URL=$effectiveUrl CLASS=$classname ERROR: $@");

                my $error_cgi = 'EBox::SysInfo::CGI::PageNotFound';
                eval "use $error_cgi";
                $cgi = new $error_cgi(@extraParams);
            } else {
                $cgi = new $classname(@extraParams);
            }
        }

        $cgi->{originalUrl} = $url;

        $cgi->run();
        $redis->commit();
    } otherwise {
        my ($ex) = @_;

        # Base exceptions are already logged, log the rest
        unless (ref ($ex) and $ex->isa('EBox::Exceptions::Base')) {
            EBox::error("Exception trying to access $url: $ex");
        }

        $redis->rollback();
        $ex->throw();
    };
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

    defined ($url) or die "Not URL provided";

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

    if ($type eq any(qw(Composite View Controller ModalController Tree))) {
        return ($model, $namespace, $type, $action);
    }

    return undef;
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

    my ($cgi, $menuNamespace) = (undef, undef);

    my ($modelName, $namespace, $type, $action) = _parseModelUrl($url);

    return undef unless ($modelName and $namespace and $type);

    my $manager = EBox::Model::Manager->instance();
    my $path = lc ($namespace) . "/$modelName";
    return undef unless $manager->componentExists($path);

    my $model = $self->_instanceComponent($path, $type);

    if ($model) {
        $menuNamespace = $model->menuNamespace();
        if ($type eq 'View') {
            $cgi = EBox::CGI::View::DataTable->new('tableModel' => $model, 'namespace' => $namespace, @extraParams);
        } elsif ($type eq 'Tree') {
            $cgi = EBox::CGI::View::Tree->new('model' => $model, 'namespace' => $namespace, @extraParams);
        } elsif ($type eq 'Controller') {
            $cgi = EBox::CGI::Controller::DataTable->new('tableModel' => $model, 'namespace' => $namespace, @extraParams);
        } elsif ($type eq 'ModalController') {
            $cgi = EBox::CGI::Controller::Modal->new('tableModel' => $model, 'namespace' => $namespace, @extraParams);
        } elsif ($type eq 'Composite') {
            if (defined ($action)) {
                $cgi = new EBox::CGI::Controller::Composite(composite => $model,
                                                            action    => $action,
                                                            namespace => $namespace,
                                                            @extraParams);
            } else {
                $cgi = new EBox::CGI::View::Composite(composite => $model,
                                                      namespace => $namespace,
                                                      @extraParams);
            }
        }

        if (defined ($cgi) and defined ($menuNamespace)) {
            $cgi->setMenuNamespace($menuNamespace);
        }
    }

    return $cgi;
}

1;
