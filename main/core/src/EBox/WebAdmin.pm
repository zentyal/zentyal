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

package EBox::WebAdmin;
use base qw(EBox::Module::Service);

use EBox;
use EBox::Validate qw( checkPort checkCIDR );
use EBox::Sudo;
use EBox::Global;
use EBox::Service;
use EBox::Menu;
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
use TryCatch;

# Constants
use constant CAS_KEY => 'cas';
use constant CA_CERT_PATH  => EBox::Config::conf() . 'ssl-ca/';
use constant CA_CERT_FILE  => CA_CERT_PATH . 'nginx-ca.pem';
use constant CERT_FILE     => EBox::Config::conf() . 'ssl/ssl.pem';
use constant RELOAD_FILE   => '/var/lib/zentyal/webadmin.reload';
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

# FIXME: is this still needed?
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

#  Method: _daemons
#
#   Overrides <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        { name => 'zentyal.webadmin-uwsgi' },
        { name => 'zentyal.webadmin-nginx' }
    ];
}

# Method: listeningPort
#
#     Return the listening port for the webadmin.
#
# Returns:
#
#     Int - the listening port
#
sub listeningPort
{
    my ($self) = @_;

    return $self->model('AdminPort')->value('port');
}

sub reload
{
    EBox::Sudo::root('touch ' . RELOAD_FILE);
}

sub _setConf
{
    my ($self) = @_;

    $self->_setLanguage();
    $self->_writeNginxConfFile();
    $self->_writeCSSFiles();
    $self->_reportAdminPort();
    $self->_setEdition();
    $self->enableRestartOnTrigger();
}

sub _enforceServiceState
{
    my ($self, %params) = @_;

    if ((not $params{'stop'}) and $self->isRunning()) {
        $self->reload();

        my $state = $self->get_state();
        if (exists $state->{port_changed}) {
            delete $state->{port_changed};
            $self->set_state($state);
            EBox::Sudo::silentRoot("systemctl restart zentyal.webadmin-nginx");
        }
    } else {
        $self->SUPER::_enforceServiceState(%params);
    }
}

sub _writeNginxConfFile
{
    my ($self) = @_;

    my $nginxconf = '/var/lib/zentyal/conf/nginx.conf';
    my $templateConf = 'core/nginx.conf.mas';

    my @confFileParams = ();
    push @confFileParams, (port                => $self->listeningPort());
    push @confFileParams, (tmpdir              => EBox::Config::tmp());
    push @confFileParams, (zentyalconfdir      => EBox::Config::conf());
    push @confFileParams, (restrictedresources => $self->get_list('restricted_resources') );
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

    @confFileParams = ();
    push @confFileParams, (conf => $nginxconf);
    push @confFileParams, (confDir => EBox::Config::conf());

    $permissions = {
        uid => 0,
        gid => 0,
        mode => '0644',
        force => 1,
    };

    my $systemdPathPrefix = '/lib/systemd/system/zentyal.webadmin';

    EBox::Module::Base::writeConfFileNoCheck("$systemdPathPrefix-nginx.service", 'core/systemd-nginx.mas', \@confFileParams, $permissions);

    my $systemdFile = 'core/systemd-uwsgi.mas';
    @confFileParams = ();
    push (@confFileParams, socketpath => '/run/zentyal-' . $self->name());
    push (@confFileParams, socketname => 'webadmin.sock');
    push (@confFileParams, script     => EBox::Config::psgi() . 'zentyal.psgi');
    push (@confFileParams, reloadfile => RELOAD_FILE);
    push (@confFileParams, user       => EBox::Config::user());
    push (@confFileParams, group      => EBox::Config::group());
    EBox::Module::Base::writeConfFileNoCheck("$systemdPathPrefix-uwsgi.service", $systemdFile, \@confFileParams, $permissions);
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

# Report the new TCP admin port to the observer modules
sub _reportAdminPort
{
    my ($self) = @_;

    foreach my $mod (@{$self->global()->modInstancesOfType('EBox::WebAdmin::PortObserver')}) {
        $mod->adminPortChanged($self->listeningPort());
    }
}

sub logs
{
    my @logs = ();
    my $log;
    $log->{'module'} = 'webadmin';
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

# Method: certificates
#
# Overrides: EBox::Module::Service::certificates
#
sub certificates
{
    my ($self) = @_;
    return [
        {
            serviceId => 'Zentyal Administration Web Server',
            service => __('Zentyal Administration Web Server'),
            path => CERT_FILE,
            user =>  'root',
            group => 'root',
            mode => '0600',
        },
     ];
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

# Method: disableRestartOnTrigger
#
#   Makes webadmin and other modules listed in the restart-trigger script  to
#   ignore it and do nothing
sub disableRestartOnTrigger
{
    system ('touch ' . NO_RESTART_ON_TRIGGER);
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
    return (not EBox::Sudo::fileTest('-e', NO_RESTART_ON_TRIGGER));
}

sub usesPort
{
    my ($self, $proto, $port, $iface) = @_;
    if ($proto ne 'tcp') {
        return 0;
    }
    return ($port == $self->listeningPort());
}

sub defaultPort
{
    return 8443;
}

# Method: checkAdminPort
#
#      Check the admin port is being in use by another service.
#
#      There are two sources: firewall module and netstat output
#
# Parameters:
#
#      port - Int the new port to set
#
# Exceptions:
#
#      <EBox::Exceptions::External> - thrown if the port is being in used by other service
#
sub checkAdminPort
{
    my ($self, $port) = @_;

    my $global = $self->global();
    my $fw = $global->modInstance('firewall');
    if (defined($fw)) {
        unless ($fw->availablePort('tcp', $port)) {
            throw EBox::Exceptions::External(__x(
                'Zentyal is already configured to use port {p} for another service. Choose another port or free it and retry.',
                p => $port
               ));
        }
    }

    my $netstatLines = EBox::Sudo::root('netstat -tlnp');
    foreach my $line (@{ $netstatLines }) {
        my ($proto, $recvQ, $sendQ, $localAddr, $foreignAddr, $state, $PIDProgram) =
          split ('\s+', $line, 7);
        if ($localAddr =~ m/:$port$/) {
            my ($pid, $program) = split ('/', $PIDProgram);
            throw EBox::Exceptions::External(__x(
                q{Port {p} is already in use by program '{pr}'. Choose another port or free it and retry.},
                p => $port,
                pr => $program));
        }
    }

}

# Method: updateAdminPortService
#
#    Update the admin port service used by network module, if available
#
# Parameters:
#
#    port - Int the new port for the webadmin
#
sub updateAdminPortService
{
    my ($self, $port) = @_;
    my $global = $self->global();
    if ($global->modExists('network')) {
        my $services = $global->modInstance('network');
        $services->setAdministrationPort($port);
    }

    # Enforce nginx restart
    my $state = $self->get_state();
    $state->{port_changed} = 1;
    $self->set_state($state);
}

sub _setEdition
{
    my ($self) = @_;

    my $themePath = EBox::Config::share() . 'zentyal/www';

    # Check not to override the rebranded Zentyal
    if (-r "$themePath/custom.theme.sig") {
        my $content = File::Slurp::read_file("$themePath/custom.theme");
        if ($content !~ /title-(ent|sb|comm|prof|business|premium|trial).png/) {
            # Do not rebrand
            EBox::debug("Custom logo images are not rebranded because there is already a rebranding");
            return;
        }
    }

    my @cmds;
    my $edition = $self->global()->edition();
    my $expired = (rindex($edition, 'expired') != -1);
    $edition =~ s/-expired//;
    if ($edition eq 'commercial') {
        @cmds = ("cp '$themePath/comm.theme' '$themePath/custom.theme'",
                 "cp '$themePath/comm.theme.sig' '$themePath/custom.theme.sig'");
    } elsif ($edition eq 'professional') {
        @cmds = ("cp '$themePath/prof.theme' '$themePath/custom.theme'",
                 "cp '$themePath/prof.theme.sig' '$themePath/custom.theme.sig'");
    } elsif ($edition eq 'business') {
        @cmds = ("cp '$themePath/business.theme' '$themePath/custom.theme'",
                 "cp '$themePath/business.theme.sig' '$themePath/custom.theme.sig'");
    } elsif ($edition eq 'premium') {
        @cmds = ("cp '$themePath/premium.theme' '$themePath/custom.theme'",
                 "cp '$themePath/premium.theme.sig' '$themePath/custom.theme.sig'");
    } elsif ($edition eq 'trial') {
        @cmds = ("cp '$themePath/trial.theme' '$themePath/custom.theme'",
                 "cp '$themePath/trial.theme.sig' '$themePath/custom.theme.sig'");
    } else {
        @cmds = ("rm -f '$themePath/custom.theme' '$themePath/custom.theme.sig'",
                 "rm -f /etc/apt/sources.list.d/zentyal-qa.list");
    }
    if ($expired) {
        push (@cmds, "rm -f /etc/apt/sources.list.d/zentyal-qa.list");
    } elsif ($edition ne 'community') {
        my $version = EBox::Config::version();
        my $lk = read_file('/var/lib/zentyal/.license');
        chomp ($lk);
        if (substr($lk, 0, 2) eq 'NS') {
            $version .= '-nss';
        }
        push (@cmds,
            "echo 'deb https://archive.zentyal.com/zentyal-qa $version main' > /etc/apt/sources.list.d/zentyal-qa.list",
            "echo 'machine archive.zentyal.com login $lk password lk' > /etc/apt/auth.conf",
            'chmod 600 /etc/apt/auth.conf',
            'sed -i "/packages.zentyal.org/d" /etc/apt/sources.list'
        );
    }
    EBox::Sudo::root(@cmds);
}

1;
