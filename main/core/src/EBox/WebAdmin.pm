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

package EBox::WebAdmin;
use base qw(EBox::Module::Service);

use strict;
use warnings;

use EBox;
use EBox::Validate qw( :all );
use EBox::Sudo;
use EBox::Global;
use EBox::Service;
use EBox::Menu;
use HTML::Mason::Interp;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::InvalidType;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::External;
use EBox::Gettext;
use EBox::Config;
use EBox::Util::Version;
use English qw(-no_match_vars);
use File::Basename;
use File::Slurp;
use POSIX qw(setsid setlocale LC_ALL);
use Error qw(:try);

# Constants
use constant APACHE_INCLUDE_KEY => 'apacheIncludes';
use constant NGINX_INCLUDE_KEY => 'nginxIncludes';
use constant CAS_KEY => 'cas';
use constant CA_CERT_PATH  => EBox::Config::conf() . 'ssl-ca/';
use constant CA_CERT_FILE  => CA_CERT_PATH . 'nginx-ca.pem';
use constant NO_RESTART_ON_TRIGGER => EBox::Config::tmp() . 'webadmin_no_restart_on_trigger';

# Constructor: _create
#
#      Create a new EBox::WebAdmin module object
#
# Returns:
#
#      <EBox::WebAdmin> - the recently created model
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(
        name   => 'webadmin',
        printableName => __('Zentyal Webadmin'),
        @_
    );

    bless($self, $class);
    return $self;
}

sub serverroot
{
    return '/var/lib/zentyal';
}

# Method: cleanupForExec
#
#   It does the job to prepare a forked apache process to do an exec.
#   We should use spawn_proc_prog() from mod_perl but we experience
#   some issues.
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

sub _daemon
{
    my ($self, $action) = @_;

    $self->_manageNginx($action);
    $self->_manageApache($action);

    if ($action eq 'stop') {
        # Stop redis server
        $self->{redis}->stopRedis();
        $self->setHardRestart(0) if $self->hardRestart();
    }
}

sub _manageNginx
{
    my ($self, $action) = @_;

    EBox::Service::manage($self->_nginxUpstartName(), $action);
}

# restarting apache from inside apache could be problematic, so we fork()
sub _manageApache
{
    my ($self, $action) = @_;

    my $conf = EBox::Config::conf();
    my $ctl = "APACHE_CONFDIR=$conf apache2ctl";

    # Sometimes apache is running but for some reason apache.pid does not
    # exist, with this workaround we always ensure a successful restart
    my $pidfile = EBox::Config::tmp() . 'apache.pid';
    my $pid;
    unless (-f $pidfile) {
        $pid = `ps aux|grep 'apache2 -d $conf'|awk '/^root/{print \$2;exit}'`;
        write_file($pidfile, $pid) if $pid;
    }

    my $hardRestart = $self->hardRestart();

    if ($action eq 'stop') {
        EBox::Sudo::root("$ctl stop");
    } elsif ($action eq 'start') {
        EBox::Sudo::root("$ctl start");
    } elsif ($action eq 'restart') {
        if ($hardRestart) {
            EBox::info("Apache hard restart requested");
            $self->_daemon('stop');
            $self->_daemon('start');
            return;
        }
        unless (defined($pid = fork())) {
            throw EBox::Exceptions::Internal("Cannot fork().");
        }
        if ($pid) {
            return; # parent returns inmediately
        } else {
            EBox::Sudo::root("$ctl restart");
            exit ($?);
        }
    }
}

sub setHardRestart
{
    my ($self, $reload) = @_;
    my $state = $self->get_state;
    $state->{hardRestart} = $reload;
    $self->set_state($state);
}

# return wether we should reload the page after saving changes
sub hardRestart
{
    my ($self) = @_;
    my $state = $self->get_state;
    return $state->{hardRestart};
}

sub _stopService
{
    my ($self) = @_;

    $self->_daemon('stop');
}

sub _setConf
{
    my ($self) = @_;

    $self->_setLanguage();
    $self->_writeNginxConfFile();
    $self->_writeHttpdConfFile();
    $self->_writeCSSFiles();
    $self->_reportAdminPort();
    $self->enableRestartOnTrigger();
}

sub _enforceServiceState
{
    my ($self) = @_;

    $self->_daemon('restart');
}

sub _nginxConfFile
{
    return '/var/lib/zentyal/conf/nginx.conf';
}

sub _nginxUpstartName
{
    return 'zentyal.webadmin-nginx';
}

sub _nginxUpstartFile
{
    my ($self) = @_;

    my $nginxUpstartName = $self->_nginxUpstartName();
    return "/etc/init/$nginxUpstartName.conf";
}

sub _writeNginxConfFile
{
    my ($self) = @_;

    # Write CA links
    $self->_writeCAFiles();

    my $nginxconf = $self->_nginxConfFile();
    my $templateConf = 'core/nginx.conf.mas';

    my @confFileParams = ();
    push @confFileParams, (port => $self->port());
    push @confFileParams, (tmpdir => EBox::Config::tmp());
    push @confFileParams, (zentyalconfdir => EBox::Config::conf());
    push @confFileParams, (includes => $self->_nginxIncludes(1));
    if (@{$self->_CAs(1)}) {
        push @confFileParams, (caFile => CA_CERT_FILE);
    } else {
        push @confFileParams, (caFile => undef);
    }

    my $permissions = {
        uid => EBox::Config::user(),
        gid => EBox::Config::group(),
        mode => '0644',
        force => 1,
    };

    EBox::Module::Base::writeConfFileNoCheck($nginxconf, $templateConf, \@confFileParams, $permissions);

    my $upstartFile = 'core/upstart-nginx.mas';

    @confFileParams = ();
    push @confFileParams, (conf => $self->_nginxConfFile());
    push @confFileParams, (confDir => EBox::Config::conf());

    $permissions = {
        uid => 0,
        gid => 0,
        mode => '0644',
        force => 1,
    };

    EBox::Module::Base::writeConfFileNoCheck($self->_nginxUpstartFile, $upstartFile, \@confFileParams, $permissions);
}

sub _writeHttpdConfFile
{
    my ($self) = @_;

    my $httpdconf = '/var/lib/zentyal/conf/apache2.conf';
    my $template = 'core/apache.mas';

    my @confFileParams = ();
    #push @confFileParams, ( port => $self->port());
    push @confFileParams, ( user => EBox::Config::user());
    push @confFileParams, ( group => EBox::Config::group());
    push @confFileParams, ( serverroot => $self->serverroot());
    push @confFileParams, ( tmpdir => EBox::Config::tmp());
    push @confFileParams, ( eboxconfdir => EBox::Config::conf());

    push @confFileParams, ( restrictedResources => $self->get_list('restricted_resources') );
    push @confFileParams, ( includes => $self->_apacheIncludes(1) );

    my $debugMode = EBox::Config::boolean('debug');
    push @confFileParams, ( debug => $debugMode);

    my $permissions = {
        uid => EBox::Config::user(),
        gid => EBox::Config::group(),
        mode => '0644',
        force => 1,
    };

    EBox::Module::Base::writeConfFileNoCheck($httpdconf, $template, \@confFileParams, $permissions);
}

sub _setLanguage
{
    my ($self) = @_;

    my $languageModel = $self->model('Language');

    # TODO: do this only if language has changed?
    my $lang = $languageModel->value('language');
    EBox::setLocale($lang);
    EBox::setLocaleEnvironment($lang);
    EBox::Menu::regenCache();
}

sub _writeCSSFiles
{
    my ($self) = @_;

    my $path = EBox::Config::dynamicwww() . '/css';
    unless (-d $path) {
        mkdir $path;
    }

    my ($primaryGid) = split / /, $GID, 2;

    my $global = EBox::Global->getInstance();
    my $theme = $global->theme();
    my %params = %{ $theme };

    foreach my $file ('public.css', 'login.css', 'jquery-ui.css') {
        my $dst = "$path/$file";
        if ($file eq 'jquery-ui.css') {
            $dst = EBox::Config::www() . '/css/jquery-ui/' . $file;
        }

        EBox::Module::Base::writeConfFileNoCheck($dst,
                                                 "css/$file.mas",
                                                 [ %params ],
                                                 { mode => '0644',
                                                   uid => $UID,
                                                   gid => $primaryGid});
    }

    # special treatment for jqueryui-c


}

# write CA Certificate file with included CAs
sub _writeCAFiles
{
    my ($self) = @_;

    system('rm -rf ' . CA_CERT_PATH);
    mkdir(CA_CERT_PATH);

    foreach my $ca (@{$self->_CAs(1)}) {
        write_file(CA_CERT_FILE, { append => 1 }, read_file($ca));
   }
}

# Report the new TCP admin port to Zentyal Cloud
sub _reportAdminPort
{
    my ($self) = @_;

    my $global = EBox::Global->getInstance(1);
    if ($global->modExists('remoteservices')) {
        my $rs = $global->modInstance('remoteservices');
        $rs->reportAdminPort($self->port());
    }
}

sub port
{
    my ($self) = @_;

    return $self->model('AdminPort')->value('port');
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

    my $adminPortModel = $self->model('AdminPort');
    my $oldPort = $adminPortModel->value('port');

    return if ($oldPort == $port);

    $self->checkAdminPort($port);

    $adminPortModel->setValue('port', $port);
    $self->updateAdminPortService($port);
}

sub checkAdminPort
{
    my ($self, $port) = @_;

    my $global = EBox::Global->getInstance();
    my $fw = $global->modInstance('firewall');
    if (defined($fw)) {
        unless ($fw->availablePort("tcp",$port)) {
            throw EBox::Exceptions::External(__x(
'Zentyal is already configured to use port {p} for another service. Choose another port or free it and retry.',
                p => $port
               ));
        }
    }

    my $netstatLines = EBox::Sudo::root('netstat -tlnp');
    foreach my $line (@{ $netstatLines }) {
        my ($proto, $recvQ, $sendQ, $localAddr, $foreignAddr, $state, $PIDProgram) =
            split '\s+', $line, 7;
        if ($localAddr =~ m/:$port$/) {
            my ($pid, $program) = split '/', $PIDProgram;
            throw EBox::Exceptions::External(__x(
q{Port {p} is already in use by program '{pr}'. Choose another port or free it and retry.},
                p => $port,
                pr => $program,
              )
            );
        }
    }
}

sub updateAdminPortService
{
    my ($self, $port) = @_;
    my $global = $self->global();
    if ($global->modExists('services')) {
        my $services = $global->modInstance('services');
        $services->setAdministrationPort($port);
    }
}

sub logs
{
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

    my $resources = $self->get_list('restricted_resources');
    if ($self->_restrictedResourceExists($resourceName)) {
        my @deleted = grep { $_->{name} ne $resourceName} @{$resources};
        $resources = \@deleted;
    }
    push (@{$resources}, { name => $resourceName, allowedIPs => $allowedIPs, type => $resourceType});
    $self->set('restricted_resources', $resources);
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
        unless defined ($resourcename);

    $resourcename =~ s:^/::;

    my $resources = $self->get_list('restricted_resources');

    unless ($self->_restrictedResourceExists($resourcename)) {
        throw EBox::Exceptions::DataNotFound(data  => 'resourcename',
                                             value => $resourcename);
    }

    my @deleted = grep { $_->{name} ne $resourcename} @{$resources};
    $self->set('restricted_resources', \@deleted);
}

sub _restrictedResourceExists
{
    my ($self, $resourcename) = @_;

    foreach my $resource (@{$self->get_list('restricted_resources')}) {
        if ($resource->{name} eq $resourcename) {
            return 1;
        }
    }
    return 0;
}

# Method: isEnabled
#
# Overrides:
#   EBox::Module::Service::isEnabled
sub isEnabled
{
    # apache always has to be enabled
    return 1;
}

# Method: showModuleStatus
#
#   Indicate to ServiceManager if the module must be shown in Module
#   status configuration.
#
# Overrides:
#   EBox::Module::Service::showModuleStatus
#
sub showModuleStatus
{
    # we don't want it to appear in module status
    return undef;
}

# Method: addModuleStatus
#
#   Do not show entry in the module status widget
#
# Overrides:
#   EBox::Module::Service::addModuleStatus
#
sub addModuleStatus
{
}

# Method: addNginxInclude
#
#      Add an "include" directive to the nginx configuration. If it is already
#      added, it does nothing
#
#      Added only in the main virtual host
#
# Parameters:
#
#      includeFilePath - String the configuration file path to include
#      in nginx configuration
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::Internal> - thrown if the given file does
#      not exists
#
sub addNginxInclude
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
    my @includes = @{$self->_nginxIncludes(0)};
    unless ( grep { $_ eq $includeFilePath } @includes) {
        push(@includes, $includeFilePath);
        $self->set_list(NGINX_INCLUDE_KEY, 'string', \@includes);
    }

}

# Method: removeNginxInclude
#
#      Remove an "include" directive to the nginx configuration. If the
#      "include" was not in the configuration, it does nothing
#
#
# Parameters:
#
#      includeFilePath - String the configuration file path to remove
#      from nginx configuration
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#
sub removeNginxInclude
{
    my ($self, $includeFilePath) = @_;

    unless(defined($includeFilePath)) {
        throw EBox::Exceptions::MissingArgument('includeFilePath');
    }
    my @includes = @{$self->_nginxIncludes(0)};
    my @newIncludes = grep { $_ ne $includeFilePath } @includes;
    if ( @newIncludes == @includes ) {
        return;
    }
    $self->set_list(NGINX_INCLUDE_KEY, 'string', \@newIncludes);

}

# Return those include files that has been added
sub _nginxIncludes
{
    my ($self, $check) = @_;
    my $includeList = $self->get_list(NGINX_INCLUDE_KEY);
    if (not $check) {
        return $includeList;
    }

    my @includes;
    foreach my $incPath (@{ $includeList }) {
        if ((-f $incPath) and (-r $incPath)) {
            push @includes, $incPath;
        } else {
            EBox::warn("Ignoring apache include $incPath: cannot read the file or it is not a regular file");
        }
    }

    return \@includes;
}

# Method: addApacheInclude
#
#      Add an "include" directive to the apache configuration
#
#      Added only in the main virtual host
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
sub addApacheInclude
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
    my @includes = @{$self->_apacheIncludes(0)};
    unless ( grep { $_ eq $includeFilePath } @includes) {
        push(@includes, $includeFilePath);
        $self->set_list(APACHE_INCLUDE_KEY, 'string', \@includes);
    }

}

# Method: removeApacheInclude
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
sub removeApacheInclude
{
    my ($self, $includeFilePath) = @_;

    unless(defined($includeFilePath)) {
        throw EBox::Exceptions::MissingArgument('includeFilePath');
    }
    my @includes = @{$self->_apacheIncludes(0)};
    my @newIncludes = grep { $_ ne $includeFilePath } @includes;
    if ( @newIncludes == @includes ) {
        throw EBox::Exceptions::Internal("$includeFilePath has not been included previously",
                                         silent => 1);
    }
    $self->set_list(APACHE_INCLUDE_KEY, 'string', \@newIncludes);

}

# Return those include files that has been added
sub _apacheIncludes
{
    my ($self, $check) = @_;
    my $includeList = $self->get_list(APACHE_INCLUDE_KEY);
    if (not $check) {
        return $includeList;
    }

    my @includes;
    foreach my $incPath (@{ $includeList }) {
        if ((-f $incPath) and (-r $incPath)) {
            push @includes, $incPath;
        } else {
            EBox::warn("Ignoring apache include $incPath: cannot read the file or it is not a regular file");
        }
    }

    return \@includes;
}

# Method: addCA
#
#   Include the given CA in the ssl_client_certificate
#
# Parameters:
#
#      ca - CA Certificate
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::Internal> - thrown if the given file does
#      not exists
#
sub addCA
{
    my ($self, $ca) = @_;

    unless(defined($ca)) {
        throw EBox::Exceptions::MissingArgument('ca');
    }
    unless(-f $ca and -r $ca) {
        throw EBox::Exceptions::Internal(
            "File $ca cannot be read or it is not a file"
           );
    }
    my @cas = @{$self->_CAs(0)};
    unless ( grep { $_ eq $ca } @cas) {
        push(@cas, $ca);
        $self->set_list(CAS_KEY, 'string', \@cas);
    }

}

# Method: removeCA
#
#      Remove a previously added CA from the ssl_client_certificate
#
# Parameters:
#
#       ca - CA certificate
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
#      <EBox::Exceptions::Internal> - thrown if the given file has not
#      been included previously
#
sub removeCA
{
    my ($self, $ca) = @_;

    unless(defined($ca)) {
        throw EBox::Exceptions::MissingArgument('ca');
    }
    my @cas = @{$self->_CAs(0)};
    my @newCAs = grep { $_ ne $ca } @cas;
    if ( @newCAs == @cas ) {
        throw EBox::Exceptions::Internal("$ca has not been included previously",
                                         silent => 1);
    }
    $self->set_list(CAS_KEY, 'string', \@newCAs);
}

# Return those include files that has been added
sub _CAs
{
    my ($self, $check) = @_;
    my $caList = $self->get_list(CAS_KEY);
    if (not $check) {
        return $caList;
    }

    my @cas;
    foreach my $ca (@{ $caList }) {
        if ((-f $ca) and (-r $ca)) {
            push @cas, $ca;
        } else {
            EBox::warn("Ignoring CA $ca: cannot read the file or not is a regular file");
        }
    }

    return \@cas;
}

# Method: certificates
#
#   This method is used to tell the CA module which certificates
#   and its properties we want to issue for this service module.
#
# Returns:
#
#   An array ref of hashes containing the following:
#
#       service - name of the service using the certificate
#       path    - full path to store this certificate
#       user    - user owner for this certificate file
#       group   - group owner for this certificate file
#       mode    - permission mode for this certificate file
#
sub certificates
{
    my ($self) = @_;

    return [
            {
             serviceId =>  'Zentyal Administration Web Server',
             service =>  __('Zentyal Administration Web Server'),
             path    =>  '/var/lib/zentyal/conf/ssl/ssl.pem',
             user => EBox::Config::user(),
             group => EBox::Config::group(),
             mode => '0600',
            },
           ];
}

# Method: disableRestartOnTrigger
#
#   Makes webadmin and other modules listed in the restart-trigger script  to
#   ignore it and do nothing
sub disableRestartOnTrigger
{
    system 'touch ' . NO_RESTART_ON_TRIGGER;
    if ($? != 0) {
        EBox::warn('Canot create "webadmin no restart on trigger" file');
    }
}

# Method: enableRestartOnTrigger
#
#   Makes webadmin and other modules listed in the restart-trigger script  to
#   restart themselves when the script is executed (default behaviour)
sub enableRestartOnTrigger
{
    EBox::Sudo::root("rm -f " . NO_RESTART_ON_TRIGGER);
}

# Method: restartOnTrigger
#
#  Whether webadmin and other modules listed in the restart-trigger script  to
#  restart themselves when the script is executed
sub restartOnTrigger
{
    return not EBox::Sudo::fileTest('-e', NO_RESTART_ON_TRIGGER);
}

sub usesPort
{
    my ($self, $proto, $port, $iface) = @_;
    if ($proto ne 'tcp') {
        return 0;
    }
    return $port == $self->port();
}

# Method: initialSetup
#
# Overrides:
#
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Upgrade from 3.0
    if (defined ($version) and (EBox::Util::Version::compare($version, '3.1') < 0)) {
        # Perform the migration to 3.2
        $self->_migrateTo32();
    }
}

# Migration to 3.2
#
#  * Migrate redis keys from apache to webadmin
#
sub _migrateTo32
{
    my ($self) = @_;

    my $redis = $self->redis();
    my @keys = $redis->_keys('apache/*');
    foreach my $key (@keys) {
        my $value = $redis->get($key);
        my $newkey = $key;
        $newkey =~ s{^apache}{webadmin};
        $redis->set($newkey, $value);
    }
    $redis->unset(@keys);
}

1;
