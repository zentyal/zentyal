# Copyright (C) 2014 Zentyal S.L.
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

package EBox::Firewall::Types::NDPIApplication;
use base 'EBox::Types::Select';

use EBox::Gettext;

sub new
{
    my ($class, %params)  = @_;
    $params{populate} = \&_ndpiServices;

    my $self = $class->SUPER::new(%params);
    bless($self, $class);

    return $self;
}

sub _ndpiServices
{
    my @services = (
        { 'value' => 'ndpi_facebook',
          'printableValue' => __('Facebook') },
        { 'value' => 'ndpi_twitter',
          'printableValue' => __('Twitter') },
        { 'value' => 'ndpi_bittorrent',
          'printableValue' => __('Bittorrent') },
        { 'value' => 'ndpi_edonkey',
          'printableValue' => __('Amule') },
        { 'value' => 'ndpi_dropbox',
          'printableValue' => __('Dropbox') },
        { 'value' => 'ndpi_msn',
          'printableValue' => __('MSN Messanger') },
        { 'value' => 'ndpi_unencrypedjabber',
          'printableValue' => __('GTalk') },
        { 'value' => 'ndpi_whatsapp',
          'printableValue' => __('Whatsapp') },
        { 'value' => 'ndpi_tor',
          'printableValue' => __('TOR') },
        { 'value' => 'ndpi_teamviewer',
          'printableValue' => __('TeamViewer') },
        { 'value' => 'ndpi_rdp',
          'printableValue' => __('RDP') },
        { 'value' => 'ndpi_vmware',
          'printableValue' => __('LogMeIn') },
        { 'value' => 'ndpi_vnc',
          'printableValue' => __('VNC') },
    );

    return \@services;
}

1;
