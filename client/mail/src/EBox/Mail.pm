# Copyright (C) 2005 Warp Netwoks S.L., DBS Servicios Informaticos S.L.
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

package EBox::Mail;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::LdapModule EBox::ObjectsObserver EBox::FirewallObserver EBox::LogObserver);

use Proc::ProcessTable;
use EBox::Sudo qw( :all );
use EBox::Validate qw( :all );
use EBox::Gettext;
use EBox::Summary::Module;
use EBox::Summary::Status;
use EBox::Menu::Item;
use EBox::Menu::Folder;
use EBox::MailVDomainsLdap;
use EBox::MailUserLdap;
use EBox::MailAliasLdap;
use EBox::MailLogHelper;
use EBox::MailFirewall;

use constant MAILMAINCONFFILE			=> '/etc/postfix/main.cf';
use constant MAILMASTERCONFFILE			=> '/etc/postfix/master.cf';
use constant AUTHLDAPCONFFILE			=> '/etc/courier/authldaprc';
use constant AUTHDAEMONCONFFILE			=> '/etc/courier/authdaemonrc';
use constant POP3DCONFFILE			=> '/etc/courier/pop3d';
use constant POP3DSSLCONFFILE			=> '/etc/courier/pop3d-ssl';
use constant IMAPDCONFFILE			=> '/etc/courier/imapd';
use constant IMAPDSSLCONFFILE			=> '/etc/courier/imapd-ssl';
use constant SASLAUTHDDCONFFILE			=> '/etc/saslauthd.conf';
use constant SASLAUTHDCONFFILE			=> '/etc/default/saslauthd';
use constant SMTPDCONFFILE			=> '/etc/postfix/sasl/smtpd.conf';
use constant MAILINIT				=> '/etc/init.d/postfix';
use constant POPINIT				=> '/etc/init.d/courier-pop';
use constant IMAPINIT				=> '/etc/init.d/courier-imap';
use constant AUTHDAEMONINIT			=> '/etc/init.d/courier-authdaemon';
use constant AUTHLDAPINIT			=> '/etc/init.d/courier-ldap';
use constant POPPIDFILE				=> "/var/run/courier/pop3d.pid";
use constant IMAPPIDFILE			=> "/var/run/courier/imapd.pid";
use constant BYTES				=> '1048576';
use constant MAXMGSIZE				=> '104857600';

sub _create 
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'mail',
		domain => 'ebox-mail',
		@_);

	$self->{vdomains} = new EBox::MailVDomainsLdap;
	$self->{musers} = new EBox::MailUserLdap;
	$self->{malias} = new EBox::MailAliasLdap;

	bless($self, $class);
	return $self;
}

sub domain 
{
	return 'ebox-mail';	
}

# Method: _getIfacesForAddress
#
#  This method returns all interfaces which ip address belongs
#
# Parameters:
#
# 		ip - The IP address
#
# Returns:
#
# 		array ref - with all interfaces
sub _getIfacesForAddress {
	my ($self, $ip) = @_;

	my $net = EBox::Global->modInstance('network');
	my @ifaces = ();

	foreach my $iface (@{$net->InternalIfaces()}) {
		foreach my $addr (@{$net->ifaceAddresses($iface)}) {
			if (isIPInNetwork($addr->{'address'}, $addr->{'netmask'}, $ip)) {
				push(@ifaces, $iface);
			}
		}
	}

	return \@ifaces;
}

# Method: _setMailConf
#
#  This method creates all configuration files from gconf data.
#  
sub _setMailConf {
	my $self = shift;
	my @array = ();
	my $users = EBox::Global->modInstance('users');
	my $ob = EBox::Global->modInstance('objects');
	my $ldap = EBox::Ldap->instance();
	my $allowedaddrs = "127.0.0.0/8";

	foreach my $obj (@{$self->allowedObj}) {
		foreach my $addr (@{$ob->ObjectAddresses($obj)}) {
			$allowedaddrs .= " $addr";
		}
	}

	push(@array, 'ldapi', $self->{vdomains}->{ldap}->ldapConf->{ldap});
	push(@array, 'vdomainDN', $self->{vdomains}->vdomainDn());
	push(@array, 'relay', $self->relay());
	push(@array, 'maxmsgsize', ($self->getMaxMsgSize() * $self->BYTES));
	push(@array, 'allowed', $allowedaddrs);
	push(@array, 'aliasDN', $self->{malias}->aliasDn());
	push(@array, 'vmaildir', $self->{musers}->DIRVMAIL);
	push(@array, 'usersDN', $users->usersDn());
	push(@array, 'uidvmail', $self->{musers}->uidvmail());
	push(@array, 'gidvmail', $self->{musers}->gidvmail());
	push(@array, 'sasl', $self->service('sasl'));
	push(@array, 'smtptls', $self->tlsSmtp());
	push(@array, 'popssl', $self->sslPop());
	push(@array, 'imapssl', $self->sslImap());
	push(@array, 'ldap', $ldap->ldapConf());
	push(@array, 'filter', $self->service('filter'));
	push(@array, 'ipfilter', $self->ipfilter());
	push(@array, 'portfilter', $self->portfilter());
	$self->writeConfFile(MAILMAINCONFFILE, "mail/main.cf.mas", \@array);

	@array = ();
	push(@array, 'smtptls', $self->tlsSmtp);
	push(@array, 'filter', $self->service('filter'));
	push(@array, 'fwport', $self->fwport());
	push(@array, 'ipfilter', $self->ipfilter());
	$self->writeConfFile(MAILMASTERCONFFILE, "mail/master.cf.mas", \@array);

	@array = ();
	push(@array, 'usersDN', $users->usersDn());
	push(@array, 'rootDN', $self->{vdomains}->{ldap}->rootDn());
	push(@array, 'rootPW', $self->{vdomains}->{ldap}->rootPw());

	$self->writeConfFile(AUTHLDAPCONFFILE, "mail/authldaprc.mas", \@array);

	$self->writeConfFile(AUTHDAEMONCONFFILE, "mail/authdaemonrc.mas");
	$self->writeConfFile(IMAPDCONFFILE, "mail/imapd.mas");
	$self->writeConfFile(POP3DCONFFILE, "mail/pop3d.mas");

	@array = ();
	push(@array, 'popssl', $self->sslPop());
	$self->writeConfFile(POP3DSSLCONFFILE, "mail/pop3d-ssl.mas", \@array);
	
	@array = ();
	push(@array, 'imapssl', $self->sslImap());
	$self->writeConfFile(IMAPDSSLCONFFILE, "mail/imapd-ssl.mas",\@array);

	@array = ();
	push(@array, 'ldapi', $self->{vdomains}->{ldap}->ldapConf->{ldap});
	push(@array, 'rootdn', $self->{vdomains}->{ldap}->rootDn());
	push(@array, 'passdn', $self->{vdomains}->{ldap}->rootPw());
	push(@array, 'usersdn', $users->usersDn());
	
	$self->writeConfFile(SASLAUTHDDCONFFILE, "mail/saslauthd.conf.mas",\@array);
	$self->writeConfFile(SASLAUTHDCONFFILE, "mail/saslauthd.mas",\@array);
	$self->writeConfFile(SMTPDCONFFILE, "mail/smtpd.conf.mas",\@array);
}

# Method: isRunning
#
#  This method returns if the service is running
#
# Parameter:
#
# 		service - a string with a service name. It could be:
# 			active for smtp service
# 			pop for pop service
# 			imap for imap service
#
# Returns
#
# 		bool - true if the service is running, false otherwise
sub isRunning
{
	my ($self, $service) = @_;
	if ($service eq 'active') {
		my $t = new Proc::ProcessTable;
		foreach my $proc (@{$t->table}) {
			($proc->fname eq 'master') and return 1;
		}
	} elsif ($service eq 'pop') {
		return $self->pidFileRunning(POPPIDFILE);
	} elsif ($service eq 'imap') {
		return $self->pidFileRunning(IMAPPIDFILE);
	} else {
		return undef;
	}
}

# Method: setFWPort
#
#  This method sets the port where forward all messages from external filter
#
# Parameters:
#
# 		fwport - The port
sub setFWPort
{
	my ($self, $fwport) = @_;

	my $fw = EBox::Global->modInstance('firewall');
	checkPort($fwport, "port");

	if ($self->fwport() == $fwport) {
		return;
	}
	unless ($fw->availablePort('tcp',$fwport)) {
		throw EBox::Exceptions::DataExists(
			'data'  => __('port'),
			'value' => $fwport);
	}
	$self->set_int('fwport', $fwport);
}

# Method: setFWPort
#
#  This method returns the port where forward all messages from external filter
#
sub fwport
{
	my $self = shift;
	return $self->get_int('fwport');
}

# Method: setIPFilter
#
#  This method sets the ip of the external filter
#
# Parameters:
#
# 		ip - The ip address
sub setIPFilter
{
	my ($self, $ip) = @_;

	unless (checkIP($ip)) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('remote IP'),
			'value'	=> __($ip.' is not a valid ip address'));
	}
	
	unless (defined(@{$self->_getIfacesForAddress($ip)})) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('remote IP'),
			'value'	=> __($ip.' cannot be reached by any configured interface'));
	}
	
	unless ($#{$self->_getIfacesForAddress($ip)} = 1) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('remote IP'),
			'value'	=> __($ip.' can be reached by more than one configured interface'));
	}
	
	$self->set_string('ipfilter', $ip);
}

# Method: ipfilter
#
#  This method returns the ip of the external filter
#
sub ipfilter
{
	my $self = shift;
	return $self->get_string('ipfilter');
}

# Method: setPortFilter
#
#  This method sets the port where the external filter listen
#
# Parameters:
#
# 		port - The port
sub setPortFilter
{
	my ($self, $port) = @_;
	
	checkPort($port, __('port'));
	$self->set_int('portfilter', $port);
}

# Method: portfilter
#
#  This method returns the port where the external filter listen
#
sub portfilter
{
	my $self = shift;
	return $self->get_int('portfilter');
}

# Method: setRelay
#
#  This method sets the ip address of the smarthost
#
# Parameters:
#
# 		relay - The ip address
sub setRelay #(smarthost)
{
	my ($self, $relay) = @_;
	
	unless ($relay eq "") {
		checkIP($relay, __('smarthost ip'));
	}

	$self->set_string('relay', $relay);
}

# Method: relay
#
#  This method returns the ip address of the smarthost if set
#
sub relay
{
	my $self = shift;
	return $self->get_string('relay');
}

# Method: setMaxMsgSize
#
#  This method sets maximum message size
#
# Parameters:
#
# 		size - the size
sub setMaxMsgSize
{
	my ($self, $size)  = @_;
	
	unless (isAPositiveNumber($size)) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('message size'),
			'value'	=> $size);
	}

	if($size > MAXMGSIZE) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('message size'),
			'value'	=> $size);
	}
	
	$self->set_int('maxmsgsize', $size);
}

# Method: getMaxMsgSize
#
#  This method returns the maximum message size
#
sub getMaxMsgSize
{
	my $self = shift;
	return $self->get_int('maxmsgsize');
}

# Method: setMDDefaultSize
#
#  This method sets the default maildir size 
#
# Parameters:
#
# 		size - size of maildir
sub setMDDefaultSize
{
	my ($self, $size)  = @_;
	
	unless (isAPositiveNumber($size)) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('maildir size'),
			'value'	=> $size);
	}
	
	if($size > MAXMGSIZE) {
		throw EBox::Exceptions::InvalidData(
			'data'	=> __('maildir size'),
			'value'	=> $size);
	}
	
	$self->set_int('mddefaultsize', $size);
}

# Method: getMDDefaultSize
#
#  This method returns the default maildir size
#
sub getMDDefaultSize
{
	my $self = shift;
	return $self->get_int('mddefaultsize');
}

# Method: setAllowedObj
#
#  This method sets the object lists that can send mail throught mail module
#
# Parameters:
#
# 		args - Object list
sub setAllowedObj
{
	my ($self, $args) = @_;
	($args) or return;
	$self->set_list("allowed", "string", $args);
}

# Method: setTlsSmtp
#
#  This method sets the tls on smtp
#
# Parameters:
#
# 		bool
sub setTlsSmtp
{
	my ($self, $level) = @_;
	$self->set_bool('smtptls', $level);
}

# Method: tlsSmtp
#
#  This method returns if tls on smtp is active
#
sub tlsSmtp
{
	my $self = shift;

	my $foo = $self->get_bool('smtptls');
	return $foo;
}

# Method: setSslPop
#
#  This method sets the ssl level on pop, it could be: no, optional, required
#
# Parameters:
#
# 		level - a string with the level
sub setSslPop
{
	my ($self, $level) = @_;
	$self->set_string('popssl', $level);
}

# Method: sslPop
#
#  This method returns the ssl level on pop, it could be: no, optional, required
#
# Returns:
#
# 		string - with the level (no, optional, required)
sub sslPop
{
	my $self = shift;

	return $self->get_string('popssl');
}

# Method: setSslImap
#
#  This method sets the ssl level on imap, it could be: no, optional, required
#
# Parameters:
#
# 		level - a string with the level
sub setSslImap
{
	my ($self, $level) = @_;
	$self->set_string('imapssl', $level);
}

# Method: sslImap
#
#  This method returns the ssl level on imap, it could be: no, optional, required
#
# Returns:
#
# 		string - with the level (no, optional, required)
sub sslImap
{
	my $self = shift;

	return $self->get_string('imapssl');
}

#
# Method: allowedObj
#
#  Returns the list of allowed objects to relay mail.
#
# Returns:
#
#  array ref - holding the objects
#
sub allowedObj
{
	my $self = shift;
	return $self->get_list('allowed');
}

#
# Method: isAllowed
#
#  Checks if a given object is allowed to relay mail.
#
# Parameters:
#
#  object - object name
#
# Returns:
#
#  boolean - true if it's set as allowed, otherwise false
#
sub isAllowed
{
	my ($self, $object)  = @_;
	my @allowed = @{$self->allowedObj};
	(@allowed) or return;
	foreach (@allowed) {
		return 1 if ($_ eq $object);
	}
	return undef;
}

#
# Method: deniedObj
#
#  Returns the list of objects that cant relay mail.
#
# Returns:
#
#  array ref - holding the objects
#
sub deniedObj
{
	my $self = shift;
	my @denied = ();
	my $object = EBox::Global->modInstance('objects');

	my @objects = @{$object->ObjectNames};

	foreach (@objects) {
		if ($self->isAllowed($_)) {
			next;
		}
		push(@denied, $_);
	}
	return \@denied;
}

#
# Method: freeObject
#
#  This method set a new allowed object list without the object passed as
#  parameter
#
# Parameters:
#		object - The object to remove.
#
sub freeObject # (object)
{
	my ($self, $object) = @_;
	(defined($object) && $object ne "") or return;

	my @allowedobjs= @{$self->allowedObj};

	if (grep(/^$object$/, @allowedobjs)) {
		my @array = ();
		foreach (@allowedobjs) {
			($_ ne $object) or next;
			push(@array, $_)
		}
		$self->setAllowedObj(\@array);
	}
}

# Method: usesObject
#
#  This methos method returns if the object is on allowed list
#
# Returns:
#
#		bool - true if the object is in allowed list, false otherwise
#
sub usesObject # (object)
{
	my ($self, $object) = @_;
	if ($self->isAllowed($object)) {
		return 1;
	}
	return undef;
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
	my ($self, $protocol, $port, $iface) = @_;

	my %srvpto = (
		'active' => 25,
		'pop'		=> 110,
		'imap'	=> 143,
	);


	foreach my $mysrv (keys %srvpto) {
		return 1 if (($port eq $srvpto{$mysrv}) and ($self->service($mysrv)));
	}

	return undef;
}

sub firewallHelper
{
	my $self = shift;
	if ($self->anyInService()) {
		return new EBox::MailFirewall();
	}
	return undef;
}

sub _doDaemon
{
	my ($self, $service) = @_;
	my @services = ('active', 'pop', 'imap');

	if ($self->service($service) and $self->isRunning($service)) {
		if ($service eq 'active') {
			foreach (@services) {
				$self->_daemon('restart',$_);
			}
		}
		$self->_daemon('restart', $service);
	} elsif ($self->service($service)) {
		$self->_daemon('start', $service);
	} elsif ($self->isRunning($service)) {
		$self->_daemon('stop', $service);
	}
}

sub _command
{
	my ($self, $action, $service) = @_;
	my $cmd = undef;

	if ($service eq 'active') {
		$cmd = MAILINIT . " " . $action . " 2>&1";
	} elsif ($service eq 'pop') {
		$cmd = POPINIT . " " . $action . " 2>&1";
	} elsif ($service eq 'imap') {
		$cmd = IMAPINIT . " " . $action . " 2>&1";
	} elsif ($service eq 'authdaemon') {
		$cmd = AUTHDAEMONINIT . " " . $action . " 2>&1";
	} elsif ($service eq 'authldap') {
		$cmd = AUTHLDAPINIT . " " . $action . " 2>&1";
	} else {
		throw EBox::Exceptions::Internal("Bad service: $service");
	}

	return $cmd;
}		

sub _daemon
{
	my ($self, $action, $service) = @_;

	my $command = $self->_command($action, $service);

	if ( $action eq 'start') {
		root($command);
	} elsif ( $action eq 'stop') {
		root($command);
	} elsif ( $action eq 'reload') {
		root($command);
	} elsif ( $action eq 'restart') {
		root($command);
	} else {
		throw EBox::Exceptions::Internal("Bad argument: $action");
	}
}

sub _stopService
{
	my $self = shift;
	if ($self->isRunning('active')) {
		$self->_daemon('stop', 'active');
	}
}

sub _regenConfig
{
	my $self = shift;
	my @services = ('active', 'pop', 'imap');
	$self->_setMailConf;

	foreach (@services) {
		$self->_doDaemon($_);
	}

	$self->_daemon('restart', 'authdaemon');
	$self->_daemon('restart', 'authldap');
}

#
# Method: setService
#
#  Enable/Disable the service passes as parameter.
#
# Parameters:
#
#  active - true or false
#  service - the service to enable or disable.
#
sub setService 
{
	my ($self, $active, $service) = @_;
	($active and $self->service($service)) and return;
	(!$active and !$self->service($service)) and return;
	$self->set_bool($service, $active);
}

#
# Method: service
#
#  Returns the state of the service passed as parameter
#
# Parameters:
#
#  service - the service
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub service
{
	my ($self, $service) = @_;
	defined($service) or $service = 'active';
	return $self->get_bool($service);
}

#
# Method: anyInService
#
#  Returns if any service is active
#
# Returns:
#
#  boolean - true if any is active, otherwise false
#
sub anyInService {
	my $self = shift;
	my @services = ('active', 'pop', 'imap');

	foreach (@services) {
		return 1 if $self->service($_);
	}

	return undef;
}	

# LdapModule implmentation    
sub _ldapModImplementation    
{
	my $self;

	return new EBox::MailUserLdap();
}

sub summary
{
	my $self = shift;
	my $item = new EBox::Summary::Module(__("Mail"));
	my $section = new EBox::Summary::Section();
	$item->add($section);
	my $pop = new EBox::Summary::Status('mail', __('POP3 service'),
		$self->isRunning('pop'), $self->service('pop'), 1);
	my $imap = new EBox::Summary::Status('mail', __('IMAP service'),
		$self->isRunning('imap'), $self->service('imap'), 1);

	$section->add($pop);
	$section->add($imap);

	return $item;
}

sub rootCommands
{
	my $self = shift;
	my @array = ();
	push(@array, MAILINIT);
	push(@array, POPINIT);
	push(@array, IMAPINIT);
	push(@array, AUTHDAEMONINIT);
	push(@array, AUTHLDAPINIT);

	push(@array, $self->rootCommandsForWriteConfFile(MAILMAINCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(MAILMASTERCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(POP3DCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(POP3DSSLCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(IMAPDCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(IMAPDSSLCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(AUTHDAEMONCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(AUTHLDAPCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(SASLAUTHDCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(SASLAUTHDDCONFFILE));
	push(@array, $self->rootCommandsForWriteConfFile(SMTPDCONFFILE));

	push(@array, "/bin/chmod 2775 /var/mail/");
	push(@array, "/bin/chown ebox.ebox -R /var/vmail/*");
	push(@array, "/bin/chown ebox.ebox /var/vmail/*");
	push(@array, "/bin/mkdir -p /var/vmail*");
	push(@array, "/usr/bin/maildirmake /var/vmail/*");
	push(@array, "/bin/rm -rf /var/vmail/*");
	push(@array, "/usr/bin/mailq");
	push(@array, "/usr/sbin/postsuper");
	push(@array, "/usr/sbin/postcat");

	return @array;
}

sub statusSummary
{
	my $self = shift;
	return new EBox::Summary::Status('mail', __('Mail system'),
		$self->isRunning('active'), $self->service('active'));
}

sub menu
{
	my ($self, $root) = @_;

	my $folder = new EBox::Menu::Folder('name' => 'Mail',
		'text' => __('Mail'));

	$folder->add(new EBox::Menu::Item('url' => 'Mail/Index',
			'text' => __('General')));

	$folder->add(new EBox::Menu::Item('url' => 'Mail/VDomains',
			'text' => __('Virtual domains')));

	$folder->add(new EBox::Menu::Item('url' => 'Mail/QueueManager',
			'text' => 'Queue Management'));

	$root->add($folder);
}

sub tableInfo {
	my $self = shift;
	my $titles = { 'postfix_date' => __('Date'),
						'message_id' => __('Message ID'),
						'from_address' => __('From'),
						'to_address' => __('To'),
						'client_host_name' => __('From hostname'),
						'client_host_ip' => __('From host ip'),
						'message_size' => __('Size (bytes)'),
						'relay' => __('Relay'),
						'status' => __('Status'),
						'event' => __('Event'),
						'message' => __('Aditional Info')
					};
	my @order = ('postfix_date', 'from_address',
		'to_address', 'client_host_ip',
		'message_size', 'relay', 'status', 'event', 'message');

	my $events = { 'msgsent' => __('Successful messages'),
		'maxmsgsize' => __('Maximum message size exceeded'),
		'maxusrsize' => __('User quote exceeded'),
		'norelay' => __('Relay access denied'),
		'noaccount' => __('Account do not exists'),
		'nohost' => __('Host unreachable'),
		'noauth' => __('Authentication error'),
		'other' => __('Other events') };

	return {
		'name' => __('Mail'),
		'index' => 'mail',
		'titles' => $titles,
		'order' => \@order,
		'tablename' => 'message',
		'timecol' => 'postfix_date',
		'filter' => ['from_address', 'to_address', 'status'],
		'events' => $events,
		'eventcol' => 'event'
	};
}

sub logHelper
{
	return (new EBox::MailLogHelper);
}

1;
