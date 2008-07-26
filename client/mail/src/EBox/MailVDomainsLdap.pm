# Copyright (C) 2005 Warp Networks S.L., DBS Servicios Informaticos S.L.
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

package EBox::MailVDomainsLdap;

use strict;
use warnings;

use EBox::Sudo qw( :all );
use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Ldap;
use EBox::Validate qw( :all );
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::Internal;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Gettext;

use constant VDOMAINDN     => 'ou=vdomains, ou=postfix';
use constant BYTES                              => '1048576';
use constant MAXMGSIZE                          => '104857600';

sub new 
{
    my $class = shift;
    my $self  = {};
    $self->{ldap} = EBox::Ldap->instance();
    bless($self, $class);
    return $self;
}

# Method: addVDomain
#
#  Creates a new virtual domain
#
# Parameters:
#
#     vdomain - The virtual domain name
#               dftmdsize - Default maildir size for the vdomain
sub addVDomain { #vdomain
    my ($self, $vdomain, $dftmdsize) = @_;
        

    my $ldap = $self->{ldap};
    
    checkDomainName($vdomain, 'Virtual domain name');
        
    # Verify vdomain exists
    if ($self->vdomainExists($vdomain)) {
        throw EBox::Exceptions::DataExists('data' => __('virtual domain'),
                                           'value' => $vdomain);
    }
    
    
        
    my $dn = "domainComponent=$vdomain, " . $self->vdomainDn;
    my %attrs = ( 
                 attr => [
                          'domainComponent' => $vdomain,
                          'objectclass'    => 'domain',
                          'objectclass'     => 'vdeboxmail'
                         ]
                );
    
    my $r = $self->{'ldap'}->add($dn, \%attrs);
    
    my $mail = EBox::Global->modInstance('mail');
    if ($mail->mdQuotaAvailable) {
        $self->_addVDomainWiithMdQuota($dn, $dftmdsize);
    }
    
    
    $self->_initVDomain($vdomain);
}

# Method: _initVDomain
#
#  This method tell all modules that a new virtual domain was added.
#
# Parameters:
#
#     vdomain - The virtual domain name
sub _initVDomain 
{
    my ($self, $vdomain) = @_;
    
    my @mods = @{$self->_modsVDomainModule()};
    
    foreach my $mod (@mods){
        $mod->_addVDomain($vdomain);
    }
}

# Method: delVDomain
#
#  Removes a virtual domain
#
# Parameters:
#
#     vdomain - The virtual domain name
sub delVDomain 
{ 
    my ($self, $vdomain) = @_;

    my $mail = EBox::Global->modInstance('mail');
    
    # Verify vdomain exists
    unless ($self->vdomainExists($vdomain)) {
        throw EBox::Exceptions::DataNotFound('data' => __('virtual domain'),
                                             'value' => $vdomain);
    }
    
    # We Should warn about users whose mail account belong to this vdomain.
    $mail->{malias}->delAliasesFromVDomain($vdomain);
    $mail->{musers}->delAccountsFromVDomain($vdomain);
    
    $self->_cleanVDomain($vdomain);
    
    my $r = $self->{'ldap'}->delete("domainComponent=$vdomain, " .
                                    $self->vdomainDn);
}

# Method: _cleanVDomain
#
#  This method noitifies that the virtual domain its going to be deleted.
#
# Parameters:
#
#     vdomain - The virtual domain name
sub _cleanVDomain
 {
     my ($self, $vdomain) = @_;

     my @mods = @{$self->_modsVDomainModule()};
     
     foreach my $mod (@mods){
         $mod->_delVDomain($vdomain);
     }
 }

# Method: vdomains
#
#  This method returns all defined virtual domains
#
# Returns:
#
#     array - with all virtual domain names
sub vdomains
{
    my ($self) = @_;

    my %args = (
                base => $self->vdomainDn,
                filter => 'objectclass=*',
                scope => 'one',
                attrs => ['domainComponent']
               );
    
    my $result = $self->{ldap}->search(\%args);

    my @vdomains = map { $_->get_value('dc')} $result->sorted('domainComponent');
    
    return @vdomains;
}


# Method: _updateVDomain
#
#  This method notifies that the virtual domain was changed
#
# Parameters:
#
#     vdomain - The virtual domain name
sub _updateVDomain
 {
     my ($self, $vdomain) = @_;
     
        my @mods = @{$self->_modsVDomainModule()};
     
     foreach my $mod (@mods){
         $mod->_modifyVDomain($vdomain);
     }
}

# Method: vdomainDn
#
#  This method returns the base Dn od virtual domains ldap leaf
#
# Returns:
#
#               string - base dn
sub vdomainDn
{
    my ($self) = @_;
    return VDOMAINDN . ", " . $self->{ldap}->dn;
}

# Method: vdomainExists
#
#  This method returns if the virtual domain exists in ldap leaf
#
# Parameters:
#
#     vdomain - The virtual domain name
#
# Returns:
#
#               boolean - true if the virtual domain exists, false otherwise
sub vdomainExists
{ 
    my ($self, $vdomain) = @_;

    my %attrs = (
                 base => $self->vdomainDn,
                 filter => "&(objectclass=*)(dc=$vdomain)",
                 scope => 'one'
        );
    
    my $result = $self->{'ldap'}->search(\%attrs);
    
    return ($result->count > 0);
}

# Method: _modsVDomainModule
#
#  FIXME
#
# Returns:
#
#  
sub _modsVDomainModule 
{
    my ($self) = @_;

    my $global = EBox::Global->modInstance('global');
    my @names = @{$global->modNames};
    
    my @modules;
    foreach my $name (@names) {
        my $mod = EBox::Global->modInstance($name);
                if ($mod->isa('EBox::VDomainModule')) {
                    push (@modules, $mod->_vdomainModImplementation);
                }
    }
    
    return \@modules;
}

# Method: allWarning
#
#  Returns all the the warnings provided by the modules when a certain
#  virtual domain is going to be deleted. Function _delVDomainWarning 
#  is called in all module implementing them.
#
# Parameters:
#
#  name - name of the virtual domain
#
# Returns:
#
#       array ref - holding all the warnings
#
sub allWarnings
{
    my ($self, $name) = @_;
    
    my @modsFunc = @{$self->_modsVDomainModule()};
    my @allWarns;
    
        foreach my $mod (@modsFunc) {
            my $warn = undef;
            $warn = $mod->_delVDomainWarning($name);
            push (@allWarns, $warn) if ($warn);
        }
    
    return \@allWarns;
}



sub regenConfig
{
    my ($self) = @_;

    my %vdomainsToDelete = map {  $_ => 1 } $self->vdomains();

    my $mf =  EBox::Global->modInstance('mail');
    my $vdomainsTable = $mf->model('VDomains');

    foreach my $vdRow (@{ $vdomainsTable->rows() }) {
        my $vdomain     = $vdRow->elementByName('vdomain')->value();

        if (not $self->vdomainExists($vdomain)) {
            $self->addVDomain($vdomain);
        }

        delete $vdomainsToDelete{$vdomain};
    }

        # vdomains no present in the table must be deleted
    foreach my $vdomain (keys %vdomainsToDelete) {
        $self->delVDomain($vdomain);
    }
}

# Mail dir quota methods...

sub _mdQuotaAddOn
{
    my ($self, $vdomain) = @_;
    
    my $mail =  EBox::Global->modInstance('mail');
    
    my @params;
    push @params, ('vdomain' => $vdomain);
    push @params, ('mdsize' => $mail->{vdomains}->getMDSize($vdomain));
    
    my $addon = {
                 name => __('Size quota'),
                 path => '/mail/editVDomainSizeQuota.mas',
                 params => \@params,
                 
                };
    
    
    return $addon;
}



# Method: vdandmaxsizes
#
#  This method returns all defined virtual domain with their maximal maildir
#  sizes.
#
# Returns:
#
#     hash - with (vdomain name, dflt mfsize) pairs
sub vdandmaxsizes()
{
    my ($self) = @_;

    my $mail = EBox::Global->modInstance('mail');
    $mail->assureMdQuotaIsAvailable();
    
    my %args = (
                base => $self->vdomainDn,
                filter => 'objectclass=*',
                scope => 'one',
                attrs => ['domainComponent', 'vddftMaildirSize']
               );
    
    my $result = $self->{ldap}->search(\%args);
    
    my %vdomains = map { $_->get_value('dc'), ($_->get_value('vddftMaildirSize') / $self->BYTES)}
        $result->sorted('domainComponent');
    
    return %vdomains;
}

# Method: getMDSize
#
#  This method returns the maildir size of a virtual domain.
#
# Parameters:
#
#     vdomain - The virtual domain name
#
# Returns:
# 
#               dftmdsize - Default maildir size for the vdomain
sub getMDSize
 {
     my ($self, $vdomain) = @_;
     
     my $mail = EBox::Global->modInstance('mail');
     $mail->assureMdQuotaIsAvailable();
     
     my %args = (
                 base => $self->vdomainDn,
                 filter => 'domainComponent='.$vdomain,
                 scope => 'one',
                 attrs => ['vddftMaildirSize']
                );
        
     my $result = $self->{ldap}->search(\%args);
     my $entry = $result->entry(0);
     
     my $mdsize = $entry->get_value('vddftMaildirSize');
     
     return ($mdsize / $self->BYTES);
}

# Method: setMDSize
#
#  This method changes the default maildir size of a virtual domain
#
# Parameters:
#
#     vdomain - The virtual domain name
#               mdsize - Desired maildir size for the vdomain
sub setMDSize
 {
     my ($self, $vdomain, $mdsize) = @_;
     
     my $mail = EBox::Global->modInstance('mail');
     $mail->assureMdQuotaIsAvailable();
     
     unless (isAPositiveNumber($mdsize)) {
         throw EBox::Exceptions::InvalidData(
                                             'data'  => __('maildir size'),
                                             'value' => $mdsize);
     }
     
     if($mdsize > MAXMGSIZE) {
         throw EBox::Exceptions::InvalidData(
                                             'data'  => __('maildir size'),
                                             'value' => $mdsize);
     }
     
     my $dn = "domainComponent=$vdomain," .  $self->vdomainDn;
     
     $self->_updateVDomain($vdomain);
     
     my $r = $self->{'ldap'}->modify($dn, {
                                           replace => { 'vddftMaildirSize' => $mdsize * $self->BYTES }});
 }

# Method: updateMDSizes
#
#  This method updates all maildir sizes of users accounts that belongs to the
#  virtual domain.
#
# Parameters:
#
#     vdomain - The virtual domain name
#               mdsize - Default maildir size for the vdomain
sub updateMDSizes
 {
     my ($self, $vdomain, $mdsize) = @_;
     
     my $mail = EBox::Global->modInstance('mail');
     $mail->assureMdQuotaIsAvailable();
     
     my %accounts = %{$mail->{musers}->allAccountsFromVDomain($vdomain)};
     
     foreach my $uids (keys %accounts) {
         $mail->{musers}->setMDSize($uids, $mdsize);
     }
 }



sub _addVDomainWiithMdQuota
{
    my ($self, $dn, $dftmdsize) = @_;
    defined $dftmdsize or $dftmdsize = 0;

    unless (isAPositiveNumber($dftmdsize)) {
        throw EBox::Exceptions::InvalidData(
                                            'data'  => __('maildir size'),
                                            'value' => $dftmdsize);
    }
    
    if($dftmdsize > MAXMGSIZE) {
        throw EBox::Exceptions::InvalidData(
                                            'data'  => __('maildir size'),
                                            'value' => $dftmdsize);
    }
    
    
    my $ldap = $self->{ldap};
    
    my %modificationParams = ( 
                              changes => [
                                        add => [
                                                'vddftMaildirSize'=> ($dftmdsize * $self->BYTES),
                                                
                                               ]
                                         ],
                             );
    
    $ldap->modify($dn, \%modificationParams);
    
}


1;
