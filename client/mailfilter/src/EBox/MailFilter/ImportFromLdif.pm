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

package EBox::MailFilter::ImportFromLdif;
use base 'EBox::UsersAndGroups::ImportFromLdif::Base';
#

use strict;
use warnings;

use EBox::Global;
use EBox::MailFilter::VDomainsLdap;


sub classesToProcess
{
    return [
	    { class => 'amavisAccount',    priority => 25 },
	    { class => 'vdmailfilter',     priority => 30 },
	   ];
}



sub processVdmailfilter
{
    my ($package, $entry) = @_;

    $package->processParents($entry, parents => ['amavisAccount']);
}


sub processAmavisAccount
{
    my ($package, $entry) = @_;

    my $vdomain = $entry->get_value('dc');

    my $vdomainsLdap =  EBox::MailFilter::VDomainsLdap->new();

    my $amavisBypassSpamChecks = $entry->get_value('amavisBypassSpamChecks');
    if (defined $amavisBypassSpamChecks) {
	my $active = $amavisBypassSpamChecks ? 0 : 1;
	$vdomainsLdap->setAntispam($vdomain, $active);
    }

    my $amavisBypassVirusChecks = $entry->get_value('amavisBypassVirusChecks');
    if (defined $amavisBypassVirusChecks) {
	my $active = $amavisBypassVirusChecks ? 0 : 1;
	$vdomainsLdap->setAntivirus($vdomain, $active);
    }



    my $amavisSpamTag2Level = $entry->get_value('amavisSpamTag2Level');
    if (defined $amavisSpamTag2Level) {
	$vdomainsLdap->setSpamThreshold($vdomain, $amavisSpamTag2Level);
    }

    my @whiteList = $entry->get_value( 'amavisWhitelistSender');
    if (@whiteList) {
	$vdomainsLdap->setWhitelist($vdomain, \@whiteList);
    }
 
    my @blackList = $entry->get_value( 'amavisBlacklistSender');
    if (@blackList) {
	$vdomainsLdap->setBlacklist($vdomain, \@blackList);
    }



}


1;
