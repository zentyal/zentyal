# Copyright (C) 2010 eBox Technologies S.L.
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

# Class: EBox::FTP

package EBox::FTP;

use strict;
use warnings;

use base qw(EBox::Module::Service
            EBox::Model::ModelProvider
            EBox::FirewallObserver);


use EBox::Global;
use EBox::Gettext;
use EBox::Sudo;

sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'ftp',
            printableName => 'FTP',
            domain => 'ebox-ftp',
            @_);

    bless ($self, $class);
    return $self;
}

# Method: menu
#
#       Add an entry to the menu with this module
#
# Overrides:
#
#       <EBox::Module::menu>
#
sub menu
{
    my ($self, $root) = @_;
    $root->add(new EBox::Menu::Item('url' => 'FTP/View/Options',
                                    'text'  => $self->printableName(),
                                    'separator' => 'Infrastructure',
                                    'order' => 435));
}

# Method: modelClasses
#
#       Return the model classes used by the module.
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [ 'EBox::FTP::Model::Options' ];
}

# Method: usedFiles
#
#   Override EBox::ServiceModule::ServiceInterface::usedFiles
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, { 'file' => '/etc/vsftpd.conf',
                        'module' => 'ftp',
                        'reason' => __('To configure vsftpd')
                      });
    push (@usedFiles, { 'file' => '/etc/pam.d/vsftpd',
                        'module' => 'ftp',
                        'reason' => __('To configure vsftpd with LDAP authentication')
                      });

    return \@usedFiles;
}

# Function: usesPort
#
#       Implements EBox::FirewallObserver interface
#
sub usesPort # (protocol, port, iface)
{
    my ($self, $protocol, $port, $iface) = @_;

    ($protocol eq 'tcp') or return undef;

    ($self->isEnabled()) or return undef;

    return (($port eq 20) or ($port eq 21));
}

# Private functions

# Method: _setConf
#
#        Regenerate the configuration
#
# Overrides:
#
#       <EBox::Module::Service::_setConf>
#
sub _setConf
{
    my ($self) = @_;

    my $options = $self->model('Options');
    my $anonymous = $options->anonymous();
    my $userHomes = $options->userHomes();

    $self->writeConfFile('/etc/pam.d/vsftpd',
                         '/ftp/vsftpd.mas',
                         [ enabled => $userHomes ]);

    $self->writeConfFile('/etc/vsftpd.conf',
                         '/ftp/vsftpd.conf.mas',
                         [ anonymous => $anonymous,
                           userHomes => $userHomes ]);
}

sub _daemons
{
    return [ { 'name' => 'vsftpd' } ];
}

sub backupDomains
{
    my $name = 'ftpserver';
    my %attrs  = (
                  printableName => __('FTP server hosted files'),
                  description   => __(q{User homes and anonymous directory}),
                  order        => 300,
                 );

    return ($name, \%attrs);
}

sub ftpHome
{
    return '/srv/ftp';
}

sub backupDomainsFileSelection
{
    my ($self, %enabled) = @_;
    if ($enabled{ftpserver}) {
        my @includes = ( $self->ftpHome(), );
        my @excludes = ();
        my $options = $self->model('Options');
        if ( $options->userHomes()) {
            push @includes, '/home';
            push @excludes, '/home/samba';
        }

        my $selection = {
                          includes => \@includes,
                          excludes => \@excludes,
                          # the priority is to avoid clashes with the samba module
                          priority => 20,
                         };
        return $selection;
    }

    return {};
}

1;
