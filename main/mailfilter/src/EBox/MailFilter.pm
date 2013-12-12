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

use base (
          'EBox::Module::Service',
          'EBox::VDomainModule',
          'EBox::LdapModule',
          'EBox::Mail::FilterProvider',
          'EBox::FirewallObserver',
          'EBox::LogObserver',
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
use EBox::Users::User;

use EBox::MailFilter::Amavis;
use EBox::MailFilter::SpamAssassin;
use EBox::MailFilter::POPProxy;

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

    $self->{smtpFilter} = new EBox::MailFilter::Amavis();
    $self->{antispam}  = new EBox::MailFilter::SpamAssassin();
    $self->{popProxy}  = new EBox::MailFilter::POPProxy();

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
    push (@usedFiles, EBox::MailFilter::POPProxy::usedFiles());

    return \@usedFiles;
}

# Method: initialSetup
#
# Overrides:
#   EBox::Module::Base::initialSetup
#
sub initialSetup
{
    my ($self, $version) = @_;

    unless ($version) {
        # Create default rules and services
        # only if installing the first time
        my $firewall = EBox::Global->modInstance('firewall');
        $firewall->addServiceRules($self->_serviceRules());
        $firewall->saveConfigRecursive();
    }
}

#  mailfilter can be used without mail so this methods reflects that
sub depends
{
    my ($self) = @_;
    my @depends = ('firewall');
    my $mail = $self->global()->modInstance('mail');
    if ($mail and $mail->isEnabled()) {
        push @depends, 'mail';
    }

    return \@depends;
}

sub _serviceRules
{
    my ($self) = @_;

    my $popProxyPort = $self->popProxy()->port();

    return [
             {
              'name' => 'POP Transparent proxy',
              'printableName' => __('POP Transparent proxy'),
              'description' => __('POP Transparent proxy'),
              'internal' => 1,
              'protocol' => 'tcp',
              'sourcePort' => 'any',
              'destinationPorts' => [ $popProxyPort ],
              'rules' => { 'external' => 'deny', 'internal' => 'accept' },
             },
             {
              'name' => 'POP3',
              'description' => __('POP3 protocol'),
              'internal' => 1,
              'protocol'   => 'tcp',
              'sourcePort' => 'any',
              'destinationPorts' => [ 110 ],
              'rules' => { 'internet' => 'accept', 'output' => 'accept' },
             },
    ];
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

sub _ldapSetup
{
    my $users = EBox::Global->modInstance('users');

    my $container = EBox::Users::User->defaultContainer();
    my @controlUsers = (
        {
            uid => 'spam',
            givenname => 'Spam',
            surname  => 'spam',
            parent => $container,
            isSystemUser => 1,
            isInternal => 1,
        },
        {
            uid => 'ham',
            givenname => 'Ham',
            surname => 'ham',
            parent => $container,
            isSystemUser => 1,
            isInternal => 1,
        },
    );

    foreach my $user_r (@controlUsers) {
        my $username = $user_r->{uid};
        my $user = new EBox::Users::User(uid => $username);
        unless ($user->exists()) {
            EBox::debug("Creating user '$username'");
            EBox::Users::User->create(%$user_r);
        } else {
            unless ($user->isSystem()) {
                die $user->name() . " is not a system user as it has to be";
            }
        }
    }

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

    $self->performLDAPActions();

    $self->_ldapSetup();

    # Execute enable-module script
    $self->SUPER::enableActions();
}

#  Method: enableModDepends
#
#   Override EBox::Module::Service::enableModDepends
#
#  The mail dependency only exists bz we need the ldap mail data or we will run
#  in error when seting mail domains options
sub enableModDepends
{
    my ($self) = @_;
    my @depends = qw(network antivirus);

    my $mail = EBox::Global->modInstance('mail');
    if ($mail) {
        if (not $mail->configured()) {
            push @depends, 'mail';
        }
    }

    if ($self->popProxy->isEnabled()) {
        # requires firewall to do the port redirection
        push @depends, 'firewall';
    }

    return \@depends;;
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

#
# Method: popProxy
#
# Returns:
#   - the popProxy object. This a instance of EBox::MailFilter::POPProxy
sub popProxy
{
    my ($self) = @_;
    return $self->{popProxy};
}

sub antispamNeeded
{
    my ($self) = @_;

    if ($self->smtpFilter()->isEnabled() and $self->smtpFilter()->antispam()) {
        return 1;
    }

    if ($self->popProxy()->isEnabled() and $self->popProxy()->antispam()) {
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
#FIXME    $self->popProxy()->writeConf();

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
#FIXME    $self->popProxy()->doDaemon($enabled);

    # Workaround postfix amavis issue.
    EBox::Sudo::root('/etc/init.d/postfix restart');
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

    foreach my $componentName (qw(smtpFilter antispam popProxy)) {
        my $component = $self->$componentName();
        if ($component->isRunning) {
            return 1;
        }
    }

    if ((not $self->smtpFilter()->isEnabled()) and
        (not $self->popProxy()->isEnabled())) {
        # none service is enabled but module is -> running = 1
        if ($self->isEnabled()) {
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
#    $self->popProxy()->stopService();
}

## firewall method
sub usesPort
{
  my ($self, $protocol, $port, $iface) = @_;

  if ($self->smtpFilter()->usesPort( $protocol, $port, $iface) ) {
    return 1;
  }
  elsif ($self->popProxy()->usesPort( $protocol, $port, $iface) ) {
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
                              POPProxy        => $self->popProxy->isEnabled(),
                              POPProxyPort    => $self->popProxy->port,
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
# FIXME
#    $self->popProxy()->summary($widget);
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

    my $consolidate = {
                       mailfilter_smtp_traffic => _filterTrafficConsolidationSpec(),
                      };

    return {
            'name' => __('SMTP filter'),
            'tablename' => 'mailfilter_smtp',
            'titles' => $titles,
            'order' => \@order,
            'filter' => ['action', 'from_address', 'to_address'],
            'events' => $events,
            'eventcol' => 'event',
            'consolidate' => $consolidate,
    };
}

# sub _popProxyTableInfo
# {
#     my ($self) = @_;

#     my $titles = {
#                   'timestamp' => __('Date'),

#                   'address' => __('Account'),
#                   clientConn => __(q{Client's address}),
#                   'event' => __('Event'),

#                   mails  => __('Total messages'),
#                   clean  => __('Clean messages'),
#                   virus  => __('Virus messages'),
#                   spam   => __('Spam messages'),
#                  };

#     my @order = qw( timestamp event address clientConn mails clean virus spam );

#     my $events = {
#                   'pop3_fetch_ok' =>
#                         __('POP3 transmission complete'),
#                   'pop3_fetch_failed' =>
#                         __('POP3 transmission aborted'),
#     };

#     return {
#             'name' => __('POP3 proxy'),
#             'tablename' => 'mailfilter_pop',
#             'titles' => $titles,
#             'order' => \@order,
#             'filter' => ['timestamp', 'address', 'clientConn'],
#             'events' => $events,
#             'eventcol' => 'event',
#             'consolidate' => $self->_popProxyFilterConsolidationSpec(),
#     };
# }

sub logHelper
{
    my ($self) = @_;

    return new EBox::MailFilter::LogHelper();
}

sub _filterTrafficConsolidationSpec
{
    my $spec = {
        accummulateColumns => {
            clean => 0,
            spam => 0,
            banned => 0,
            blacklisted => 0,
            clean  => 0,
            infected => 0,
            bad_header => 0,
        },
        filter => sub {
            my ($row) = @_;
            if ($row->{event} eq 'MTA-BLOCKED') {
                return 0;
            }
            return 1;
        },
        consolidateColumns => {
            event => {
                conversor => sub { return 1  },
                accummulate => sub {
                    my ($v) = @_;
                    if ($v eq 'BAD-HEADER') {
                        return 'bad_header';
                    }

                    return lc $v;
                },
            },
        },
    };

    return $spec;
}

sub _popProxyFilterConsolidationSpec
{
    my $spec = {
        filter             => sub {
            my ( $row) = @_;
            return $row->{event} eq 'pop3_fetch_ok'
        },
        accummulateColumns => {
            mails  => 0,
            clean  => 0,
            virus  => 0,
            spam   => 0,
        },
        consolidateColumns => {
            mails => {
                accummulate => 'mails',
            },
            clean => {
                accummulate => 'clean',
            },
            virus => {
                accummulate => 'virus',
            },
            spam => {
                accummulate => 'spam',
            },

        },
    };

    return { mailfilter_pop_traffic => $spec };
}

sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
                                        'name' => 'MailFilter',
                                        'icon' => 'mailfilter',
                                        'text' => $self->printableName(),
                                        'separator' => 'Communications',
                                        'order' =>  615
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/Composite/Amavis',
                                      'text' => __('SMTP Mail Filter')
                 )
    );

# FIXME: p3scan is disabled, it crashes installation
#    $folder->add(
#                 new EBox::Menu::Item(
#                                      'url' => 'MailFilter/View/POPProxyConfiguration',
#                                      'text' => __('POP Transparent Proxy')
#                 )
#    );

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

1;
