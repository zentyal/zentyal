# Copyright (C) 2007 Warp Networks S.L.
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

    my $samba = $self->global()->modInstance('samba');
    my $commercial = (not $self->global()->communityEdition());

    my @tableDesc = (
          new EBox::Types::Boolean(
                  fieldName => 'transparentProxy',
                  printableName => __('Transparent Proxy'),
                  editable => 1,
                  defaultValue => 0,
              ),
    );
    if ($commercial and $samba and $samba->isEnabled()) {
        push (@tableDesc,
          new EBox::Types::Boolean(
                  fieldName => 'kerberos',
                  printableName => __('Enable Single Sign-On (Kerberos)'),
                  editable => 1,
                  defaultValue => 0,
              ),
        );
    }
    push (@tableDesc,
          new EBox::Types::Port(
                  fieldName => 'port',
                  printableName => __('Port'),
                  editable => 1,
                  defaultValue => $self->parentModule->DEFAULT_PORT(),
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

        if (($params_r->{kerberos} and $params_r->{kerberos}->value()) or
            ($actual_r->{kerberos} and $actual_r->{kerberos}->value())) {
            throw EBox::Exceptions::External(
                __('Transparent proxy is incompatible with Kerberos authentication')
               );
        }
    }
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

sub _commercialMsg
{
    return __sx('Want to remove ads from the websites your users browse? Get the {oh}Commercial editions{ch} that will keep your Ad blocking rules always up-to-date.',
                oh => '<a href="' . EBox::Config::urlEditions() . '" target="_blank">', ch => '</a>');
}

1;
