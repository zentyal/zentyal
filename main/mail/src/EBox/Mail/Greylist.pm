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

package EBox::Mail::Greylist;

use Perl6::Junction qw(any all);

use EBox::Service;
use EBox::Gettext;
use EBox::NetWrappers;
use EBox::Module::Base;
use EBox::Global;
use EBox::Dashboard::ModuleStatus;

use constant GREYLIST_SERVICE => 'postgrey';

sub new
{
  my $class = shift @_;

  my $self = {};
  bless $self, $class;

  return $self;
}

sub daemon
{
    return {
            'name' => GREYLIST_SERVICE,
            'precondition' => \&EBox::Mail::isGreylistEnabled #  awkward but
                   # precondition  method must reside in the main package
           };
}

sub isEnabled
{
    my ($self) = @_;
    return $self->_confAttr('service');
}

sub isRunning
{
    my ($self) = @_;

    unless (EBox::Global->modInstance('mail')->configured()) {
        return undef;
    }

    return EBox::Service::running(GREYLIST_SERVICE);
}

sub delay
{
  my ($self) = @_;
  return $self->_confAttr('delay');
}

sub retryWindow
{
  my ($self) = @_;
  return $self->_confAttr('retryWindow');
}

sub maxAge
{
  my ($self) = @_;
  return $self->_confAttr('maxAge');
}

sub _confAttr
{
    my ($self, $attr) = @_;

    if (not $self->{configuration}) {
        my $mail = EBox::Global->modInstance('mail');
        $self->{configuration} = $mail->model('GreylistConfiguration');
    }

    my $row = $self->{configuration}->row();
    return $row->valueByName($attr);
}

sub writeConf
{
    my ($self) = @_;

    EBox::Module::Base::writeConfFileNoCheck(
        '/etc/default/postgrey',
        '/mail/postgrey.mas',
        [
         address  => $self->address(),
         port => $self->port(),

         delay       => $self->delay(),
         maxAge      => $self->maxAge(),
         retryWindow => $self->retryWindow(),
        ],
        { uid  => 0, gid  => 0, mode => '0644' }
    );
}

sub port
{
    my ($self) = @_;
    return 60000;
}

sub address
{
    my ($self) = @_;
    return '127.0.0.1';
}

sub usesPort
{
    my ($self, $protocol, $port, $iface) = @_;

    if ($protocol ne 'tcp')  {
        return undef;
    }

    if ($port != $self->port()) {
        return undef;
    }

    my $allIfaceAddr = all (EBox::NetWrappers::iface_addresses($iface));
    if ($self->address ne $allIfaceAddr) {
        return undef;
    }

    return 1;
}

sub serviceWidget
{
    my ($self) = @_;

    my $widget = new EBox::Dashboard::ModuleStatus(
                                                module => 'mail',
                                                printableName => __('Greylist service'),
                                                running => $self->isRunning() ? 1 : 0,
                                                enabled => $self->isEnabled() ? 1 : 0,
                                               );

    return $widget;
}

1;
