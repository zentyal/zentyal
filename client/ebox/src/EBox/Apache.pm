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
package EBox::Apache;

use strict;
use warnings;

use base 'EBox::GConfModule';

use EBox::Validate qw( :all );
use EBox::Sudo qw( :all );
use EBox::Global;
use EBox::Service;
use HTML::Mason::Interp;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Config;
use English qw(-no_match_vars);
use File::Basename;
use POSIX qw(setsid);
use Error qw(:try);

# Constants
use constant RESTRICTED_RESOURCES_KEY    => 'restricted_resources';
use constant RESTRICTED_IP_LIST_KEY  => 'allowed_ips';
use constant RESTRICTED_PATH_TYPE_KEY => 'path_type';
use constant RESTRICTED_RESOURCE_TYPE_KEY => 'type';
use constant INCLUDE_KEY => 'includes';
use constant ABS_PATH => 'absolute';
use constant REL_PATH => 'relative';
use constant APACHE_PORT => 443;

sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'apache',
                                          @_);
	bless($self, $class);
	return $self;
}

sub serverroot
{
	return '/var/lib/ebox';
}

sub initd
{
	return '/usr/share/ebox/ebox-apache2ctl';
}

# Method: cleanupForExec
#
#	It does the job to prepare a forked apache process to do an exec.
#	We should use spawn_proc_prog() from mod_perl but we experience
#	some issues.
#
#
sub cleanupForExec
{
    POSIX::setsid();

	opendir(my $dir, "/proc/$$/fd");
	while (defined(my $fd = readdir($dir))) {
		next unless ($fd =~ /^\d+$/);
		eval('POSIX::close($fd)');
	}
	open(STDOUT, '> /dev/null');
	open(STDERR, '> /dev/null');
	open(STDIN, '/dev/null');
}

# restarting apache from inside apache could be problematic, so we fork() and
# detach the child from the process group.
sub _daemon # (action) 
{
	my $self = shift;
	my $action = shift;
	my $pid;
	my $fork = undef;
	exists $ENV{"MOD_PERL"} and $fork = 1;

	if ($fork) {
		unless (defined($pid = fork())) {
			throw EBox::Exceptions::Internal("Cannot fork().");
		}
	
		if ($pid) { 
			return; # parent returns inmediately
		}
		cleanupForExec();
	} 

	if ($action eq 'stop') {
		EBox::Sudo::root('/usr/share/ebox/ebox-apache2ctl stop');
	} elsif ($action eq 'start') {
		EBox::Sudo::root('/usr/share/ebox/ebox-apache2ctl start');
	} elsif ($action eq 'restart') {
		my $restartCmd = EBox::Config::pkgdata . 'ebox-apache-restart';
		if ($fork) {
			exec($restartCmd);
		}
		else {
			EBox::Sudo::root($restartCmd);
		}

	}

	if ($fork) {
		exit 0;
	}
}

sub _stopService
{
	my $self = shift;
	$self->_daemon('stop');
}

sub stopService
{
    my $self = shift;

    $self->_lock();
    try {
        $self->_stopService();
    } finally {
        $self->_unlock();
    };
}

sub restartService
{
	my $self = shift;

	$self->_lock();
	my $global = EBox::Global->getInstance();
	my $log = EBox::logger;

	if (not $self->isEnabled()) {
		$log->info("Skipping restart for $self->{name} as it's disabled");
		return;
	}

	$log->info("Restarting service for module: " . $self->name);
	try {
            $self->_regenConfig('restart' => 1);
	} otherwise  {
            my ($ex) = @_;
            $log->error("Error restarting service: $ex");
            throw $ex;
        } finally {
		$self->_unlock();
	};
}

sub _regenConfig
{
	my $self = shift;

        # We comment out this in order to make ebox-software
        # work. State will be removed at ebox initial script
        # $self->_deleteSessionObjects();

	$self->_writeHttpdConfFile();
	$self->_writeStartupFile();

	$self->_daemon('restart');
}


#  all the state keys for apache are sessions object so we delete them all
#  warning: in the future maybe we can have other type of states keys
sub _deleteSessionObjects
{
  my ($self) = @_;
  $self->st_delete_dir('');
}

sub _writeHttpdConfFile
{
    my ($self) = @_;

	my $httpdconf = _httpdConfFile();
	my $output;
	my $interp = HTML::Mason::Interp->new(out_method => \$output);
	my $comp = $interp->make_component(
			comp_file => (EBox::Config::stubs . '/apache.mas'));

	my @confFileParams = ();
	push @confFileParams, ( port => $self->port());
	push @confFileParams, ( user => EBox::Config::user());
	push @confFileParams, ( group => EBox::Config::group());
	push @confFileParams, ( serverroot => $self->serverroot());
	push @confFileParams, ( tmpdir => EBox::Config::tmp());
        push @confFileParams, ( restrictedResources => $self->_restrictedResources() );
        push @confFileParams, ( includes => $self->_includes() );

        my $debugMode =  EBox::Config::configkey('debug') eq 'yes';
	push @confFileParams, ( debug => $debugMode);

	$interp->exec($comp, @confFileParams);

	my $confile = EBox::Config::tmp . "httpd.conf";
	unless (open(HTTPD, "> $confile")) {
		throw EBox::Exceptions::Internal("Could not write to $confile");
	}
	print HTTPD $output;
	close(HTTPD);

	root("/bin/mv $confile $httpdconf");

}

sub _writeStartupFile
{
    my ($self) = @_;

    my $startupFile = _startupFile();
    my ($primaryGid) = split / /, $GID, 2;
    EBox::Module::Base::writeConfFileNoCheck($startupFile, '/startup.pl.mas' , [], {mode => '0600', uid => $UID, gid => $primaryGid});

}


sub _httpdConfFile
{
    return '/var/lib/ebox/conf/apache2.conf';
}


sub _startupFile
{
  
    return '/var/lib/ebox/conf/startup.pl';
}

sub port
{
	my $self = shift;
	my $port = $self->get_int('port');
    $port or $port = APACHE_PORT;
    return $port;
}

# Method: setPort
#
#     Set the listening port for the apache perl
#
# Parameters:
#
#     port - Int the new listening port
#
sub setPort # (port) 
{
	my ($self, $port) = @_;

	checkPort($port, __("port"));
	my $fw = EBox::Global->modInstance('firewall');

	if ($self->port() == $port) {
		return;
	}

	if (defined($fw)) {
		unless ($fw->availablePort("tcp",$port)) {
			throw EBox::Exceptions::DataExists(data => __('port'),
							   value => $port);
		}
	}

	if (EBox::Global->instance()->modExists('services')) {
		my $services = EBox::Global->modInstance('services');
		$services->setAdministrationPort($port);
	}

	$self->set_int('port', $port);
}


sub logs {
	my @logs = ();
	my $log;
	$log->{'module'} = 'apache';
	$log->{'table'} = 'access';
	$log->{'file'} = EBox::Config::log . "/access.log";
	my @fields = qw{ host www_user date method url protocol code size referer ua };
	$log->{'fields'} = \@fields;
	$log->{'regex'} = '(.*?) - (.*?) \[(.*)\] "(.*?) (.*?) (.*?)" (.*?) (.*?) "(.*?)" "(.*?)" "-"';
	my @types = qw{ inet varchar timestamp varchar varchar varchar integer integer varchar varchar };
	$log->{'types'} = \@types;
	push(@logs, $log);
	return \@logs;
}

# Method: setRestrictedResource
#
#      Set a restricted resource to the Apache perl configuration
#
# Parameters:
#
#      resourceName - String the resource name to restrict
#
#      allowedIPs - Array ref the set of IPs which allow the
#      restricted resource to be accessed in CIDR format or magic word
#      'all' or 'nobody'. The former all sources are allowed to see
#      that resourcename and the latter nobody is allowed to see this
#      resource. 'all' value has more priority than 'nobody' value.
#
#      resourceType - String the resource type: It can be one of the
#      following: 'file', 'directory' and 'location'.
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::InvalidType> - thrown if the resource type
#      is invalid
#
#      <EBox::Exceptions::Internal> - thrown if any of the allowed IP
#      addresses are not in CIDR format or no allowed IP is given
#
sub setRestrictedResource
{
    my ($self, $resourceName, $allowedIPs, $resourceType) = @_;


    throw EBox::Exceptions::MissingArgument('resourceName')
      unless defined ( $resourceName );
    throw EBox::Exceptions::MissingArgument('allowedIPs')
      unless defined ( $allowedIPs );
    throw EBox::Exceptions::MissingArgument('resourceType')
      unless defined ( $resourceType );

    unless ( $resourceType eq 'file' or $resourceType eq 'directory'
             or $resourceType eq 'location' ) {
        throw EBox::Exceptions::InvalidType('resourceType',
                                            'file, directory or location');
    }

    my $allFound = grep { $_ eq 'all' } @{$allowedIPs};
    my $nobodyFound = grep { $_ eq 'nobody' } @{$allowedIPs};
    if ( $allFound ) {
        $allowedIPs = ['all'];
    } elsif ( $nobodyFound ) {
        $allowedIPs = ['nobody'];
    } else {
        # Check the given list is a list of IPs
        my $notIPs = grep { ! checkCIDR($_) } @{$allowedIPs};
        if ( $notIPs > 0 ) {
            throw EBox::Exceptions::Internal('Some of the given allowed IP'
                                             . 'addresses are not in CIDR format');
        }
        if ( @{$allowedIPs} == 0 ) {
            throw EBox::Exceptions::Internal('Some allowed IP must be set');
        }
    }

    my $nSubs = ($resourceName =~ s:^/::);
    my $rootKey = RESTRICTED_RESOURCES_KEY . "/$resourceName/";
    if ( $nSubs > 0 ) {
        $self->set_string( $rootKey . RESTRICTED_PATH_TYPE_KEY,
                           ABS_PATH );
    } else {
        $self->set_string( $rootKey . RESTRICTED_PATH_TYPE_KEY,
                           REL_PATH );
    }

    # Set the current list
    $self->set_list( $rootKey . RESTRICTED_IP_LIST_KEY,
                     'string', $allowedIPs );
    $self->set_string( $rootKey . RESTRICTED_RESOURCE_TYPE_KEY,
                       $resourceType);

}

# Method: delRestrictedResource
#
#       Remove a restricted resource from the list
#
# Parameters:
#
#       resourcename - String the resource name which indexes which restricted
#       resource is requested to be deleted
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given resource name is
#      not in the list of restricted resources
#
sub delRestrictedResource
{
    my ($self, $resourcename) = @_;

    throw EBox::Exceptions::MissingArgument('resourcename')
      unless defined ( $resourcename );

    $resourcename =~ s:^/::;

    my $resourceKey = RESTRICTED_RESOURCES_KEY . "/$resourcename";

    unless ( $self->dir_exists($resourceKey) ) {
        throw EBox::Exceptions::DataNotFound( data  => 'resourcename',
                                              value => $resourcename);
    }

    $self->delete_dir($resourceKey);

}

# Get the structure for the apache.mas.in template to restrict a
# certain number of resources for a set of ip addresses
sub _restrictedResources
{

    my ($self) = @_;

    my @restrictedResources = ();
    foreach my $dir (@{$self->all_dirs_base(RESTRICTED_RESOURCES_KEY)}) {
        my $resourcename = $dir;
        my $compKey = RESTRICTED_RESOURCES_KEY . "/$dir";
        while ( @{$self->all_dirs_base($compKey)} > 0 ) {
            my ($subdir) = @{$self->all_dirs_base($compKey)};
            $compKey .= "/$subdir";
            $resourcename .= "/$subdir";
        }
        # Add first slash if the added resource name is absolute
        if ( $self->get_string("$compKey/" . RESTRICTED_PATH_TYPE_KEY )
             eq ABS_PATH ) {
            $resourcename = "/$resourcename";
        }
        my $restrictedResource = {
                              allowedIPs => $self->get_list("$compKey/" . RESTRICTED_IP_LIST_KEY),
                              name       => $resourcename,
                              type       => $self->get_string( "$compKey/"
                                                               . RESTRICTED_RESOURCE_TYPE_KEY),
                             };
        push ( @restrictedResources, $restrictedResource );
    }
    return \@restrictedResources;
}


# Method: isEnabled
#
#      As it's not a service but it expects to behave like one,
#      implement isEnabled
#
sub isEnabled
{
    return 1;
}

# Method: addInclude
#
#      Add an "include" directive to the apache configuration
#
# Parameters:
#
#      includeFilePath - String the configuration file path to include
#      in apache configuration
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::Internal> - thrown if the given file does
#      not exists
#
sub addInclude
{
    my ($self, $includeFilePath) = @_;

    unless(defined($includeFilePath)) {
        throw EBox::Exceptions::MissingArgument('includeFilePath');
    }
    unless(-f $includeFilePath and -r $includeFilePath) {
        throw EBox::Exceptions::Internal(
            "File $includeFilePath cannot be read or it is not a file"
           );
    }
    my @includes = @{$self->_includes()};
    unless ( grep { $_ eq $includeFilePath } @includes) {
        push(@includes, $includeFilePath);
        $self->set_list(INCLUDE_KEY, 'string', \@includes);
    }

}

# Method: removeInclude
#
#      Remove an "include" directive to the apache configuration
#
# Parameters:
#
#      includeFilePath - String the configuration file path to remove
#      from apache configuration
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::Internal> - thrown if the given file has not
#      been included previously
#
sub removeInclude
{
    my ($self, $includeFilePath) = @_;

    unless(defined($includeFilePath)) {
        throw EBox::Exceptions::MissingArgument('includeFilePath');
    }
    my @includes = @{$self->_includes()};
    my @newIncludes = grep { $_ ne $includeFilePath } @includes;
    if ( @newIncludes eq @includes ) {
        throw EBox::Exceptions::Internal("$includeFilePath has not been included previously");
    }
    $self->set_list(INCLUDE_KEY, 'string', \@newIncludes);

}

# Return those include files that has been added
sub _includes
{
    my ($self) = @_;
    return $self->get_list(INCLUDE_KEY);
}

1;
