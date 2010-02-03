# Copyright (C) 2008 eBox Technologies S.L.
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


package EBox::Asterisk;

# Class: EBox::Asterisk
#
#

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider EBox::LdapModule
            EBox::FirewallObserver EBox::LogObserver
            EBox::UserCorner::Provider);

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Ldap;
use EBox::Dashboard::Widget;
use EBox::Dashboard::List;
use EBox::AsteriskLdapUser;
use EBox::AsteriskFirewall;
use EBox::AsteriskLogHelper;
use EBox::Asterisk::Extensions;

use Net::IP;
use Error qw(:try);

use constant MODULESCONFFILE      => '/etc/asterisk/modules.conf';
use constant EXTCONFIGCONFFILE    => '/etc/asterisk/extconfig.conf';
use constant RESLDAPCONFFILE      => '/etc/asterisk/res_ldap.conf';
use constant USERSCONFFILE        => '/etc/asterisk/users.conf';
use constant SIPCONFFILE          => '/etc/asterisk/sip.conf';
use constant RTPCONFFILE          => '/etc/asterisk/rtp.conf';
use constant EXTNCONFFILE         => '/etc/asterisk/extensions.conf';
use constant MEETMECONFFILE       => '/etc/asterisk/meetme.conf';
use constant VOICEMAILCONFFILE    => '/etc/asterisk/voicemail.conf';
use constant MOHCONFFILE          => '/etc/asterisk/musiconhold.conf';
use constant FEATURESCONFFILE     => '/etc/asterisk/features.conf';

use constant VOICEMAIL_DIR        => '/var/spool/asterisk/voicemail';

use constant EBOX_VOIP_SRVNAME    => 'ebox-technologies';
use constant EBOX_SIP_SERVER      => 'sip.ebox-technologies.com';

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
            printableName => __n('VoIP'),
            domain => 'ebox-asterisk',
            @_);

    bless($self, $class);

    return $self;
}


# Method: modelClasses
#
# Overrides:
#
#      <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
        'EBox::Asterisk::Model::Settings',
        'EBox::Asterisk::Model::Provider',
        'EBox::Asterisk::Model::NAT',
        'EBox::Asterisk::Model::Localnets',
        'EBox::Asterisk::Model::Meetings',
        'EBox::Asterisk::Model::Voicemail',
        'EBox::Asterisk::Model::AsteriskUser',
    ];
}


# Method: compositeClasses
#
# Overrides:
#
#      <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
        'EBox::Asterisk::Composite::General',
    ];
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

    push (@usedFiles, { 'file' => USERSCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the common SIP and IAX users.')
                      });

    push (@usedFiles, { 'file' => SIPCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the SIP trunk for local users and external providers.')
                      });

    push (@usedFiles, { 'file' => RTPCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the RTP port ranges.')
                      });

    push (@usedFiles, { 'file' => EXTNCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the dialplan.')
                      });

    push (@usedFiles, { 'file' => VOICEMAILCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the voicemail.')
                      });

    push (@usedFiles, { 'file' => MEETMECONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the conferences.')
                      });
    push (@usedFiles, { 'file' => MOHCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the music on hold.')
                      });
    push (@usedFiles, { 'file' => FEATURESCONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure DTMF behaviour.')
                      });
    return \@usedFiles;
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

    $self->performLDAPActions();

    EBox::Sudo::root(EBox::Config::share() .
                     '/ebox-asterisk/ebox-asterisk-enable');
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
            'name' => 'ebox.asterisk'
        }
    ];
}


# Method: enableService
#
# Overrides:
#
#      <EBox::Module::Service::enableService>
#
sub enableService
{
    my ($self, $status) = @_;

    $self->SUPER::enableService($status);
}


# Method: firewallHelper
#
# Overrides:
#
#      <EBox::FirewallObserver::firewallHelper>
#
sub firewallHelper
{
    my ($self, $status) = @_;

    if ($self->isEnabled()) {
        return new EBox::AsteriskFirewall();
    }
    return undef;
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
    $self->writeConfFile(USERSCONFFILE, "asterisk/users.conf.mas",
                         [], { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
    $self->writeConfFile(MOHCONFFILE, "asterisk/musiconhold.conf.mas",
                         [], { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
    $self->writeConfFile(FEATURESCONFFILE, "asterisk/features.conf.mas",
                         [], { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
    $self->writeConfFile(VOICEMAILCONFFILE, "asterisk/voicemail.conf.mas",
                         [], { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });

    $self->_setRealTime();
    $self->_setExtensions();
    $self->_setVoicemail();
    $self->_setSIP();
    $self->_setMeetings();
}


# set up the RealTime configuration on res_ldap.conf
sub _setRealTime
{
    my ($self) = @_;

    my @params = ();

    my $users = EBox::Global->modInstance('users');

    my $ldapConf = $self->ldap->ldapConf();
    push (@params, url => $ldapConf->{'ldap'});
    push (@params, dn => $ldapConf->{'dn'});
    push (@params, rootdn => $ldapConf->{'rootdn'});
    push (@params, password => $self->ldap->getPassword());

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(RESLDAPCONFFILE, "asterisk/res_ldap.conf.mas", \@params,
                            { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}


# set up the extensions configuration on extensions.conf
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

    my $network = EBox::Global->modInstance('network');
    my $ifaces = $network->InternalIfaces();
    my @localaddrs = ();
    for my $iface (@{$ifaces}) {
        push(@localaddrs, $network->ifaceAddress($iface));
    }

    push (@params, localaddrs => \@localaddrs);

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(EXTNCONFFILE, "asterisk/extensions.conf.mas", \@params,
                         { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}


# set up the Voicemail configuration on LDAP
sub _setVoicemail
{
    my ($self) = @_;
    
    my $model = $self->model('Settings');
    my $vmextn = $model->voicemailExtnValue();

    my $extensions = new EBox::Asterisk::Extensions;

    $extensions->cleanUpVoicemail();

    $extensions->addExtension($vmextn, 1, 'VoicemailMain', 'users');
}


# set up the sip.conf file
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

    if ($model->providerValue() eq 'custom') {
        push (@params, name => $model->nameValue());
    } else {
        push (@params, name => EBOX_VOIP_SRVNAME);
    }
    push (@params, username => $model->usernameValue());
    push (@params, password => $model->passwordValue());
    if ($model->providerValue() eq 'custom') {
        push (@params, server => $model->serverValue());
    } else {
        push (@params, server => EBOX_SIP_SERVER);
    }
    push (@params, incoming => $model->incomingValue());

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(SIPCONFFILE, "asterisk/sip.conf.mas", \@params,
                            { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}


# set up the meetings on meetme.conf
sub _setMeetings
{
    my ($self) = @_;

    my $model = $self->model('Meetings');

    my $extns = new EBox::Asterisk::Extensions;

    $extns->cleanUpMeetings();

    my @meetings = ();
    foreach my $meeting (@{$model->ids()}) {
        my $row = $model->row($meeting);
        my $exten = $row->valueByName('exten');
        #my $alias = $row->valueByName('alias'); FIXME not implemented yet
        my $pin = $row->valueByName('pin');
        my $options = ",s";
        my $data = $exten . $options;
        push (@meetings, { exten => $exten,
                           pin => $pin,
                         });
        #$extns->addExtension($alias, 1, 'GoTo', $exten); #FIXME when we delete these extensions? XXX
        $extns->addExtension($exten, 1, 'MeetMe', $data);
    }

    my @params = ( meetings => \@meetings );

    my $astuid = (getpwnam('asterisk'))[2];
    my $astgid = (getpwnam('asterisk'))[3];
    $self->writeConfFile(MEETMECONFFILE, "asterisk/meetme.conf.mas", \@params,
                            { 'uid' => $astuid, 'gid' => $astgid, mode => '640' });
}


# Method: fqdn
#FIXME doc
sub fqdn
{
    my $fqdn = `hostname --fqdn`;
    if ($? != 0) {
        $fqdn = 'ebox.localdomain';
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
    return new EBox::AsteriskLdapUser();
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
                                        'text' => $self->printableName(),
                                        'separator' => 'Communications',
                                        'order' => 630);

    $folder->add(new EBox::Menu::Item(
            'url' => 'Asterisk/Composite/General',
            'text' => __('General')));

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

    $root->add(new EBox::Menu::Item('url' => '/Asterisk/View/Voicemail',
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


sub _meetmeList
{
    my ($self) = @_;

    return [] unless ($self->isEnabled());

    my $rooms= [];
    my @output;
    my $error;
    try {
        @output= @{ EBox::Sudo::root("asterisk -rx 'meetme list'") };
    } otherwise {
        $error = 1;
    };

    return [] if ($error);

    for my $line (@output) {
        chomp($line);
        # 8989           0001           N/A        02:03:32  Static    No
        if ( $line =~ m/(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/ ) {
            my ($extn, $time) = ($1, $4);
            my $room = {};
            $room->{'users'} = [];
            $room->{'name'} = $extn;
            $room->{'time'} = $time;
            my @output2 = @{ EBox::Sudo::root("asterisk -rx 'meetme list $extn'") };
            for my $line2 (@output2) {
                chomp($line2);
                # User #: 02         1003 <no name>            Channel: SIP/juruen-08293ff8     (unmonitored) 02:37:32
                if ( $line2 =~ m/.*Channel: (\S+)\s+(\S+)\s+(\S+)/ ) {
                    my ($username, $utime) = ($1, $3);
                    my $user = {};
                    $user->{'username'} = $username;
                    $user->{'utime'} = $utime;
                    push(@{$room->{'users'}}, $user);
                }
            }
            push(@{$rooms}, $room);
        }
    }

    return $rooms;
}


sub usersByMeetingsWidget
{
    my ($self, $widget) = @_;

    my $usersByConference = $self->_meetmeList();

    for my $room (@{$usersByConference}) {
        my $title = __x("Room {name} active for {rtime}", name => $room->{'name'}, rtime => $room->{'time'});
        my $section = new EBox::Dashboard::Section($room->{'name'}, $title);
        $widget->add($section);
        my $titles = [__('User'), __('Time Connected')];

        my $rows = {};
        foreach my $user (@{$room->{'users'}}) {
            my $id = $user->{'username'};
            $rows->{$id} = [$user->{'username'}, $user->{'utime'}];
        }
        my $ids = [sort keys %{$rows}];
        $section->add(new EBox::Dashboard::List(undef, $titles, $ids, $rows,
                  __('No users connected.')));
    }
}


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

    return {
        'onlineusers' => {
            'title' => __("VoIP Online Users"),
                'widget' => \&onlineUsersWidget,
                'default' => 1
        },
        'usersbyconference' => {
            'title' => __("VoIP Users in Meetings"),
                'widget' => \&usersByMeetingsWidget,
                'default' => 1
        }
    };
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
            'index' => 'asterisk',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'asterisk_cdr',
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

sub extendedBackup
{
  my ($self, %params) = @_;
  my $dir = $params{dir};
  my $archiveFile = $self->_backupArchiveFile($dir);

  my @dirsToBackup = map { "'$_'"  } (
          VOICEMAIL_DIR,
         );

  my $tarCmd= "/bin/tar -cf $archiveFile  --atime-preserve --absolute-names --preserve --same-owner @dirsToBackup";
  EBox::Sudo::root($tarCmd)
}

sub extendedRestore
{
  my ($self, %params) = @_;
  my $dir = $params{dir};
  my $archiveFile = $self->_backupArchiveFile($dir);
  if (not -e $archiveFile) {
      return;
  }

  my $tarCmd = "/bin/tar -xf $archiveFile --atime-preserve --absolute-names --preserve --same-owner";
  EBox::Sudo::root($tarCmd);
}

1;
