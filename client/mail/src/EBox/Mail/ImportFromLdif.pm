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

package EBox::Mail::ImportFromLdif;
use base 'EBox::UsersAndGroups::ImportFromLdif::Base';
#

use strict;
use warnings;

use EBox::Global;
use EBox::MailAliasLdap;
use EBox::MailVDomainsLdap;

sub classesToProcess
{
    return [
	    { class => 'domain',           priority => 10 },
	    { class => 'vdeboxmail',       priority => 15 },
	    { class => 'posixAccount',     priority => 15 },
	    { class => 'usereboxmail',     priority => 20 },
	    { class => 'CourierMailAlias', priority => 20 },
	   ];
}


sub processPosixAccount
{
    my ($package, $entry) = @_;

    my $username = $entry->get_value('cn');

    my $email = $entry->get_value('mail');
    
    $email or return; # if email is not configured in this user we left the user
                      # alone

    my $mailMod = EBox::Global->modInstance('mail');
    my $mailUserLdap = $mailMod->_ldapModImplementation();

    my ($leftHand, $rightHand) = split '@', $email;



    $mailUserLdap->setUserAccount($username, $leftHand, $rightHand);
}

sub processUsereboxmail
{
    my ($package, $entry) = @_;

    my $username = $entry->get_value('cn');
    my $mdsize = $entry->get_value('userMaildirSize')   ;

    $mdsize or return;

    my $mailMod = EBox::Global->modInstance('mail');
    my $mailUserLdap = $mailMod->_ldapModImplementation();
    $mailUserLdap->setMDSize($mdsize);
}

sub processCourierMailAlias
{
    my ($package, $entry) = @_;

    my $alias    = $entry->get_value('mail');
    my $maildrop = $entry->get_value('maildrop');    
    my $uid       = $entry->get_value('uid');
    
    my $aliasLdap = EBox::MailAliasLdap->new();
    $aliasLdap->addAlias($alias, $maildrop, $uid);
}


sub processDomain
{
    my ($package, $entry, %options) = @_;

    my $vdomain = $entry->get_value('dc');

    my $vdomainsLdap = EBox::MailVDomainsLdap->new();

    $vdomainsLdap->addVDomain($vdomain);
}


sub startupDomain
{
    my ($package) = @_;
    # we remove all domains to avoid conflicts

    my $vdomainsLdap = EBox::MailVDomainsLdap->new();
    foreach my $vdomain ($vdomainsLdap->vdomains()) {
	$vdomainsLdap->delVDomain($vdomain);
    }
}


sub processVdeboxmail
{
    my ($package, $entry) = @_;

    my $vdomain = $entry->get_value('dc');

    my $dftmdsize = $entry->get_value('vddftMaildirSize');

    $dftmdsize or return;

    my $vdomainsLdap = EBox::MailVDomainsLdap->new();
    $vdomainsLdap->_addVDomainWiithMdQuota($vdomain, $dftmdsize);
}

1;
