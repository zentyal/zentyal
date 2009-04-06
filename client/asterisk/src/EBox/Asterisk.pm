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
            EBox::FirewallObserver EBox::UserCorner::Provider);

use strict;
use warnings;

use EBox::Gettext;
use EBox::Global;
use EBox::Ldap;
use EBox::AsteriskLdapUser;
use EBox::Asterisk::Extensions;

use constant MODULESCONFFILE      => '/etc/asterisk/modules.conf';
use constant EXTCONFIGCONFFILE    => '/etc/asterisk/extconfig.conf';
use constant RESLDAPCONFFILE      => '/etc/asterisk/res_ldap.conf';
use constant SIPCONFFILE          => '/etc/asterisk/sip.conf';
use constant RTPCONFFILE          => '/etc/asterisk/rtp.conf';
use constant EXTNCONFFILE         => '/etc/asterisk/extensions.conf';
use constant MEETMECONFFILE       => '/etc/asterisk/meetme.conf';

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
            printableName => __('Asterisk'),
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
        'EBox::Asterisk::Model::Meetings',
        'EBox::Asterisk::Model::Voicemail',
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

    push (@usedFiles, { 'file' => MEETMECONFFILE,
                        'module' => 'asterisk',
                        'reason' => __('To configure the conferences.')
                      });

    push (@usedFiles, {
                        'file' => '/etc/ldap/slapd.conf',
                        'reason' => __('To add a new schema'),
                        'module' => 'users'
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
        return new EBox::SambaFirewall();
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

    $self->writeConfFile(MODULESCONFFILE, "asterisk/modules.conf.mas");
    $self->writeConfFile(EXTCONFIGCONFFILE, "asterisk/extconfig.conf.mas");
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

    push (@params, password => EBox::Ldap->getPassword());

    $self->writeConfFile(RESLDAPCONFFILE, "asterisk/res_ldap.conf.mas", \@params);
}


# set up the extensions configuration on extensions.conf
sub _setExtensions
{
    my ($self) = @_;

    my @params = ();

    my $model = $self->model('Settings');

    push (@params, outgoingcalls => $model->outgoingCallsValue());

    $model = $self->model('Provider');

    push (@params, name => $model->nameValue());

    $self->writeConfFile(EXTNCONFFILE, "asterisk/extensions.conf.mas", \@params);
}


# set up the Voicemail configuration on LDAP
sub _setVoicemail
{
    my ($self) = @_;

    my $model = $self->model('Settings');
    my $vmextn = $model->voicemailExtnValue();

    my $extensions = new EBox::Asterisk::Extensions;

    if ($extensions->extensionExists($vmextn)) {
        $extensions->delExtension("$vmextn-1"); #FIXME not so cool
    }
    $extensions->addExtension($vmextn, 1, 'VoicemailMain', 'users');
}


# set up the sip.conf file
sub _setSIP
{
    my ($self) = @_;

    my @params = ();

    my $model = $self->model('NAT');

    my @localnets = ();
    if ($model->behindNATValue()) {
        my $network = my $ifaces = EBox::Global->modInstance('network');
        my $ifaces = $network->InternalIfaces();
        for my $iface (@{$ifaces}) {
            push(@localnets, $network->ifaceNetwork($iface).'/'.$network->ifaceNetmask($iface));
        }
    }

    push (@params, behindNAT => $model->behindNATValue());
    push (@params, externalIP => $model->externalIPValue());
    push (@params, localnets => \@localnets);

    $model = $self->model('Settings');

    push (@params, outgoingcalls => $model->outgoingCallsValue());

    $model = $self->model('Provider');

    push (@params, name => $model->nameValue());
    push (@params, username => $model->usernameValue());
    push (@params, password => $model->passwordValue());
    push (@params, server => $model->serverValue());
    push (@params, incoming => $model->incomingValue());

    $self->writeConfFile(SIPCONFFILE, "asterisk/sip.conf.mas", \@params);
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
        my $adminpin = $row->valueByName('adminpin');
        push (@meetings, { exten => $exten,
                           pin => $pin,
                           adminpin => $adminpin,
                         });
        #$extns->addExtension($alias, 1, 'GoTo', $exten); #FIXME when we delete these extensions? XXX
        $extns->addExtension($exten, 1, 'MeetMe', $exten); #FIXME when we delete these extensions? XXX
    }

    my @params = ( meetings => \@meetings );

    $self->writeConfFile(MEETMECONFFILE, "asterisk/meetme.conf.mas", \@params);
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
                                        'text' => __('Asterisk'));

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

1;
