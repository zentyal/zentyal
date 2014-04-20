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
        { value => "ndpi_ftp", printableValue => __('FTP') },
        { value => "ndpi_pop3", printableValue => __('POP3') },
        { value => "ndpi_smtp", printableValue => __('SMTP') },
        { value => "ndpi_imap", printableValue => __('IMAP') },
        { value => "ndpi_dns", printableValue => __('DNS') },
        { value => "ndpi_ipp", printableValue => __('IPP') },
        { value => "ndpi_http", printableValue => __('HTTP') },
        { value => "ndpi_mdns", printableValue => __('MDNS') },
        { value => "ndpi_ntp", printableValue => __('NTP') },
        { value => "ndpi_netbios", printableValue => __('NETBIOS') },
        { value => "ndpi_nfs", printableValue => __('NFS') },
        { value => "ndpi_ssdp", printableValue => __('SSDP') },
        { value => "ndpi_bgp", printableValue => __('BGP') },
        { value => "ndpi_snmp", printableValue => __('SNMP') },
        { value => "ndpi_xdmcp", printableValue => __('XDMCP') },
        { value => "ndpi_smb", printableValue => __('SMB') },
        { value => "ndpi_syslog", printableValue => __('Syslog') },
        { value => "ndpi_dhcp", printableValue => __('DHCP') },
        { value => "ndpi_postgresql", printableValue => __('PostgreSQL') },
        { value => "ndpi_mysql", printableValue => __('MySQL') },
        { value => "ndpi_tds", printableValue => __('TDS') },
        { value => "ndpi_directdownloadlink", printableValue => __('Direct Download Link') },
        { value => "ndpi_pops", printableValue => __('Secure POP') },
        { value => "ndpi_applejuice", printableValue => __('AppleJuice') },
        { value => "ndpi_directconnect", printableValue => __('DirectConnect') },
        { value => "ndpi_socrates", printableValue => __('Socrates') },
        { value => "ndpi_winmx", printableValue => __('WinMX') },
        { value => "ndpi_vmware", printableValue => __('VMWare') },
        { value => "ndpi_smtps", printableValue => __('SMTPS') },
        { value => "ndpi_filetopia", printableValue => __('Filetopia') },
        { value => "ndpi_imesh", printableValue => __('iMesh') },
        { value => "ndpi_kontiki", printableValue => __('Kontiki') },
        { value => "ndpi_openft", printableValue => __('OpenFT') },
        { value => "ndpi_fasttrack", printableValue => __('FastTrack') },
        { value => "ndpi_gnutella", printableValue => __('GNUTella') },
        { value => "ndpi_edonkey", printableValue => __('aMule') },
        { value => "ndpi_bittorrent", printableValue => __('BitTorrent') },
        { value => "ndpi_epp", printableValue => __('EPP') },
        { value => "ndpi_avi", printableValue => __('AVI') },
        { value => "ndpi_flash", printableValue => __('Flash') },
        { value => "ndpi_oggvorbis", printableValue => __('Oggvorbis') },
        { value => "ndpi_mpeg", printableValue => __('MPEG') },
        { value => "ndpi_quicktime", printableValue => __('QuickTime') },
        { value => "ndpi_realmedia", printableValue => __('RealMedia') },
        { value => "ndpi_windowsmedia", printableValue => __('Windows Media') },
        { value => "ndpi_mms", printableValue => __('MMS') },
        { value => "ndpi_xbox", printableValue => __('xBox') },
        { value => "ndpi_qq", printableValue => __('QQ') },
        { value => "ndpi_move", printableValue => __('MOVE') },
        { value => "ndpi_rtsp", printableValue => __('RTSP') },
        { value => "ndpi_imaps", printableValue => __('IMAPS') },
        { value => "ndpi_icecast", printableValue => __('IceCast') },
        { value => "ndpi_pplive", printableValue => __('PP Live') },
        { value => "ndpi_ppstream", printableValue => __('PP Stream') },
        { value => "ndpi_zattoo", printableValue => __('Zattoo') },
        { value => "ndpi_shoutcast", printableValue => __('Shoutcast') },
        { value => "ndpi_sopcast", printableValue => __('SopCast') },
        { value => "ndpi_tvants", printableValue => __('TvAnts') },
        { value => "ndpi_tvuplayer", printableValue => __('TvUplayer') },
        { value => "ndpi_httpapplicationveohtv", printableValue => __('HTTP Application on Veoh TV') },
        { value => "ndpi_qqlive", printableValue => __('QQ Live') },
        { value => "ndpi_thunder", printableValue => __('Thunder') },
        { value => "ndpi_soulseek", printableValue => __('Soul seek') },
        { value => "ndpi_sslnocert", printableValue => __('SSL without certificate') },
        { value => "ndpi_irc", printableValue => __('IRC') },
        { value => "ndpi_ayiya", printableValue => __('Ayiya') },
        { value => "ndpi_unencrypedjabber", printableValue => __('GTalk') },
        { value => "ndpi_msn", printableValue => __('MSN Messanger') },
        { value => "ndpi_oscar", printableValue => __('OSCAR') },
        { value => "ndpi_yahoosoftware", printableValue => __('Yahoo Software') },
        { value => "ndpi_battlefield", printableValue => __('Battlefield') },
        { value => "ndpi_quake", printableValue => __('Quake') },
        { value => "ndpi_vrrp", printableValue => __('VRRP') },
        { value => "ndpi_steam", printableValue => __('Steam') },
        { value => "ndpi_halflife2", printableValue => __('Half Life 2') },
        { value => "ndpi_worldofwarcraft", printableValue => __('World of Warcraft') },
        { value => "ndpi_telnet", printableValue => __('telnet') },
        { value => "ndpi_stun", printableValue => __('STUN') },
        { value => "ndpi_ipsec", printableValue => __('IPSEC') },
        { value => "ndpi_gre", printableValue => __('GRE') },
        { value => "ndpi_icmp", printableValue => __('ICMP') },
        { value => "ndpi_igmp", printableValue => __('IGMP') },
        { value => "ndpi_egp", printableValue => __('EGP') },
        { value => "ndpi_sctp", printableValue => __('SCTP') },
        { value => "ndpi_ospf", printableValue => __('OSPF') },
        { value => "ndpi_ipinip", printableValue => __('IP in IP') },
        { value => "ndpi_rtp", printableValue => __('RTP') },
        { value => "ndpi_rdp", printableValue => __('RDP') },
        { value => "ndpi_vnc", printableValue => __('VNC') },
        { value => "ndpi_pcanywhere", printableValue => __('PC Anywhere') },
        { value => "ndpi_ssl", printableValue => __('SSL') },
        { value => "ndpi_ssh", printableValue => __('SSH') },
        { value => "ndpi_usenet", printableValue => __('Usenet') },
        { value => "ndpi_mgcp", printableValue => __('MGCP') },
        { value => "ndpi_iax", printableValue => __('IAX') },
        { value => "ndpi_tftp", printableValue => __('TFTP') },
        { value => "ndpi_afp", printableValue => __('AFP') },
        { value => "ndpi_stealthnet", printableValue => __('Stealth Net') },
        { value => "ndpi_aimini", printableValue => __('Aimini') },
        { value => "ndpi_sip", printableValue => __('SIP') },
        { value => "ndpi_truphone", printableValue => __('Truphone') },
        { value => "ndpi_icmpv6", printableValue => __('ICMP6') },
        { value => "ndpi_dhcpv6", printableValue => __('DHCP6') },
        { value => "ndpi_armagetron", printableValue => __('Armagetron') },
        { value => "ndpi_crossfire", printableValue => __('Crossfire') },
        { value => "ndpi_dofus", printableValue => __('Dofus') },
        { value => "ndpi_fiesta", printableValue => __('Fiesta') },
        { value => "ndpi_florensia", printableValue => __('Florensia') },
        { value => "ndpi_guildwars", printableValue => __('Guild Wars') },
        { value => "ndpi_httpapplicationactivesync", printableValue => __('HTTP application Active Sync') },
        { value => "ndpi_kerberos", printableValue => __('Kerberos') },
        { value => "ndpi_ldap", printableValue => __('LDAP') },
        { value => "ndpi_maplestory", printableValue => __('Maple Story') },
        { value => "ndpi_mssql", printableValue => __('MS SQL') },
        { value => "ndpi_pptp", printableValue => __('PPTP') },
        { value => "ndpi_warcraft3", printableValue => __('World of Warcraft 3') },
        { value => "ndpi_worldofkungfu", printableValue => __('World of Kung Fu') },
        { value => "ndpi_meebo", printableValue => __('Meebo') },
        { value => "ndpi_facebook", printableValue => __('Facebook') },
        { value => "ndpi_twitter", printableValue => __('Twitter') },
        { value => "ndpi_dropbox", printableValue => __('Dropbox') },
        { value => "ndpi_gmail", printableValue => __('GMail') },
        { value => "ndpi_googlemaps", printableValue => __('Google Maps') },
        { value => "ndpi_youtube", printableValue => __('Youtube') },
        { value => "ndpi_google", printableValue => __('Google') },
        { value => "ndpi_dcerpc", printableValue => __('DCE/RPC') },
        { value => "ndpi_netflow", printableValue => __('Netflow') },
        { value => "ndpi_sflow", printableValue => __('sFlow') },
        { value => "ndpi_httpconnect", printableValue => __('HTTP connect') },
        { value => "ndpi_httpproxy", printableValue => __('HTTP proxy') },
        { value => "ndpi_citrix", printableValue => __('Citrix') },
        { value => "ndpi_netflix", printableValue => __('Netflix') },
        { value => "ndpi_lastfm", printableValue => __('LastFM') },
        { value => "ndpi_grooveshark", printableValue => __('Grooveshark') },
        { value => "ndpi_skyfileprepaid", printableValue => __('SkyFile Pre-paid') },
        { value => "ndpi_skyfilerudics", printableValue => __('SkyFile on RUDICS platforms') },
        { value => "ndpi_skyfilepostpaid", printableValue => __('SkyFile Post-paid') },
        { value => "ndpi_citrixonline", printableValue => __('Citric Online') },
        { value => "ndpi_apple", printableValue => __('Apple') },
        { value => "ndpi_webex", printableValue => __('Webex') },
        { value => "ndpi_whatsapp", printableValue => __('WhatsApp') },
        { value => "ndpi_appleicloud", printableValue => __('Apple iCloud') },
        { value => "ndpi_appleitunes", printableValue => __('Apple iTunes') },
        { value => "ndpi_radius", printableValue => __('RADIUS') },
        { value => "ndpi_windowsupdate", printableValue => __('Windows Update') },
        { value => "ndpi_teamviewer", printableValue => __('Team Viewer') },
        { value => "ndpi_tuenti", printableValue => __('Tuenti') },
        { value => "ndpi_lotusnotes", printableValue => __('Lotus Notes') },
        { value => "ndpi_sap", printableValue => __('SAP') },
        { value => "ndpi_gtp", printableValue => __('GTP') },
        { value => "ndpi_upnp", printableValue => __('UPNP') },
        { value => "ndpi_llmnr", printableValue => __('LLMNR') },
        { value => "ndpi_remotescan", printableValue => __('remote scan') },
        { value => "ndpi_spotify", printableValue => __('Spotify') },
        { value => "ndpi_webm", printableValue => __('WebM') },
        { value => "ndpi_h323", printableValue => __('H.323') },
        { value => "ndpi_openvpn", printableValue => __('OpenVPN') },
        { value => "ndpi_noe", printableValue => __('NOE') },
        { value => "ndpi_ciscovpn", printableValue => __('Cisco VPN') },
        { value => "ndpi_teamspeak", printableValue => __('TeamSpeak') },
        { value => "ndpi_tor", printableValue => __('TOR') },
        { value => "ndpi_ciscoskinny", printableValue => __('SCCP') },
        { value => "ndpi_rtcp", printableValue => __('RTCP') },
        { value => "ndpi_rsync", printableValue => __('RSYNC') },
        { value => "ndpi_oracle", printableValue => __('Oracle') },
        { value => "ndpi_corba", printableValue => __('CORBA') },
        { value => "ndpi_ubuntuone", printableValue => __('UbuntuONE') },
        { value => "ndpi_whoisdas", printableValue => __('WHOIS, DAS') },
        { value => "ndpi_collectd", printableValue => __('Collectd') },
        { value => "ndpi_socks5", printableValue => __('SOCKETS5') },
        { value => "ndpi_socks4", printableValue => __('SOCKETS4') },
        { value => "ndpi_rtmp", printableValue => __('RTMP') },
        { value => "ndpi_ftpdata", printableValue => __('FTP Data') },
        { value => "ndpi_wikipedia", printableValue => __('Wikipedia') },
        { value => "ndpi_msn", printableValue => __('MSN') },
        { value => "ndpi_amazon", printableValue => __('Amazon') },
        { value => "ndpi_ebay", printableValue => __('eBay') },
        { value => "ndpi_cnn", printableValue => __('CNN website') },
        { value => "ndpi_skype", printableValue => __('Skype') },
        { value => "ndpi_viber", printableValue => __('Viber') },
        { value => "ndpi_yahoo", printableValue => __('Yahoo') },
        { value => "ndpi_pandomediabooster", printableValue => __('Pando Media Booster') },
        { value => "ndpi_unsupported", printableValue => __('LogMeIn') },
    );

    @services = sort {
        (lc $a->{printableValue}) cmp (lc $b->{printableValue})
    } @services;

    unshift @services, { value => 'ndpi_none', printableValue => __('None')};

    return \@services;
}

1;
