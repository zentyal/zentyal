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
use POSIX qw(setsid);
use EBox::Global;
use EBox::Service;
use HTML::Mason::Interp;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::MissingArgument;
use EBox::Gettext;
use EBox::Config;
use English qw(-no_match_vars);
use File::Basename();

# Constants
use constant RESTRICTED_FILES_KEY    => 'restricted_files';
use constant RESTRICTED_IP_LIST_KEY  => 'allowed_ips';
use constant RESTRICTED_PATH_TYPE_KEY => 'path_type';
use constant ABS_PATH => 'absolute';
use constant REL_PATH => 'relative';

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
	my $root = EBox::Config::configkey('httpd_serverroot');
	($root) or
		throw EBox::Exceptions::External(__('You must set the '.
		'httpd_serverroot variable in the ebox configuration file'));
	return $root;
}

#not used now
sub initd
{
	my $initd = EBox::Config::configkey('httpd_init');
	($initd) or
		throw EBox::Exceptions::External(__('You must set the '.
			'httpd_init variable in the ebox configuration file'));
	( -x $initd ) or
		throw EBox::Exceptions::External(__('The httpd_init script'.
			' you configured is not executable.'));
	return $initd;
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

		POSIX::setsid();
		close(STDOUT);
		close(STDERR);
		open(STDOUT, "> /dev/null");
		open(STDERR, "> /dev/null");
		sleep(5);
	}

	if ($action eq 'stop') {
		EBox::Service::manage('apache-perl','stop');
	} elsif ($action eq 'start') {
		EBox::Service::manage('apache-perl','start');
	} elsif ($action eq 'restart') {
		exec(EBox::Config::libexec . 'ebox-apache-restart');
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

sub _regenConfig
{
	my $self = shift;
	
	$self->_deleteSessionObjects();

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
        push @confFileParams, ( restrictedFiles => $self->_restrictedFiles() );

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
    $self->writeConfFile($startupFile, '/startup.pl.mas' , [], {mode => '0600', uid => $UID, gid => $primaryGid});

}


sub _httpdConfFile
{
    my $httpdconf = EBox::Config::configkey('httpd_conf');
    return $httpdconf;
}


sub _startupFile
{
  
    my $startup = File::Basename::dirname( _httpdConfFile() ); # startup mus be in the same dir thet the pache conf file
    $startup .= '/startup.pl';
    return $startup;
}

sub port
{
	my $self = shift;
	return $self->get_int('port');
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

# Method: setRestrictedFile
#
#      Set a restricted file to the Apache perl configuration
#
# Parameters:
#
#      filename - String the file name to restrict
#
#      allowedIPs - Array ref the set of IPs which allow the
#      restricted file to be accessed in CIDR format or magic word
#      'all' or 'nobody'. The former all sources are allowed to see
#      that filename and the latter nobody is allowed to see this
#      file. 'all' value has more priority than 'nobody' value.
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::Internal> - thrown if any of the allowed IP
#      addresses are not in CIDR format or no allowed IP is given
#
sub setRestrictedFile
{
    my ($self, $filename, $allowedIPs) = @_;


    throw EBox::Exceptions::MissingArgument('filename')
      unless defined ( $filename );
    throw EBox::Exceptions::MissingArgument('allowedIPs')
      unless defined ( $allowedIPs );

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

    my $nSubs = ($filename =~ s:^/::);
    my $rootKey = RESTRICTED_FILES_KEY . "/$filename/";
    if ( $nSubs > 0 ) {
        $self->set_string( $rootKey . RESTRICTED_PATH_TYPE_KEY,
                           ABS_PATH );
    } else {
        $self->set_string( $rootKey . RESTRICTED_PATH_TYPE_KEY,
                           REL_PATH );
    }

    # Get the current list
    $self->set_list( $rootKey . RESTRICTED_IP_LIST_KEY,
                     'string', $allowedIPs );

}

# Method: delRestrictedFile
#
#       Remove a restricted file from the list
#
# Parameters:
#
#       filename - String the file name which indexes which restricted
#       file is requested to be deleted
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::DataNotFound> - thrown if the given file name is
#      not in the list of restricted files
#
sub delRestrictedFile
{
    my ($self, $filename) = @_;

    throw EBox::Exceptions::MissingArgument('filename')
      unless defined ( $filename );

    $filename =~ s:^/::;

    my $fileKey = RESTRICTED_FILES_KEY . "/$filename";

    unless ( $self->dir_exists($fileKey) ) {
        throw EBox::Exceptions::DataNotFound( data  => 'filename',
                                              value => $filename);
    }

    $self->delete_dir($fileKey);

}

# Get the structure for the apache.mas.in template to restrict a
# certain number of files for a set of ip addresses
sub _restrictedFiles
{

    my ($self) = @_;

    my @restrictedFiles = ();
    foreach my $dir (@{$self->all_dirs_base(RESTRICTED_FILES_KEY)}) {
        my $filename = $dir;
        my $compKey = RESTRICTED_FILES_KEY . "/$dir";
        while ( @{$self->all_dirs_base($compKey)} > 0 ) {
            my ($subdir) = @{$self->all_dirs_base($compKey)};
            $compKey .= "/$subdir";
            $filename .= "/$subdir";
        }
        # Add first slash if the added file name is absolute
        if ( $self->get_string("$compKey/" . RESTRICTED_PATH_TYPE_KEY )
             eq ABS_PATH ) {
            $filename = "/$filename";
        }
        my $restrictedFile = {
                              allowedIPs => $self->get_list("$compKey/" . RESTRICTED_IP_LIST_KEY),
                              name       => $filename
                             };
        push ( @restrictedFiles, $restrictedFile );
    }
    return \@restrictedFiles;
}

1;
