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

package EBox::CGI::MailFilter::Index;

use strict;
use warnings;

use base 'EBox::CGI::ClientBase';

use EBox::Global;
use EBox::Gettext;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new('title'    => __('Mail filter'),
				      'template' => 'mailfilter/index.mas',
				      @_);
	$self->{domain} = 'ebox-mailfilter';
	bless($self, $class);
	return $self;
}



sub _process {
	my $self = shift;
	$self->{title} = __('Mail filter');

	my $menu = $self->param('menu');
	($menu) or $menu = 'general';

	my $masonParameterSub = '_' . $menu . 'MasonParameters';
	 $self->can($masonParameterSub) or
	   throw EBox::Exceptions::Internal(
             "Can not found method $masonParameterSub");

	my @masonParameters = ();
	push @masonParameters, (menu => $menu);
	push @masonParameters, $self->$masonParameterSub();


	$self->{params} = \@masonParameters;
}


sub _generalMasonParameters
{
  my ($self) = @_;

  my $mfilter = EBox::Global->modInstance('mailfilter');

  my @masonParameters;
  push @masonParameters, (active => $mfilter->service);
  push @masonParameters, (port => $mfilter->port);
  push @masonParameters, (adminAddress => $mfilter->adminAddress());
  push @masonParameters, (allowedMTAs => $mfilter->allowedExternalMTAs);
  push @masonParameters, (externalDomains => $mfilter->externalDomains);

  return @masonParameters;
}

sub _antivirusMasonParameters
{
  my ($self) = @_;

  my $mailfilter = EBox::Global->modInstance('mailfilter');
  my $antivirus  = $mailfilter->antivirus();

  my @masonParameters;
  push @masonParameters, (active => $antivirus->service);
  push @masonParameters, (policy => $mailfilter->filterPolicy('virus'));
  push @masonParameters, (state => $antivirus->freshclamState);

  return @masonParameters;
}


sub _antispamMasonParameters
{
  my ($self) = @_;

  my $mailfilter = EBox::Global->modInstance('mailfilter');
  my $antispam  = $mailfilter->antispam();

  my @masonParameters;
  push @masonParameters, (active => $antispam->service);
  push @masonParameters, (policy => $mailfilter->filterPolicy('spam'));
  push @masonParameters, (spamThreshold => $antispam->spamThreshold);

  push @masonParameters, (bayes => $antispam->bayes);
  push @masonParameters, (autoWhitelist => $antispam->autoWhitelist);

  push @masonParameters, (autolearn => $antispam->autolearn);
  push @masonParameters, (autolearnHamThreshold => $antispam->autolearnHamThreshold);
  push @masonParameters, (autolearnSpamThreshold => $antispam->autolearnSpamThreshold);

  push @masonParameters, (spamSubjectTag => $antispam->spamSubjectTag);

  push @masonParameters, (spamAccountActive => $antispam->spamAccountActive);
  push @masonParameters, (hamAccountActive  => $antispam->hamAccountActive);

  push @masonParameters, (whitelist => $antispam->whitelist);
  push @masonParameters, (blacklist => $antispam->blacklist);

  return @masonParameters;
}


sub _badHeadersMasonParameters
{
  my ($self) = @_;

  my $mailfilter = EBox::Global->modInstance('mailfilter');

  my @masonParameters;
  push @masonParameters, (policy => $mailfilter->filterPolicy('bhead'));

  return @masonParameters;
}



sub _fileFilterExtensionMasonParameters
{
  my ($self) = @_;

  my $mailfilter = EBox::Global->modInstance('mailfilter');
  my $fileFilter = $mailfilter->fileFilter();

  my @masonParameters;
  push @masonParameters, (policy => $mailfilter->filterPolicy('banned'));
  push @masonParameters, (extensions => $fileFilter->extensions());

  return @masonParameters;
}


sub _fileFilterMimeTypeMasonParameters
{
  my ($self) = @_;

  my $mailFilter = EBox::Global->modInstance('mailfilter');
  my $fileFilter = $mailFilter->fileFilter();

  my @masonParameters;
  push @masonParameters, (policy => $mailFilter->filterPolicy('banned'));
  push @masonParameters, (mimeTypes => $fileFilter->mimeTypes());

  return @masonParameters;
}

1;
