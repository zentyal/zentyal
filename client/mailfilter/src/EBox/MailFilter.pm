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
use EBox::MailFilter::ClamAV;
use EBox::MailFilter::SpamAssassin;
use EBox::MailFilter::POPProxy;



#
# Method: _create
#
#  Constructor of the class
#
sub _create 
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'mailfilter');
    bless($self, $class);
    
    $self->{smtpFilter} = new EBox::MailFilter::Amavis();
    $self->{antivirus} = new EBox::MailFilter::ClamAV();
    $self->{antispam}  = new EBox::MailFilter::SpamAssassin();
    $self->{popProxy}  = new EBox::MailFilter::POPProxy();
    
    return $self;
}


sub domain
{
    return 'ebox-mailfilter';
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
    push (@usedFiles, EBox::MailFilter::ClamAV::usedFiles());
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

    root(EBox::Config::share() . '/ebox-mailfilter/ebox-mailfilter-enable');
}

#  Method: enableModDepends
#
#   Override EBox::Module::Service::enableModDepends
#
#  The mail dependency only exists bz we need the ldap mail data or we wil lrun
#  in error when seting mail domains options
sub enableModDepends 
{
    my ($self) = @_;
    my @depends = qw(network);

    my $mail = EBox::Global->modInstance('mail');
    if ($mail) {
        if (not $mail->configured()) {
            push @depends, 'mail';
        }
    }

    
    if ($self->popProxy->service()) {
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

            
            'EBox::MailFilter::Model::FreshclamStatus',       
     
            'EBox::MailFilter::Model::AntispamConfiguration',
            'EBox::MailFilter::Model::AntispamACL',
            'EBox::MailFilter::Model::AntispamTraining',

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
# Method: antivirus
#
# Returns:
#   - the antivirus object. This a instance of EBox::MailFilter::ClamAV
sub antivirus
{
    my ($self) = @_;
    return $self->{antivirus};
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


sub antivirusNeeded
{
    my ($self) = @_;

    if ($self->smtpFilter()->service() and  $self->smtpFilter()->antivirus()) {
        return 1;
    }


    if ($self->popProxy()->service() and $self->popProxy()->antivirus()) {
        return 1;
    }


    return 0;
}

sub antispamNeeded
{
    my ($self) = @_;

    if ($self->smtpFilter()->service() and $self->smtpFilter()->antispam()) {
        return 1;
    }

    if ($self->popProxy()->service() and $self->popProxy()->antispam()) {
        return 1;
    }



    return 0;
}



#
# Method: _regenConfig
#
sub _regenConfig
{
    my ($self) = @_;
    my $service = $self->service();

    if ($service) {
        $self->smtpFilter->writeConf();
        $self->antivirus()->writeConf($service);
        $self->antispam()->writeConf();
        $self->popProxy()->writeConf();

  
        my $vdomainsLdap =  new EBox::MailFilter::VDomainsLdap();
        $vdomainsLdap->regenConfig();
    }
    

    $self->antivirus()->doDaemon($service);
    $self->antispam()->doDaemon($service);
    $self->smtpFilter()->doDaemon($service);
    $self->popProxy()->doDaemon($service);

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
    
    foreach my $componentName qw(smtpFilter antivirus antispam popProxy) {
        my $component = $self->$componentName();
        if ( $component->isRunning) {
            return 1;
        }
    }

    if (
        (not $self->smtpFilter()->service) and
        (not $self->popProxy()->service)
       ) 
        {
            # none service is enabled but module is -> running = 1
            if ($self->service()) {
                return 1;
            }

        }


    return 0;
}



#
# Method: service
#
#  Returns the state of the service.
#
# Returns:
#
#  boolean - true if it's active, otherwise false
#
sub service
{
    my ($self) = @_;
    return $self->isEnabled();
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
    $self->antivirus()->stopService();
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

  if (not $self->service()) {
      return undef;
  }


  my $externalMTAs = $self->smtpFilter()->allowedExternalMTAs();
  return new EBox::MailFilter::FirewallHelper(
                              smtpFilter          => $self->smtpFilter()->service,
                              antivirusActive => $self->antivirus->service,
                              port            => $self->smtpFilter()->port,
                              fwport          => $self->smtpFilter()->fwport,
                              externalMTAs    => $externalMTAs,
                              POPProxy        => $self->popProxy->service,
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
        my $self = shift;

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
        my $self = shift;

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
            'title' => __("Mail filter"),
            'widget' => \&mailFilterWidget,
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
                  'date' => __('Date'),

                  'action' => __('Action'),
                  'event' => __('Event'),

                  from_address => __('Sender address'),
                  to_address => __('Recipient address'),

                  'spam_hits' => __('Spam hits'),
    };
    my @order = qw( date event action from_address to_address spam_hits );

    my $events = {
                  'BAD-HEADER' => __('Bad header found'),
                  'SPAM'      => __('Spam found'),
                  'BANNED' => __('Forbidden attached file  found'),
                  'BLACKLISTED' => __('Address in blacklist found'),
                  'INFECTED'    => __('Virus found'),
                  'CLEAN'       => __('Clean message'),
    };


    my $consolidate = {
                       mailfilter_traffic => _filterTrafficConsolidationSpec(),
                      };


    return {
            'name' => __('SMTP filter'),
            'index' => 'mailfilter-smtpFilter',
            'titles' => $titles,
            'order' => \@order,
            'tablename' => 'message_filter',
            'timecol' => 'date',
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
                  'date' => __('Date'),

                  'address' => __('Account'),
                  clientConn => __(q{Client's address}),
                  'event' => __('Event'),

                  mails  => __('Total messages'),
                  clean  => __('Clean messages'),
                  virus  => __('Virus messages'),
                  spam   => __('Spam messages'),
                 };

    my @order = qw( date event address clientConn mails clean virus spam );

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
            'tablename' => 'pop_proxy_filter',
            'timecol' => 'date',
            'filter' => ['date', 'address', 'clientConn'],
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
        
    return {  pop_proxy_filter_traffic => $spec };
}

sub menu
{
    my ($self, $root) = @_;

    my $folder = new EBox::Menu::Folder(
                                        'name' => 'MailFilter',
                                        'text' => __('Mail Filter')
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/Composite/Amavis',
                                      'text' => __('SMTP mail filter')
                 )
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/View/POPProxyConfiguration',
                                      'text' => __('POP transparent proxy')
                 )
    );

    $folder->add(
                 new EBox::Menu::Item(
                                      'url' => 'MailFilter/View/FreshclamStatus',
                                      'text' => __('Antivirus'),
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


1;
