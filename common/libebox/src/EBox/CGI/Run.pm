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

package EBox::CGI::Run;

use strict;
use warnings;

use EBox;
# use EBox::FirstTime; # see #204 
use EBox::Gettext;
use EBox::CGI::Base;
use EBox::Model::CompositeManager;
use EBox::Model::ModelManager;
use EBox::CGI::Controller::Composite;
use EBox::CGI::Controller::DataTable;
use EBox::CGI::View::DataTable;
use EBox::CGI::View::Composite;
use CGI;

use Error qw(:try);

sub run # (url)
{
	my ($self, $script) = @_;
	my $classname = "EBox::CGI::";

	defined($script) or exit;

	$script =~ s/\?.*//g;
	$script =~ s/[\\"']//g;
	$script =~ s/\//::/g;
	$script =~ s/^:://;

	$classname .= $script;

	$classname =~ s/::::/::/g;
	$classname =~ s/::$//;
	
# see #204
# 	if (EBox::FirstTime::isFirstTime()) {
#               $classname = firstTimeClassName($classname);
# 	}
# 	elsif ($classname eq 'EBox::CGI') {
	if ($classname eq 'EBox::CGI') {
		$classname .= '::Summary::Index';
	}

	settextdomain('ebox');

	my $cgi;
	eval "use $classname"; 
	if ($@) {
	        try {
		  $cgi = $self->_lookupViewController($classname);
		}
		catch EBox::Exceptions::DataNotFound with {
		  # path not valid
		  $cgi = undef;
		};
		
		if (not $cgi) {
			my $log = EBox::logger;
			$log->error("Unable to import cgi: " 
				. "$classname Eval error: $@");

			my $error_cgi = 'EBox::CGI::EBox::PageNotFound';
			eval "use $error_cgi"; 
			$cgi = new $error_cgi;
		} else {
			EBox::debug("$classname mapped to " 
			. " Controller/Viewer CGI");
		}
	} 
        else {
		$cgi = new $classname;
	}

	$cgi->run;
}

# see #204
# sub firstTimeClassName
# {
#     my ($classname) = @_;

#     ### login and logout classes had priority over first time index
#     return $classname if $classname =~ m{::Login::};
#     return $classname if $classname =~ m{::Logout::};
#     ### other first time classes must not be replaced by the firsttime index
#     return $classname if $classname =~ m{::FirstTime::};
#     ### change to firstime index...
#     return 'EBox::CGI::FirstTime::Index' ; 
# }

# Helper functions

# Method:: _lookupViewController
#
# 	Check if a classname must be mapped to a View or Controller
# 	cgi class from a model or a composite
#
sub _lookupViewController
{
	my ($self, $classname) = @_;

#	my ($namespace, $modelName) = $classname =~ m/EBox::CGI::.*::(.*)::(.*)/;
        # URL to map:
        # url => 'EBox::CGI::<moduleName>::' menuNamespaceBranch
        # menuNamespaceBranch => 'View' model | 'Controller' model index | 'Composite' model index action
        # model => '::<modelName>'
        # index => '::<index>' | epsilon
        # action => '::<actionName>' | epsilon

        my @namespaces = split ( '::', $classname);

        my ($namespace, $modelName) = ($namespaces[3], $namespaces[4]);

        my ($cgi, $menuNamespace) = (undef, undef);
        if ( ($namespace eq 'View') or
             ($namespace eq 'Controller')) {

            if ( defined ( $namespaces[5] ) ) {
                # Set as model name, the context name
                $modelName = '/' . lc ( $namespaces[2] ) . '/' . $modelName . '/' . $namespaces[5];
            } else {
                $modelName = '/' . lc ( $namespaces[2] ) . "/$modelName";
            }
            my $manager = EBox::Model::ModelManager->instance();
            my $model = $manager->model($modelName);


            $menuNamespace = $model->menuNamespace();
            if ( $namespace eq 'View' ) {
#            if ($classname =~ /EBox::CGI::.*::View:/ ) {
		$cgi = EBox::CGI::View::DataTable->new(
                                                       'tableModel' => $model);
            } elsif ( $namespace eq 'Controller' ) {
#            } elsif ($classname =~ /EBox::CGI::.*::Controller:/) {
		$cgi = EBox::CGI::Controller::DataTable->new(
                                                             'tableModel' => $model);
            }

        } elsif ( $namespace eq 'Composite' ) {
            my $compManager = EBox::Model::CompositeManager->Instance();
            my ($composite, $action) = (undef, undef);
            if ( defined ( $namespaces[5] )) {
                # It may be the index or the action
                # Compose the composite context name
                my $contextName = '/' . lc ( $namespaces[2] ) . '/' . $modelName . '/' . $namespaces[5];
                try {
                    $composite = $compManager->composite($contextName);
                    $action = $namespaces[6];
                } catch EBox::Exceptions::DataNotFound with {
                    $action = $namespaces[5];
                };
            }
            unless ( defined ( $composite )) {
                my $contextName = '/' . lc ( $namespaces[2] ) . "/$modelName";
                $composite = $compManager->composite($contextName);
            }
            $menuNamespace = $composite->menuNamespace();
            # Check if the action is defined URL: Composite/<compName>/<action>
            if ( defined ( $action )) {
                $cgi = new EBox::CGI::Controller::Composite(
                                                            composite => $composite,
                                                            action    => $action,
                                                           );
            } else {
                $cgi = new EBox::CGI::View::Composite(
                                                      composite => $composite
                                                     );
            }
        }

	if (defined($cgi) and defined($menuNamespace)) {
		$cgi->setMenuNamespace($menuNamespace);
	}

	return $cgi;
}

1;
