package EBox::MailFilter::ClamAV;
# package:
use strict;
use warnings;

use Perl6::Junction qw(any all);
use File::Slurp qw(read_file write_file);
use EBox::Config;
#use EBox::Service;
use EBox::Gettext;
use EBox::Global;

use EBox::MailFilter::VDomainsLdap;

# use constant {
#   CLAMAVPIDFILE                 => '/var/run/clamav/clamd.pid',
#   CLAMD_INIT                    => '/etc/init.d/clamav-daemon',
#   CLAMD_SERVICE                  => 'ebox.clamd',
#   CLAMD_CONF_FILE               => '/etc/clamav/ebox.clamd.conf',

#   CLAMD_SOCKET                  => '/var/run/clamav/clamd.ctl',

#   FRESHCLAM_CONF_FILE           => '/etc/clamav/freshclam.conf',
#   FRESHCLAM_OBSERVER_SCRIPT     => 'freshclam-observer',
#   FRESHCLAM_CRON_SCRIPT         => '/etc/cron.hourly/freshclam',
# };




sub new
{
  my $class = shift @_;

  my $self = {};
  bless $self, $class;

  return $self;
}

sub _mailfilterModule
{
  return EBox::Global->modInstance('mailfilter');
3}



sub setVDomainService
{
  my ($self, $vdomain, $service) = @_;

  my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();
  $vdomainsLdap->checkVDomainExists($vdomain);
  $vdomainsLdap->setAntivirus($vdomain, $service);
}


sub vdomainService
{
  my ($self, $vdomain) = @_;

  my $vdomainsLdap = EBox::MailFilter::VDomainsLdap->new();
  $vdomainsLdap->checkVDomainExists($vdomain);
  $vdomainsLdap->antivirus($vdomain);
}





1;
