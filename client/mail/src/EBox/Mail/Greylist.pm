# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::Mail::Greylist;

#

use strict;
use warnings;

use Perl6::Junction qw(any all);

use EBox::Service;
use EBox::Gettext;
use EBox::NetWrappers;
use EBox::Module::Base;
use EBox::Global;

use constant { 
    GREYLIST_SERVICE => 'ebox.postgrey',
    WHITELIST_CLIENTS_FILE => '/etc/postgrey/whitelist_clients',
};


sub new
{
  my $class = shift @_;

  my $self = {};
  bless $self, $class;

  return $self;
}

sub usedFiles
{
    my ($self) = @_;
    return [
            {
              'file' => WHITELIST_CLIENTS_FILE,
              'reason' => __('To configure whitelist for greylisting'),
              'module' => 'mail'
            },

           ];
}


# sub actions
# {
#    my ($self) = @_;
#     return [];
# }

sub daemon
{
    return {
            'name' => GREYLIST_SERVICE
    };
}

sub service
{
  my ($self) = @_;
  return $self->_confAttr('service');
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
        my $mailfilter = EBox::Global->modInstance('mail');
        $self->{configuration}     = $mailfilter->model('GreylistConfiguration');
    }

    my $row = $self->{configuration}->row();
    return $row->valueByName($attr);
}


sub writeUpstartFile
{
  my ($self) = @_;
  my $path = '/etc/event.d/ebox.postgrey';


    my $fileAttrs    = {
                        uid  => 0,
                        gid  => 0,
                        mode => '0644',
                       };

   EBox::Module::Base::writeConfFileNoCheck(
                                    $path,
                                    '/mail/ebox.postgrey.mas',
                                    [ 
                                     address  => $self->address(),
                                     port => $self->port(),

                                     delay       => $self->delay(),
                                     maxAge      => $self->maxAge(),
                                     retryWindow => $self->retryWindow(),
                                    ],

                                    $fileAttrs
                                   );
  
}


sub writeConf
{
    my ($self) = @_;


    my $network =  EBox::Global->modInstance('network');
    my @internalIf = @{ $network->InternalIfaces()  };
    my @internalNets = map {
        my $if  = $_;
        my $net =  $network->ifaceNetwork($if);

        if ($net) {
            my $mask = $network->ifaceNetmask($if);
            EBox::NetWrappers::to_network_with_mask($net, $mask);
        }
        else {
            ()
        }
        
    } @internalIf;


    

    my $fileAttrs    = {
                        uid  => 0,
                        gid  => 0,
                        mode => '0644',
                       };

   EBox::Module::Base::writeConfFileNoCheck(
                                    WHITELIST_CLIENTS_FILE,
                                    '/mail/whitelist_clients.mas',
                                    [ 
                                     whitelist => [
                                                   @internalNets,
                                                   @{ $self->_antispamWhitelist() },
                                                   ],
                                    ],

                                    $fileAttrs
                                   );   
}



sub _antispamWhitelist
{
    my ($self) = @_;
    
    # TODO: use a interface when we have more than one module with spam ACL
    my $global = EBox::Global->getInstance();

    if (not $global->modExists('mailfilter')) {
        return [];
    }

    my $mailfilter = $global->modInstance('mailfilter');
    if (not $mailfilter->isEnabled()) {
        return [];
    }


    my @wl = @{ $mailfilter->antispam()->whitelist() };
    # the format for domains is @domain_name, however postgrey uses domainname
    # format 
    @wl = map {
        $_ =~ s/^@//;
        $_
    } @wl;

    return \@wl;
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

1;
