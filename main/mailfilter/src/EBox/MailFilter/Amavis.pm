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

package EBox::MailFilter::Amavis;

use Perl6::Junction qw(any all);
use File::Slurp qw(read_file write_file);
use EBox::Config;
use EBox::Service;
use EBox::Gettext;
use EBox::Exceptions::Internal;
use TryCatch;

use EBox::Dashboard::ModuleStatus;
use EBox::Dashboard::Section;

use EBox::MailFilter::VDomainsLdap;
use EBox::MailVDomainsLdap;

use EBox::Ldap;

use constant {
  AMAVIS_SERVICE                => 'amavis',
  AMAVIS_CONF_FILE              => '/etc/amavis/conf.d/01-zentyal',
  AMAVISPIDFILE                 => '/var/run/amavis/amavisd.pid',
                                   # which this modules provides
  MAILFILTER_NAME => 'mailfilter', # name used to identify the filter
                                   # which mavis provides
};

sub new
{
    my ($class, $global) = @_;

    my $self = {};
    bless $self, $class;
    $self->{global} = $global;

    return $self;
}

sub global
{
    my ($self) = @_;
    return $self->{global};
}

sub usedFiles
{
    my @usedFiles = (
                     {
                      'file' =>   AMAVIS_CONF_FILE,
                      'reason' => __('To configure amavis'),
                      'module' => 'mailfilter'
                     },
                    );

    return \@usedFiles;
}

sub doDaemon
{
    my ($self, $mailfilterService) = @_;

    if ($mailfilterService and $self->isEnabled() and $self->isRunning()) {
        $self->_daemon('restart');
    } elsif ($mailfilterService and $self->isEnabled()) {
        $self->_daemon('start');
    } elsif ($self->isRunning()) {
        $self->_daemon('stop');
    }
}

sub _daemon
{
    my ($self, $action) = @_;
    EBox::Service::manage(AMAVIS_SERVICE, $action);
}

sub isEnabled
{
    my ($self) = @_;
    my $mailfilter = EBox::Global->modInstance('mailfilter');
    return $mailfilter->isEnabled();
}

# we ignore freshclam running state
sub isRunning
{
    my ($self) = @_;

    try {
        return EBox::Service::running(AMAVIS_SERVICE);
    } catch (EBox::Exceptions::Internal $e) {
        return undef;
    }
}

sub stopService
{
    my ($self) = @_;

    if ($self->isRunning()) {
        $self->_daemon('stop');
    }
}

sub writeConf
{
    my ($self) = @_;

    my $usersMod = $self->global()->modInstance('samba');
    my $ldap = $usersMod->ldap();

    my $antivirus   = $self->global()->modInstance('antivirus');
    my $mailfilter  = $self->global()->modInstance('mailfilter');
    my $antispam   = $mailfilter->antispam();

    my @masonParams;

    push @masonParams, (myhostname => $self->_fqdn());
    push @masonParams, (mydomain => $self->_domain());
    push @masonParams, (localDomains => $self->_localDomains());

    push @masonParams, (port => $self->port);

    push @masonParams, (allowedExternalMTAs => $self->allowedExternalMTAs);

    push @masonParams, (ldapBase         =>  EBox::MailVDomainsLdap::VDOMAINDN() . ',' . $ldap->dn );
    push @masonParams, (ldapQueryFilter  =>  '(&(objectClass=amavisAccount)(|(mail=%m)(domainMailPortion=%m)))');
    push @masonParams, (ldapBindDn       =>  $mailfilter->_kerberosServiceAccountDN());
    push @masonParams, (ldapBindPasswd   =>  $mailfilter->_kerberosServiceAccountPassword());

    push @masonParams, (antivirusActive  => $self->antivirus());
    push @masonParams, (virusPolicy      => $self->filterPolicy('virus'));
    push @masonParams, (clamdSocket     => $antivirus->localSocket());

    push @masonParams, (antispamActive     => $self->antispam());
    push @masonParams, (spamThreshold => $antispam->spamThreshold());
    push @masonParams, (spamSubject   =>  $antispam->spamSubjectTag);
    push @masonParams, (spamPolicy         => $self->filterPolicy('spam'));
    push @masonParams, (antispamWhitelist  => $antispam->whitelistForAmavisConf());
    push @masonParams, (antispamBlacklist  => $antispam->blacklistForAmavisConf());

    push @masonParams, (bannedPolicy      => $self->filterPolicy('banned'));
    push @masonParams, (bannedFileTypes   => $self->bannedFilesRegexes);

    push @masonParams, (bheadPolicy      => $self->filterPolicy('bhead'));

    push @masonParams, (adminAddress => $self->adminAddress);

    push @masonParams, (debug => EBox::Config::boolean('debug'));

    my $uid = getpwnam('root');
    my $gid = getgrnam('root');

    my $fileAttrs = {
                     mode => '0640',
                     uid   => $uid,
                     gid   => $gid,
                     force => 1,
                    };

    EBox::Module::Base::writeConfFileNoCheck(AMAVIS_CONF_FILE, '/mailfilter/amavisd.conf.mas', \@masonParams, $fileAttrs);
}

sub antivirus
{
    my ($self) = @_;
    return $self->_confAttr('antivirus');
}

sub antispam
{
    my ($self) = @_;
    return $self->_confAttr('antispam');
}

# Method: port
#
# Returns:
#  return the port used by the mail filter for input
#
sub port
{
    my ($self) = @_;
    return $self->_confAttr('port');
}

# Method: fwport
#
# Returns:
#  return the port used by the mail filter for forwarding messages to the mta
#
sub fwport
{
    my ($self) = @_;

    # The static port number is also overridden, and cally
    # calculated  as being one above the incoming SMTP/LMTP session port number.
    my $fwport = $self->port() + 1;
    return $fwport;
}

sub _confAttr
{
    my ($self, $attr) = @_;

    if (not $self->{configuration}) {
        my $mailfilter = $self->global()->modInstance('mailfilter');
        $self->{configuration}     = $mailfilter->model('AmavisConfiguration');
    }

    my $row = $self->{configuration}->row();
    return $row->valueByName($attr);
}

sub _domain
{
    my $domain = `hostname --domain`;

    if ($? != 0) {
        throw EBox::Exceptions::Internal('Zentyal was unable to get the domain for its host/' .
                                         'Please, check than your resolver and /etc/hosts file are propely configured.'
                                        );
    }

    chomp $domain;

    if (not $domain) {
        return 'localdomain';
    }

    return $domain;
}

sub _fqdn
{
    my $fqdn = `hostname --fqdn`;

    if ($? != 0) {
        throw EBox::Exceptions::Internal(
            'Zentyal was unable to get the full qualified domain name (FQDN) for its host/' .
            'Please, check than your resolver and /etc/hosts file are propely configured.'
                                        );
    }

    chomp $fqdn;

    if (not $fqdn =~ m/\./) {
        my $domain = _domain();
        return "$fqdn.$domain";
    }

    return $fqdn;
}

sub _localDomains
{
    my ($self) = @_;

    my @vdomains =  EBox::MailVDomainsLdap->new->vdomains();
    push @vdomains, @{ $self->externalDomains() };
    push @vdomains, $self->global()->modInstance('sysinfo')->hostDomain();
    push @vdomains, $self->global()->modInstance('sysinfo')->fqdn();

    return [@vdomains];
}

# Method : allowedExternalMTAs
#
#  get the list of external MTA's addresses which are allowed to connect to the
#  filter.
#
#  Returns:
#   the MTAs list as a list reference
sub allowedExternalMTAs
{
    my ($self) = @_;

    my $mailfilter  = $self->global()->modInstance('mailfilter');
    my $externalMTA = $mailfilter->model('ExternalMTA');
    return $externalMTA->allowed();
}

sub externalDomains
{
    my ($self) = @_;

    my $mailfilter  = $self->global()->modInstance('mailfilter');
    my $externalDomain = $mailfilter->model('ExternalDomain');
    return $externalDomain->allowed();
}

sub adminAddress
{
    my ($self) = @_;

    my $mailfilter  = $self->global()->modInstance('mailfilter');
    my $amavisConfiguration = $mailfilter->model('AmavisConfiguration');
    return $amavisConfiguration->notificationAddress();
}

sub bannedFilesRegexes
{
    my ($self) = @_;

    my $mailfilter  = $self->global()->modInstance('mailfilter');

    my @bannedRegexes;

    my $extensionACL = $mailfilter->model('FileExtensionACL');
    push @bannedRegexes, @{ $extensionACL->bannedRegexes() };

    my $mimeACL = $mailfilter->model('MIMETypeACL');
    push @bannedRegexes, @{ $mimeACL->bannedRegexes() };

    return \@bannedRegexes;
}

# Method: filterPolicy
#
#  Returns the policy of a filter type passed as parameter. The filter type
#  could be:
#       - virus: Virus filter.
#       - spam: Spam filter.
#       - bhead: Bad headers checks.
#       - banned: Banned names and types checks.
#  And the policy:
#       - D_PASS
#       - D_REJECT
#       - D_BOUNCE
#       - D_DISCARD
#
# Parameters:
#
#  ftype - A string with filter type.
#
# Returns:
#
#  string - The string with the policy established to the filter type.
#
sub filterPolicy
{
    my ($self, $ftype) = @_;

    my $mailfilter  = $self->global()->modInstance('mailfilter');
    my $model = $mailfilter->model('AmavisPolicy');

    my $methodValue = $ftype . 'Value';
    return $model->$methodValue();
}

## firewall method
sub usesPort
{
    my ($self, $protocol, $port, $iface) = @_;

    if ($protocol ne 'tcp') {
        return undef;
    }

    # if we have a interface specified we can check if we don't use it.
    if ((defined $iface) and ($iface ne 'lo')) {
        # see if we need to listen in normal interfaces
        my $externalMTAs = @{ $self->allowedExternalMTAs() } > 0;
        if (not $externalMTAs) {
            return undef;
        }
    }

    if ($port == $self->port) {
        return 1;
    }
    elsif ($port == $self->fwport) {
        return 1;
    }

    return undef;
}

#  Method: mailFilterName
#
#   Implements the method needed for EBox::Mail::FilterProvider
sub mailFilterName
{
    return MAILFILTER_NAME;
}

#  Method: mailFilter
#
#   Reimplements the method needed for EBox::Mail::FilterProvider
sub mailFilter
{
    my ($self) = @_;

    my $name = $self->mailFilterName;
    my $active;

    my $module = $self->global()->modInstance('mailfilter');
    if (not $module->isEnabled()) {
        $active = 0;
    }  else {
        $active = $self->isEnabled() ? 1 : 0;
    }

    my %properties = (
            address     => '127.0.0.1',
            port        => $self->port(),
            forwardPort => $self->fwport,
            prettyName  => __('Zentyal internal mail filter'),
            module      => 'mailfilter',
            active      => $active,
            );

    return ($name, \%properties);
}

sub summary
{
    my ($self, $summary) = @_;

    my $section = new EBox::Dashboard::Section('SMTPProxy',
                                               __("SMTP filter proxy"));
    $summary->add($section);

    my $enabled = $self->isEnabled();
    my $status =  new EBox::Dashboard::ModuleStatus(
        module        => 'mailfilter',
        printableName => __('Status'),
        running       => $self->isRunning(),
        enabled       => $self->isEnabled(),
        nobutton      => 1);

    $section->add($status);

    $enabled or return;

    my $mailfilter = $self->global()->modInstance('mailfilter');

    my $antispam = new EBox::Dashboard::ModuleStatus(
            module        => 'mailfilter',
            printableName =>__('Antispam'),
            enabled       => $self->antispam(),
            running       => $mailfilter->antispam()->isRunning(),
            nobutton      => 1);
    $section->add($antispam);
}

1;
