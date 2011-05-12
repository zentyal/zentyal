# Copyright (C) 2011 eBox Technologies S.L.
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

package EBox::PPTP;

# Class: EBox::PPTP
#
#

use base qw(EBox::Module::Service EBox::Model::ModelProvider
            EBox::Model::CompositeProvider EBox::FirewallObserver);

use strict;
use warnings;

use EBox::Global;
use EBox::Gettext;

use Net::IP;

use constant PPTPDCONFFILE => '/etc/pptpd.conf';
use constant OPTIONSCONFFILE => '/etc/ppp/pptpd-options';
use constant CHAPSECRETSFILE => '/etc/ppp/chap-secrets';

# Constructor: _create
#
#      Create a new EBox::PPTP module object
#
# Returns:
#
#      <EBox::PPTP> - the recently created model
#
sub _create
{
    my $class = shift;

    my $self = $class->SUPER::_create(name => 'pptp',
            printableName => 'PPTP',
            domain => 'zentyal-pptp',
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
        'EBox::PPTP::Model::Config',
        'EBox::PPTP::Model::Users',
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
        'EBox::PPTP::Composite::General',
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

    push (@usedFiles, { 'file' => PPTPDCONFFILE,
                        'module' => 'pptp',
                        'reason' => __('To configure PPTP server.')
                      },
                      { 'file' => OPTIONSCONFFILE,
                        'module' => 'pptp',
                        'reason' => __('To configure PPTP options.')
                      },
                      { 'file' => CHAPSECRETSFILE,
                        'module' => 'pptp',
                        'reason' => __('To configure PPTP users.')
                      },
         );

    return \@usedFiles;
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
            'name' => 'pptpd',
            'type' => 'init.d',
            'pidfiles' => ['/var/run/pptpd.pid'],
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

    my $config = $self->model('Config')->row();
    my $network = $config->printableValueByName('network');
    if ($network) {
        my $ip = new Net::IP($network);
        $ip++;
        push (@params, localip => $ip->ip());
        $ip++;
        my $last = new Net::IP($ip->last_ip());
        my ($last1, $last2, $last3, $last4) = split(/\./, $last->ip());
        $last4--;
        my $remoteip = $ip->ip().'-'.$last4;
        push (@params, remoteip => $remoteip);

        $self->writeConfFile(PPTPDCONFFILE, "pptp/pptpd.conf.mas",
                             \@params, { 'uid' => 'root',
                                         'gid' => 'root',
                                         mode => '640' });
    }

    @params = ();
    push (@params, nameserver1 => $config->valueByName('nameserver1'));
    push (@params, nameserver2 => $config->valueByName('nameserver2'));
    push (@params, wins1 => $config->valueByName('wins1'));
    push (@params, wins2 => $config->valueByName('wins2'));

    $self->writeConfFile(OPTIONSCONFFILE, "pptp/pptpd-options.mas",
                         \@params, { 'uid' => 'root',
                                     'gid' => 'root',
                                     mode => '640' });

    $self->_setUsers();
}

sub _setUsers
{
    my ($self) = @_;

    my @params = ();

    my $model = $self->model('Users');

    push (@params, users => $model->getUsers());

    $self->writeConfFile(CHAPSECRETSFILE, "pptp/chap-secrets.mas", \@params,
                            { 'uid' => 'root', 'gid' => 'root', mode => '640' });
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

    my $folder = new EBox::Menu::Folder(
                                        'name' => 'VPN',
                                        'text' => 'VPN',
                                        'separator' => 'UTM',
                                        'order' => 330
                                       );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'VPN/PPTP',
                                      'text' => 'PPTP',
                                      'order' => 40
                                     )
    );

    $root->add($folder);
}

1;
