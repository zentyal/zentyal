# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Asterisk;

use base qw(EBox::Module::Service EBox::LdapModule
            EBox::UserCorner::Provider EBox::LogObserver);

use EBox;
use EBox::Global;
use EBox::Gettext;
use EBox::Config;
use EBox::Ldap;
use EBox::Dashboard::Widget;
use EBox::Dashboard::List;

use EBox::AsteriskLdapUser;
use EBox::AsteriskLogHelper;
use EBox::Asterisk::Extensions;

use Net::IP;
use Error qw(:try);

use constant MODULESCONFFILE      => '/etc/asterisk/modules.conf';
use constant EXTCONFIGCONFFILE    => '/etc/asterisk/extconfig.conf';
use constant RESLDAPCONFFILE      => '/etc/asterisk/res_ldap.conf';
use constant SIPCONFFILE          => '/etc/asterisk/sip.conf';
use constant EXTNCONFFILE         => '/etc/asterisk/extensions.conf';
use constant VOICEMAILCONFFILE    => '/etc/asterisk/voicemail.conf';
use constant MOHCONFFILE          => '/etc/asterisk/musiconhold.conf';
use constant FEATURESCONFFILE     => '/etc/asterisk/features.conf';
use constant QUEUESCONFFILE       => '/etc/asterisk/queues.conf';

use constant VOICEMAIL_DIR        => '/var/spool/asterisk/voicemail';

use constant EBOX_VOIP_SRVNAME    => 'zentyal';
use constant EBOX_SIP_SERVER      => 'sip.zentyal.com';

use constant ASTERISK_REALM       => 'asterisk';

# Constructor: _create
#
#      Create a new EBox::Asterisk module object
#
# Returns:
#
#      <EBox::Asterisk> - the recently created model
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'asterisk',
            printableName => __('VoIP'),
            @_);

    bless($self, $class);

    return $self;
}

# Method: usedFiles
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::usedFiles>
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => MODULESCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure enabled and disabled modules.')
                      });

    push (@usedFiles, { 'file' => EXTCONFIGCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the Realtime interface.')
                      });

    push (@usedFiles, { 'file' => RESLDAPCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the LDAP Realtime driver.')
                      });

    push (@usedFiles, { 'file' => SIPCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the SIP trunk for local users and external providers.')
                      });

    push (@usedFiles, { 'file' => EXTNCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the dialplan.')
                      });

    push (@usedFiles, { 'file' => VOICEMAILCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the voicemail.')
                      });

    push (@usedFiles, { 'file' => MOHCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the music on hold.')
                      });
    push (@usedFiles, { 'file' => FEATURESCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure DTMF behaviour.')
                      });
    push (@usedFiles, { 'file' => QUEUESCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the queues.')
                      });
    return \@usedFiles;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    # Create default rules and services
    # only if installing the first time
    unless ($version) {
        my $services = EBox::Global->modInstance('services');

        my $serviceName = 'VoIP';
        unless($services->serviceExists(name => $serviceName)) {
            $services->addMultipleService(
                'name' => $serviceName,
                'description' => __('Zentyal VoIP system'),
                'internal' => 1,
                'readOnly' => 1,
                'services' => $self->_services(),
            );
        }

        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->setExternalService($serviceName, 'deny');
        $firewall->setInternalService($serviceName, 'accept');

        $firewall->saveConfigRecursive();
    }

    # Execute initial-setup script
    $self->SUPER::initialSetup($version);
}

sub _services
{
    return [
             { # sip
                 'protocol' => 'udp',
                 'sourcePort' => 'any',
                 'destinationPort' => '5060',
             },
             { # iax1
                 'protocol' => 'udp',
                 'sourcePort' => 'any',
                 'destinationPort' => '4569',
             },
             { # iax2
                 'protocol' => 'udp',
                 'sourcePort' => 'any',
                 'destinationPort' => '5036',
             },
             { # rtp
                 'protocol' => 'udp',
                 'sourcePort' => 'any',
                 'destinationPort' => '10000:20000',
             },
    ];
}

# Method: enableActions
#
# Overrides:
#
#      <EBox::ServiceModule::ServiceInterface::enableActions>
#
sub enableActions
{
    my ($self) = @_;
    $self->checkUsersMode();

    $self->performLDAPActions();

    # Execute enable-module script
    $self->SUPER::enableActions();
}

# Method: reprovisionLDAP
#
# Overrides:
#
#      <EBox::LdapModule::reprovisionLDAP>
sub reprovisionLDAP
{
    my ($self) = @_;

    $self->SUPER::reprovisionLDAP();

    # regenerate asterisk ldap tree
    EBox::Sudo::root('/usr/share/zentyal-asterisk/asterisk-ldap update');
}

# Method: _daemons
#
# Overrides:
#
#      <EBox::Module::Service::_daemons>
#
sub _daemons
{
    return [
        {
            'name' => 'asterisk',
            'type' => 'init.d',
        }
    ];
}

# Method: _setConf
#
# Overrides:
#
#      <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my @params;
    my $ldapConf = $self->ldap->ldapConf();
    push (@params, dn => $ldapConf->{'dn'});

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];

    $self->writeConfFile(MODULESCONFFILE, "asterisk/modules.conf.mas",
                         [], { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });

    $self->writeConfFile(EXTCONFIGCONFFILE, "asterisk/extconfig.conf.mas",
        \@params, { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
    $self->writeConfFile(MOHCONFFILE, "asterisk/musiconhold.conf.mas",
                         [], { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
    $self->writeConfFile(FEATURESCONFFILE, "asterisk/features.conf.mas",
                         [], { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });

    $self->_setRealTime();
    $self->_setExtensions();
    $self->_setVoicemail();
    $self->_setSIP();
    $self->_setQueues();
}

sub _setRealTime
{
    my ($self) = @_;

    my @params = ();

    my $users = EBox::Global->modInstance('users');

    my $ldapConf = $self->ldap->ldapConf();
    push (@params, url => $ldapConf->{'ldap'});
    push (@params, port => $ldapConf->{'port'});
    push (@params, dn => $ldapConf->{'dn'});
    push (@params, rootdn => $ldapConf->{'rootdn'});
    push (@params, password => $self->ldap->getPassword());

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(RESLDAPCONFFILE, "asterisk/res_ldap.conf.mas", \@params,
                            { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}

sub _setExtensions
{
    my ($self) = @_;

    my @params = ();

    my $model = $self->model('Settings');

    push (@params, demoextensions => $model->demoExtensionsValue());
    push (@params, outgoingcalls => $model->outgoingCallsValue());
    push (@params, domain => $model->domainValue());

    $model = $self->model('Provider');

    push (@params, name => $model->nameValue());

    $model = $self->model('Meetings');

    push (@params, meetings => $model->getMeetings());

    push (@params, users => $self->_getUsers());

    push (@params, queues => $self->_getQueues());

    #my $network = EBox::Global->modInstance('network');
    #my $ifaces = $network->InternalIfaces();
    #my @localaddrs = ();
    #for my $iface (@{$ifaces}) {
    #    push(@localaddrs, $network->ifaceAddress($iface));
    #}
    #push (@params, localaddrs => \@localaddrs);

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(EXTNCONFFILE, "asterisk/extensions.conf.mas", \@params,
                         { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}

sub _getUsers
{
    my ($self) = @_;

    my @usersExtens = ();

    my $users = EBox::Global->getInstance()->modInstance('users');

    foreach my $user (@{$users->users()}) {
        my $extensions = new EBox::Asterisk::Extensions;
        my $extn = $extensions->getUserExtension($user);
        next unless $extn; # if user doesn't have an extension we are done

        my $userextn = {};
        $userextn->{'username'} = $user->name();
        $userextn->{'extn'} = $extn;
        $userextn->{'dopts'} = $extensions->DOPTS;
        $userextn->{'vmopts'} = $extensions->VMOPTS;
        $userextn->{'vmoptsf'} = $extensions->VMOPTSF;

        push (@usersExtens, $userextn);
    }

    return \@usersExtens;
}

sub _getQueues
{
    my ($self) = @_;

    my @queues = ();

    my $usersMod = EBox::Global->modInstance('users');

    my $extensions = new EBox::Asterisk::Extensions;

    foreach my $queue (@{$extensions->queues()}) {
        my $group = $usersMod->groupByName($queue);
        my @members = map { $_->name() } @{$group->users()};

        my $queueInfo = {};
        $queueInfo->{'name'} = $queue;
        $queueInfo->{'extn'} = $extensions->getQueueExtension($group);
        $queueInfo->{'members'} = \@members;

        push (@queues, $queueInfo);
    }

    return \@queues;
}

sub _setVoicemail
{
    my ($self) = @_;

    my @params = ();

    my $model = $self->model('Phones');

    push (@params, phones => $model->getPhones());

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(VOICEMAILCONFFILE, "asterisk/voicemail.conf.mas", \@params,
                         { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}

sub _setSIP
{
    my ($self) = @_;

    my @params = ();

    my $model = $self->model('NAT');

    my $nat = 'no';
    my $type = '';
    my $value = '';
    my @localnets = ();

    if ($model->getNATType()) {
        $nat = 'yes';
        ($type, $value) = @{$model->getNATType()};
        my $network = EBox::Global->modInstance('network');
        my $ifaces = $network->InternalIfaces();
        for my $iface (@{$ifaces}) {
            push(@localnets, $network->ifaceNetwork($iface).'/'.$network->ifaceNetmask($iface));
        }
        $model = $self->model('Localnets');
        foreach my $id (@{$model->ids()}) {
            my $row = $model->row($id);
            my $net = new Net::IP($row->printableValueByName('localnet'));
            push(@localnets, $net->ip().'/'.$net->mask());
        }
    }

    push (@params, nat => $nat);
    push (@params, type => $type);
    push (@params, value => $value);
    push (@params, localnets => \@localnets);

    $model = $self->model('Settings');

    push (@params, domain => $model->domainValue());
    push (@params, outgoingcalls => $model->outgoingCallsValue());

    $model = $self->model('Provider');

#    if ($model->providerValue() eq 'custom') {
#        push (@params, name => $model->nameValue());
#    } else {
#        push (@params, name => EBOX_VOIP_SRVNAME);
#    }
    push (@params, name => $model->nameValue());
#
    push (@params, username => $model->usernameValue());
    push (@params, password => $model->passwordValue());
#    if ($model->providerValue() eq 'custom') {
#        push (@params, server => $model->serverValue());
#    } else {
#        push (@params, server => EBOX_SIP_SERVER);
#    }
    push (@params, server => $model->serverValue());
#
    push (@params, incoming => $model->incomingValue());

    my $additional_codecs = EBox::Config::configkey('asterisk_additional_codecs');
    push (@params, additional_codecs => $additional_codecs);

    my $dtmfmode = EBox::Config::configkey('asterisk_dtmfmode');
    push (@params, dtmfmode => $dtmfmode);

    $model = $self->model('Phones');
    push (@params, phones => $model->getPhones());

    push (@params, realm => ASTERISK_REALM);

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(SIPCONFFILE, "asterisk/sip.conf.mas", \@params,
                            { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}

sub _setQueues
{
    my ($self) = @_;

    my @params = ();

    push (@params, queues => $self->_getQueues());

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(QUEUESCONFFILE, "asterisk/queues.conf.mas", \@params,
                         { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}

# Method: fqdn
#
#      Returns the fully qualified domain name
#
sub fqdn
{
    my $fqdn = `hostname --fqdn`;
    if ($? != 0) {
        $fqdn = 'zentyal.localdomain';
    }
    chomp $fqdn;
    return $fqdn;
}

# Method: _ldapModImplementation
#
#      All modules using any of the functions in LdapUserBase.pm
#      should override this method to return the implementation
#      of that interface.
#
# Returns:
#
#       An object implementing EBox::LdapUserBase
#
sub _ldapModImplementation
{

    my ($self) = @_;
    return new EBox::AsteriskLdapUser(ro => $self->{ro});
}

# Method: menu
#
# Overrides:
#
#      <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder('name' => 'Asterisk',
                                        'icon' => 'asterisk',
                                        'text' => $self->printableName(),
                                        'separator' => 'Communications',
                                        'order' => 630);

    $folder->add(new EBox::Menu::Item(
            'url' => 'Asterisk/Composite/General',
            'text' => __('General')));

    $folder->add(new EBox::Menu::Item(
            'url' => 'Asterisk/View/Phones',
            'text' => __('Phones')));

    $folder->add(new EBox::Menu::Item(
            'url' => 'Asterisk/View/Meetings',
            'text' => __('Meetings')));

    $root->add($folder);
}

# Method: userMenu
#
# Implements:
#
#      <EBox::UserCorner::Provider::userMenu
#
sub userMenu
{
    my ($self, $root) = @_;

    $root->add(new EBox::Menu::Item('url' => 'Asterisk/View/Voicemail',
                                    'text' => __('Voicemail')));
}

sub onlineUsersWidget
{
    my ($self, $widget) = @_;

    my $section = new EBox::Dashboard::Section('onlineusers');
    $widget->add($section);
    my $titles = [__('User'),  __('Address'), __('NAT'), __('Status')];

    my $users = $self->_sipShowPeers();

    my $rows = {};
    foreach my $user (@{$users}) {
        if ( $user->{'status'} =~m/OK/ or $user->{'status'} =~m/UNREACHABLE/ ) {
            my $id = $user->{'username'} . '_' . $user->{'addr'};
            $rows->{$id} = [$user->{'username'}, $user->{'addr'},
                            $user->{'nat'}, $user->{'status'}];
        }
    }
    my $ids = [sort keys %{$rows}];
    $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows,
                  __('No users connected.')));
}

sub _sipShowPeers
{
    my ($self) = @_;

    return [] unless ($self->isEnabled());

    my $peers = [];
    my @output;
    my $error;
    try {
        @output= @{ EBox::Sudo::root("asterisk -rx 'sip show peers'") };
    } otherwise {
        $error = 1;
    };

    return [] if ($error);

    for my $line (@output) {
        chomp($line);
        # jbernal/jbernal            87.218.95.20     D   N      1050     OK (214 ms) Cached RT
        if ( $line =~ m/\S+\/(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S.+) Cached RT/ ) {
            my ($username, $addr, $nat, $status) = ($1, $2, $4, $6);
            my $user = {};
            $user->{'username'} = $username;
            $user->{'addr'} = $addr;
            $user->{'nat'} = $nat;
            $user->{'status'} = $status;
            push(@{$peers}, $user);
        }
    }

    return $peers;
}

#sub _meetmeList
#{
#    my ($self) = @_;
#
#    return [] unless ($self->isEnabled());
#
#    my $rooms= [];
#    my @output;
#    my $error;
#    try {
#        @output= @{ EBox::Sudo::root("asterisk -rx 'meetme list'") };
#    } otherwise {
#        $error = 1;
#    };
#
#    return [] if ($error);
#
#    for my $line (@output) {
#        chomp($line);
#        # 8989           0001           N/A        02:03:32  Static    No
#        if ( $line =~ m/(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ ) {
#            my ($extn, $time) = ($1, $4);
#            my $room = {};
#            $room->{'users'} = [];
#            $room->{'name'} = $extn;
#            $room->{'time'} = $time;
#            my @output2 = @{ EBox::Sudo::root("asterisk -rx 'meetme list $extn'") };
#            for my $line2 (@output2) {
#                chomp($line2);
#                # User #: 02         1003 <no name>            Channel: SIP/juruen-08293ff8     (unmonitored) 02:37:32
#                if ( $line2 =~ m/.*Channel: (\S+)\s+(\S+)\s+(\S+)/ ) {
#                    my ($username, $utime) = ($1, $3);
#                    my $user = {};
#                    $user->{'username'} = $username;
#                    $user->{'utime'} = $utime;
#                    push(@{$room->{'users'}}, $user);
#                }
#            }
#            push(@{$rooms}, $room);
#        }
#    }
#
#    return $rooms;
#}

#sub usersByMeetingsWidget
#{
#    my ($self, $widget) = @_;
#
#    my $usersByConference = $self->_meetmeList();
#
#    for my $room (@{$usersByConference}) {
#        my $title = __x("Room {name} active for {rtime}", name => $room->{'name'}, rtime => $room->{'time'});
#        my $section = new EBox::Dashboard::Section($room->{'name'}, $title);
#        $widget->add($section);
#        my $titles = [__('User'), __('Time Connected')];
#
#        my $rows = {};
#        foreach my $user (@{$room->{'users'}}) {
#            my $id = $user->{'username'};
#            $rows->{$id} = [$user->{'username'}, $user->{'utime'}];
#        }
#        my $ids = [sort keys %{$rows}];
#        $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows,
#                  __('No users connected.')));
#    }
#}

# Method: widgets
#
# Overrides:
#
#      <EBox::Module::widgets>
#
sub widgets
{
    my ($self) = @_;

    if (not $self->isEnabled()) {
        return {};
    }

    my $widgets = {
        'onlineusers' => {
            'title' => __('VoIP Online Users'),
            'widget' => \&onlineUsersWidget,
            'order' => 11,
            'default' => 1
        },
# XXX not working with ConfBridge yet
#        'usersbyconference' => {
#            'title' => __('VoIP Users in Meetings'),
#            'widget' => \&usersByMeetingsWidget,
#            'order' => 12,
#            'default' => 1
#        }
    };

    return $widgets;
}

# Method: logHelper
#
# Overrides:
#
#       <EBox::LogObserver::logHelper>
#
sub logHelper
{
    my ($self) = @_;

    return (new EBox::AsteriskLogHelper);
}

# Method: tableInfo
#
# Overrides:
#
#       <EBox::LogObserver::tableInfo>
#
sub tableInfo
{
    my $self = shift;
    my $titles = {
                   'timestamp' => __('Date'),
                   'src' => __('From'),
                   'dst' => __('To'),
                   'duration' => __('Duration'),
                   'channel' => __('Channel'),
                   'dstchannel' => __('Destination Channel'),
                   'lastapp' => __('Application'),
                   'lastdata' => __('Application Data'),
                   'disposition' => __('Event')
    };
    my @order = (
                 'timestamp', 'src', 'dst',
                 'duration', 'lastapp', 'disposition'
    );

    my $events = {
                   'ANSWERED' => __('Answered'),
                   'NO ANSWER' => __('No Answer'),
                   'BUSY' => __('Busy'),
                   'FAILED' => __('Failed')
    };

    return [{
            'name' => __('VoIP'),
            'tablename' => 'asterisk_cdr',
            'titles' => $titles,
            'order' => \@order,
            'timecol' => 'timestamp',
            'filter' => ['src', 'dst'],
            'events' => $events,
            'eventcol' => 'disposition'
    }];
}

sub _backupArchiveFile
{
    my ($self, $dir) = @_;
    return "$dir/asterisk.tar";
}

1;
