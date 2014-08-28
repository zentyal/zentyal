# Copyright (C) 2005-2007 Warp Networks S.L.
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

package EBox::MailFilter;

use base qw(
    EBox::Module::Kerberos
    EBox::VDomainModule
    EBox::Mail::FilterProvider
    EBox::FirewallObserver
    EBox::LogObserver
);

use Perl6::Junction qw(all any);

use EBox::Gettext;
use EBox::Sudo;
use EBox::Service;
use EBox::Exceptions::InvalidData;
use EBox::Exceptions::External;
use EBox::MailFilter::FirewallHelper;
use EBox::MailFilter::LogHelper;
use EBox::MailFilter::VDomainsLdap;
use EBox::MailVDomainsLdap;
use EBox::Validate;
use EBox::Config;
use EBox::Global;
use EBox::Util::Version;
use EBox::Samba::User;

use EBox::MailFilter::Amavis;
use EBox::MailFilter::SpamAssassin;

use constant SA_LEARN_SCRIPT => '/usr/share/zentyal-mailfilter/saLearn.pl';

#
# Method: _create
#
#  Constructor of the class
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'mailfilter',
                                      printableName => __('Mail Filter'),
                                      @_);
    bless($self, $class);

    $self->{smtpFilter} = new EBox::MailFilter::Amavis($self->global());
    $self->{antispam}  = new EBox::MailFilter::SpamAssassin();

    return $self;
}

# Method: actions
#
#       Override EBox::Module::Service::actions
#
sub actions
{
    return [
            {
             'action' => __('Add clamav user to amavis group'),
             'reason' => __('Clamav need access to amavis fields to properly scan mail'),
             'module' => 'mailfilter',
            },
            {
             'action' => __('Add clamav user to p3scan group'),
             'reason' => __('Clamav need access to p3scan group to properly scan in the POP Proxy'),
             'module' => 'mailfilter',
            },
            {
             'action' => __('Add spam and ham system users'),
             'reason' =>
__('This users are for the email accounts used for training the bayesian filter'),
             'module' => 'mailfilter',
            },

            {
             'action' => __('Update LDAP'),
             'reason' => __('Add amavis specific classes and fields'),
             'module' => 'mailfilter',
            },
           ]
}

# Method: usedFiles
#
#       Override EBox::Module::Service::files
#
sub usedFiles
{
    my @usedFiles;

    push (@usedFiles, @{EBox::MailFilter::Amavis::usedFiles()});
    push (@usedFiles, EBox::MailFilter::SpamAssassin::usedFiles());

    return \@usedFiles;
}

# Method: enableService
#
#       Override EBox::Module::Service::enableService
#
sub enableService
{
    my ($self, $status) = @_;
    my $mail = EBox::Global->modInstance('mail');
    if ($status) {
        if ($mail and $mail->customFilterInUse()) {
            throw EBox::Exceptions::External(
__('Mail server has a custom filter set, unset it before enabling Zentyal Mail Filter module')
                                            );
        }
    }

    if ($self->isEnabled() xor $status) {
        $mail->changed() or
            $mail->setAsChanged(1);
    }

    $self->SUPER::enableService($status);
}

sub setupLDAP
{
    # learn account feature disabled by now
    # my $users = EBox::Global->modInstance('samba');

    # my $container = EBox::Samba::User->defaultContainer();
    # my @controlUsers = (
    #     {
    #         samAccountName => 'spam',
    #         givenname => 'Spam',
    #         surname  => 'spam',
    #         parent => $container,
    #         isSystemUser => 1,
    #         isInternal => 1,
    #     },
    #     {
    #         samAccountName => 'ham',
    #         givenname => 'Ham',
    #         surname => 'ham',
    #         parent => $container,
    #         isSystemUser => 1,
    #         isInternal => 1,
    #     },
    # );

    # foreach my $user_r (@controlUsers) {
    #     my $samAcName = $user_r->{samAccountName};
    #     my $user = new EBox::Samba::User(samAccountName => $samAcName);
    #     unless ($user->exists()) {
    #         EBox::debug("Creating user '$samAcName'");
    #         EBox::Samba::User->create(%$user_r);
    #     } else {
    #         unless ($user->isSystem()) {
    #             die $user->name() . " is not a system user as it has to be";
    #         }
    #     }
    # }

    my $vdomainMailfilter = new EBox::MailFilter::VDomainsLdap;
    my $vdomainMail       = new EBox::MailVDomainsLdap;
    my @vdomains = $vdomainMail->vdomains();
    foreach my $vdomain (@vdomains) {
        $vdomainMailfilter->_addVDomain($vdomain);
    }
}

# Method: enableActions
#
#       Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;
    $self->checkUsersMode();

    # Execute enable-module script
    $self->SUPER::enableActions();
}

# Method: reprovisionLDAP
#
# Overrides:
#
#      <EBox::LdapModule::reprovisionLDAP>
sub reprovisionLDAP
{
    my ($self) = @_;

    $self->SUPER::reprovisionLDAP();

    $self->_ldapSetup();
}

# Method: smtpFilter
#
# Returns:
#   - the smtpFilter object. This a instance of EBox::MailFilter::Amavis
sub smtpFilter
{
    my ($self) = @_;
    return $self->{smtpFilter};
}

# Method: antispam
#
# Returns:
#   - the antispam object. This a instance of EBox::MailFilter::SpamAssassin
sub antispam
{
    my ($self) = @_;
    return $self->{antispam};
}

sub antispamNeeded
{
    my ($self) = @_;

    if ($self->smtpFilter()->isEnabled() and $self->smtpFilter()->antispam()) {
        return 1;
    }

    return 0;
}

#
# Method: _setConf
#
sub _setConf
{
    my ($self) = @_;
    $self->isEnabled() or
        return;

    $self->smtpFilter->writeConf();
    $self->antispam()->writeConf();

    my $vdomainsLdap =  new EBox::MailFilter::VDomainsLdap();
    $vdomainsLdap->regenConfig();
}

#
# Method: _enforceServiceState
#
sub _enforceServiceState
{
    my ($self) = @_;
    my $enabled = $self->isEnabled();

    $self->antispam()->doDaemon($enabled);
    $self->smtpFilter()->doDaemon($enabled);

    # Workaround postfix amavis issue.
    EBox::Sudo::root('service postfix restart');
}

#
# Method: isRunning
#
#  Returns if the module is running.
#
# Returns:
#
#  boolean - true if it's running, otherwise false
#
sub isRunning
{
    my ($self) = @_;

    foreach my $componentName (qw(smtpFilter antispam)) {
        my $component = $self->$componentName();
        if ($component->isRunning) {
            return 1;
        }
    }

    return 0;
}

sub _assureFilterNotInUse
{
    my ($self) = @_;

    my $mail = EBox::Global->modInstance('mail');

    $mail->service('filter') or
        return;

    my $filterInUse = $mail->externalFilter();
    if ($filterInUse eq $self->smtpFilter()->mailfilterName()) {
        throw EBox::Exceptions::External(
                                         __('Cannot proceed because the filter is in use'),
                                        );
  }

}

#
# Method: _stopService
#
#  Stop the service daemons
#
sub _stopService
{
    my ($self) = @_;

    $self->smtpFilter()->stopService();
    $self->antispam()->stopService();
}

## firewall method
sub usesPort
{
  my ($self, $protocol, $port, $iface) = @_;

  if ($self->smtpFilter()->usesPort( $protocol, $port, $iface) ) {
    return 1;
  }

  return undef;
}

sub firewallHelper
{
  my ($self) = @_;

  if (not $self->isEnabled()) {
      return undef;
  }

  my $externalMTAs = $self->smtpFilter()->allowedExternalMTAs();
  return new EBox::MailFilter::FirewallHelper(
                              smtpFilter          => $self->smtpFilter()->isEnabled(),
                              port            => $self->smtpFilter()->port,
                              fwport          => $self->smtpFilter()->fwport,
                              externalMTAs    => $externalMTAs,
                                             );
}

# Method: _ldapModImplementation
#
#        All modules using any of the functions in LdapUserBase.pm
#     should override this method to return the implementation
#  of that interface.
#
# Returns:
#
#  An object implementing EBox::LdapUserBase
sub _ldapModImplementation
{
    my ($self) = @_;
    # note that we dont really any user-related stuff but we need this to
    # use common ldap features like the method schemas()
    return new EBox::MailFilter::VDomainsLdap();
}

# Method: _vdomainModImplementation
#
#  All modules using any of the functions in LdapVDomainsBase.pm
#  should override this method to return the implementation
#  of that interface.
#
# Returns:
#
#  An object implementing EBox::LdapVDomainsBase
sub _vdomainModImplementation
{
    my ($self) = @_;
    return new EBox::MailFilter::VDomainsLdap();
}

#  Method: mailFilterName
#
#   Implements the method needed for EBox::Mail::FilterProvider
sub mailFilterName
{
    my ($self) = @_;
    return $self->smtpFilter->mailFilterName();
}

# Method: learnAccountsForDomain
#
#  Parameters:
#    vdomain
#
#  Returns :
#   list which the learn accounts for the vdomain
sub learnAccountsForDomain
{
    my ($self, $vdomain) = @_;
    my $vdomainsLdap =  new EBox::MailFilter::VDomainsLdap();
    return $vdomainsLdap->learnAccounts($vdomain);
}

#  Method: mailFilter
#
#   Reimplements the method needed for EBox::Mail::FilterProvider
sub mailFilter
{
    my ($self) = @_;
    return $self->smtpFilter()->mailFilter();
}

sub dovecotAntispamPluginConf
{
    my ($self) = @_;

    my $enabled =  $self->isEnabled();
    if ($enabled) {
        my $vdomains = $self->model('VDomainsFilter');
        if (not $vdomains->anyAllowedToLearnFromIMAPFolder()) {
            $enabled = 0;
        }
    }

    my $conf = {
                enabled => $enabled,
                mailtrain => SA_LEARN_SCRIPT,
                args       => '%u@%d',
                spamArgs  => '1',
                hamArgs   => '0',
               };

    return $conf;
}

sub mailFilterWidget
{
    my ($self,$widget) = @_;

    $self->smtpFilter()->summary($widget);
}

sub widgets
{
    my $widgets = {
        'mailfilter' => {
            'title' => __('Mail filter'),
            'widget' => \&mailFilterWidget,
            'order' => 10,
            'default' => 1
        }
    };
}

sub tableInfo
{
    my ($self) = @_;
    return [
            $self->_smtpFilterTableInfo(),
           ];
}

sub _smtpFilterTableInfo
{
    my ($self) = @_;
    my $titles = {
                  'timestamp' => __('Date'),

                  'action' => __('Action'),
                  'event' => __('Event'),

                  from_address => __('Sender address'),
                  to_address => __('Recipient address'),

                  'spam_hits' => __('Spam hits'),
    };
    my @order = qw( timestamp event action from_address to_address spam_hits );

    my $events = {
                  'BAD-HEADER' => __('Bad header found'),
                  'SPAM'      => __('Spam found'),
                  'BANNED' => __('Forbidden attached file found'),
                  'BLACKLISTED' => __('Address in blacklist found'),
                  'INFECTED'    => __('Virus found'),
                  'CLEAN'       => __('Clean message'),
                  'MTA-BLOCKED' => __('Unable to reinject in the mail server'),
    };

    return {
            'name' => __('SMTP filter'),
            'tablename' => 'mailfilter_smtp',
            'titles' => $titles,
            'order' => \@order,
            'filter' => ['action', 'from_address', 'to_address'],
            'events' => $events,
            'eventcol' => 'event',
    };
}

sub logHelper
{
    my ($self) = @_;

    return new EBox::MailFilter::LogHelper();
}

sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
                                        'name' => 'MailFilter',
                                        'icon' => 'mailfilter',
                                        'text' => $self->printableName(),
                                        'order' =>  615
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/Composite/Amavis',
                                      'text' => __('SMTP Mail Filter')
                 )
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/Composite/Antispam',
                                      'text' => __('Antispam'),
                 )
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/Composite/FileFilter',
                                      'text' => __('Files ACL')
                 )
    );

    $root->add($folder);
}

# Method: _kerberosServicePrincipals
#
#   EBox::Module::Kerberos implementation. We don't create any SPN, just
#   the service account to bind to LDAP
#
sub _kerberosServicePrincipals
{
    return undef;
}

sub _kerberosKeytab
{
    return undef;
}

1;
