# Copyright (C) 2008-2010 eBox Technologies S.L.
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

package EBox::MailFilter;

use strict;
use warnings;

use base (
          'EBox::Module::Service',
          'EBox::VDomainModule',
          'EBox::LdapModule',
          'EBox::Mail::FilterProvider',
          'EBox::FirewallObserver',
          'EBox::LogObserver',
          'EBox::Model::ModelProvider',
          'EBox::Model::CompositeProvider',
         );

use Perl6::Junction qw(all any);

use EBox::Gettext;
use EBox::Sudo qw( :all );
use EBox::Service;
use EBox::Exceptions::InvalidData;
use EBox::MailFilter::FirewallHelper;
use EBox::MailFilter::LogHelper;
use EBox::MailVDomainsLdap;
use EBox::Validate;
use EBox::Config;
use EBox::Global;

use EBox::MailFilter::Amavis;
use EBox::MailFilter::SpamAssassin;
use EBox::MailFilter::POPProxy;


use constant SA_LEARN_SCRIPT => '/usr/share/ebox-mailfilter/saLearn.pl';

#
# Method: _create
#
#  Constructor of the class
#
sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'mailfilter',
                                      domain => 'ebox-mailfilter',
                                      printableName => __n('Mail Filter'));
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

# Method: enableActions
#
#       Override EBox::Module::Service::enableActions
#
sub enableActions
{
    my ($self) = @_;

    $self->performLDAPActions();

    root(EBox::Config::share() . '/ebox-mailfilter/ebox-mailfilter-enable');
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


# Method: modelClasses
#
# Overrides:
#
#    <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    return [
            'EBox::MailFilter::Model::AmavisConfiguration',
            'EBox::MailFilter::Model::AmavisPolicy',
            'EBox::MailFilter::Model::ExternalMTA',
            'EBox::MailFilter::Model::ExternalDomain',
            'EBox::MailFilter::Model::VDomains',

            'EBox::MailFilter::Model::FileExtensionACL',
            'EBox::MailFilter::Model::MIMETypeACL',

            'EBox::MailFilter::Model::AntispamConfiguration',
            'EBox::MailFilter::Model::AntispamACL',
            'EBox::MailFilter::Model::AntispamTraining',

            'EBox::MailFilter::Model::AntispamVDomainACL',

            'EBox::MailFilter::Model::POPProxyConfiguration',

            'EBox::MailFilter::Model::Report::FilterDetails',
            'EBox::MailFilter::Model::Report::FilterGraph',
            'EBox::MailFilter::Model::Report::FilterReportOptions',

            'EBox::MailFilter::Model::Report::POPProxyDetails',
            'EBox::MailFilter::Model::Report::POPProxyGraph',
            'EBox::MailFilter::Model::Report::POPProxyReportOptions',
           ];
}


# Method: compositeClasses
#
# Overrides:
#
#    <EBox::Model::CompositeProvider::compositeClasses>
#
sub compositeClasses
{
    return [
            'EBox::MailFilter::Composite::Amavis',
            'EBox::MailFilter::Composite::ExternalConnections',

            'EBox::MailFilter::Composite::FileFilter',

            'EBox::MailFilter::Composite::Antispam',

            'EBox::MailFilter::Composite::Report::FilterReport',
            'EBox::MailFilter::Composite::Report::POPProxyReport',
           ];
}

#
# Method: smtpFilter
#
# Returns:
#   - the smtpFilter object. This a instance of EBox::MailFilter::Amavis
sub smtpFilter
{
    my ($self) = @_;
    return $self->{smtpFilter};
}



#
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
    $self->popProxy()->writeConf();

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
    $self->popProxy()->doDaemon($enabled);

    # Workaround postfix amavis issue.
    root("/etc/init.d/postfix restart");
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

    foreach my $componentName qw(smtpFilter  antispam popProxy) {
        my $component = $self->$componentName();
        if ( $component->isRunning) {
            return 1;
        }
    }

    if (
        (not $self->smtpFilter()->isEnabled()) and
        (not $self->popProxy()->isEnabled())
       )
        {
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
    $self->popProxy()->stopService();
}

#

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
        my $vdomains = $self->model('VDomains');
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
    $self->popProxy()->summary($widget);
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
            $self->_popProxyTableInfo(),
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
            'index' => 'mailfilter-smtpFilter',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'mailfilter_smtp',
            'filter' => ['action', 'from_address', 'to_address'],
            'events' => $events,
            'eventcol' => 'event',
            'consolidate' => $consolidate,
    };
}


sub _popProxyTableInfo
{
    my ($self) = @_;

    my $titles = {
                  'timestamp' => __('Date'),

                  'address' => __('Account'),
                  clientConn => __(q{Client's address}),
                  'event' => __('Event'),

                  mails  => __('Total messages'),
                  clean  => __('Clean messages'),
                  virus  => __('Virus messages'),
                  spam   => __('Spam messages'),
                 };

    my @order = qw( timestamp event address clientConn mails clean virus spam );

    my $events = {
                  'pop3_fetch_ok' =>
                        __('POP3 transmission complete'),
                  'pop3_fetch_failed' =>
                        __('POP3 transmission aborted'),
    };

    return {
            'name' => __('POP3 proxy'),
            'index' => 'mailfilter-popProxy',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'mailfilter_pop',
            'filter' => ['timestamp', 'address', 'clientConn'],
            'events' => $events,
            'eventcol' => 'event',
            'consolidate' => $self->_popProxyFilterConsolidationSpec(),
    };
}


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
                                        'text' => $self->printableName(),
                                        'separator' => 'UTM',
                                        'order' =>  350
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/Composite/Amavis',
                                      'text' => __('SMTP Mail Filter')
                 )
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/View/POPProxyConfiguration',
                                      'text' => __('POP Transparent Proxy')
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

# Method: consolidateReportQueries
#
#  Returns:
#
# Overrides:
#   <EBox::Module::Base::consolidateReportQueries>
sub consolidateReportQueries
{
    return [
        {
            'target_table' => 'mailfilter_smtp_report',
            'query' => {
                'select' => 'event, action, split_part(from_address, \'@\', 2) AS from_domain, split_part(to_address, \'@\', 2) AS to_domain, COUNT(*) as messages',
                'from' => 'mailfilter_smtp',
                'group' => 'event, action, from_domain, to_domain'
            }
        },
        {
            'target_table' => 'mailfilter_pop_report',
            'query' => {
                'select' => 'event, address, clientconn, SUM(clean) as clean, SUM(spam) as spam, SUM(virus) AS virus',
                'from' => 'mailfilter_pop',
                'group' => 'event, address, clientconn'
            }
        }
    ];
}

# Method: report
#
#  Returns:
#
# Overrides:
#   <EBox::Module::Base::report>
sub report
{
    my ($self, $beg, $end, $options) = @_;

    my $report;

    my $smtpRaw = $self->runMonthlyQuery($beg, $end, {
        'select' => 'lower(event) AS event, SUM(messages) AS messages',
        'from' => 'mailfilter_smtp_report',
        'group' => "event"
    }, { 'key' => 'event'});


    $report->{'smtp'} = {};
    foreach my $key (%{ $smtpRaw }) {
        my $messages = $smtpRaw->{$key}->{messages};
        defined $messages or
            next;
        $report->{'smtp'}->{$key} = $messages;
    }

    $report->{'pop'} = $self->runMonthlyQuery($beg, $end, {
        'select' => 'SUM(clean) AS clean, SUM(spam) AS spam,' .
            'SUM(virus) AS virus',
        'from' => 'mailfilter_pop_report',
        'where' => "event = 'pop3_fetch_ok'"
    });

    return $report;
}

1;
