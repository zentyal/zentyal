# Copyright (C) 2007 Warp Networks S.L.
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
use strict;
use warnings;

package EBox::Squid::Model::GeneralSettings;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Int;
use EBox::Types::Text;
use EBox::Types::Boolean;
use EBox::Types::IPAddr;
use EBox::Types::Port;
use EBox::Sudo;

use EBox::Exceptions::External;

sub _table
{
    my ($self) = @_;

    my @tableDesc = (
          new EBox::Types::Boolean(
                  fieldName => 'transparentProxy',
                  printableName => __('Transparent Proxy'),
                  editable => 1,
                  defaultValue => 0,
              ),
#           new EBox::Types::Boolean(
#                   fieldName => 'https',
#                   printableName => __('HTTPS Proxy'),
#                   hidden => \&_sslSupportNotAvailable,
#                   editable => 1,
#                   defaultValue => 0,
#                   #help => __('FIXME: add help'),
#               ),
          new EBox::Types::Boolean(
                  fieldName => 'kerberos',
                  printableName => __('Enable Single Sign-On (Kerberos)'),
                  editable => \&_kerberosEnabled,
                  defaultValue => 0,
              ),
          new EBox::Types::Boolean(
                  fieldName => 'removeAds',
                  printableName => __('Ad Blocking'),
                  editable => 1,
                  defaultValue => 0,
                  help => __('Remove advertisements from all HTTP traffic')
              ),
          new EBox::Types::Port(
                  fieldName => 'port',
                  printableName => __('Port'),
                  editable => 1,
                  defaultValue => $self->parentModule->SQUID_PORT(),
               ),
          new EBox::Types::Int(
                  fieldName => 'cacheDirSize',
                  printableName => __('Cache files size (MB)'),
                  editable => 1,
                  size => 5,
                  min  => 10,
                  defaultValue => 100,
               ),
    );

    my $dataForm = {
                    tableName          => 'GeneralSettings',
                    printableTableName => __('General Settings'),
                    modelDomain        => 'Squid',
                    defaultActions     => [ 'editField', 'changeView' ],
                    tableDescription   => \@tableDesc,
                    messages           => {
                        update => __('Settings changed'),
                    },
    };

    return $dataForm;
}

# Method: viewCustomizer
#
#      To display a permanent message
#
# Overrides:
#
#      <EBox::Model::DataTable::viewCustomizer>
#
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = $self->SUPER::viewCustomizer();

    my $securityUpdatesAddOn = 0;
    if (EBox::Global->modExists('remoteservices')) {
        my $rs = EBox::Global->modInstance('remoteservices');
        $securityUpdatesAddOn = $rs->securityUpdatesAddOn();
    }

    unless ($securityUpdatesAddOn) {
        $customizer->setPermanentMessage($self->_commercialMsg(), 'ad');
    }

    return $customizer;
}

sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    if (exists $params_r->{port}) {
        $self->_checkPortAvailable($params_r->{port}->value());
    }

    my $trans = exists $params_r->{transparentProxy} ?
                        $params_r->{transparentProxy}->value() :
                        $actual_r->{transparentProxy}->value() ;
    if ($trans) {
        if ($self->parentModule()->authNeeded()) {
            throw EBox::Exceptions::External(
                __('Transparent proxy is incompatible with the users group authorization policy found in some access rules')
               );
        }

        my $kerberos =  exists $params_r->{kerberos} ?
                         $params_r->{kerberos}->value() :
                         $actual_r->{kerberos}->value() ;
        if ($kerberos) {
            throw EBox::Exceptions::External(
                __('Transparent proxy is incompatible with Kerberos authentication')
               );
        }
#         my $https =  exists $params_r->{https} ?
#                          $params_r->{https}->value() :
#                          $actual_r->{https}->value() ;
#         if ($https) {
#             throw EBox::Exceptions::External(
#                 __('Transparent proxy is incompatible with HTTPS proxy')
#                );
#         }

    }
}

# Method: row
#
#   Overrided to enable the kerberos authentication when using
#   external AD authentication
#
sub row
{
    my ($self) = @_;

    my $row = $self->SUPER::row();
    my $mode = $self->parentModule->authenticationMode();
    if ($mode eq $self->parentModule->AUTH_MODE_EXTERNAL_AD()) {
        my $elem = $row->elementByName('kerberos');
        unless ($elem->value()) {
            $elem->setValue(1);
        }
    }
    return $row;
}

sub _checkPortAvailable
{
    my ($self, $port) = @_;

    my $oldPort = $self->portValue();
    if ($port == $oldPort) {
        # there isn't any change so we left tht things as they are
        return;
    }

    my $firewall = EBox::Global->modInstance('firewall');
    if (not $firewall->availablePort('tcp', $port)) {
        throw EBox::Exceptions::External(__x('{port} is already in use. Please choose another', port => $port));
    }
}

sub _transparentHelp
{
    return  __('Note that you cannot proxy HTTPS ' .
               'transparently. You will need to add ' .
               'a firewall rule if you enable this mode.');
}

sub _commercialMsg
{
    return __sx('Want to remove ads from the websites your users browse? Get the {oh}Commercial editions{ch} that will keep your Ad blocking rules always up-to-date.',
                oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
}

sub _sslSupportNotAvailable
{
    return system('ldd /usr/sbin/squid3 | grep -q libssl') != 0;
}

sub _kerberosEnabled
{
    my $mod = EBox::Global->modInstance('squid');
    my $mode = $mod->authenticationMode();

    return 0 if ($mode eq $mod->AUTH_MODE_EXTERNAL_AD());
    return 1;
}

1;
