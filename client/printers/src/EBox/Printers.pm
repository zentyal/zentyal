# Copyright (C) 2008-2010 Zentyal Technologies S.L.
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

package EBox::Printers;

use strict;
use warnings;

use base qw(EBox::Module::Service EBox::FirewallObserver
            EBox::Model::ModelProvider EBox::LogObserver
            EBox::Model::CompositeProvider);

use EBox::Gettext;
use EBox::Config;
use EBox::Service;
use EBox::Menu::Item;
use EBox::Sudo qw( :all );
use EBox::PrinterFirewall;
use EBox::Printers::LogHelper;
use Net::CUPS::Destination;
use Net::CUPS;

use constant CUPSD => '/etc/cups/cupsd.conf';

sub _create
{
	my $class = shift;
	my $self = $class->SUPER::_create(name => 'printers',
					  printableName => __n('Printer Sharing'),
					  domain => 'ebox-printers' );
	bless($self, $class);
	$self->{'cups'} = new Net::CUPS;
	return $self;
}

# Method: actions
#
#	Override EBox::Module::Service::actions
#
sub actions
{
    return [
    {
        'action' => __('Create spool directory for printers'),
        'reason' => __('Zentyal will create a spool directory ' .
                       'under /var/spool/samba'),
        'module' => 'printers'
    },
    {
        'action' => __('Create log table'),
        'reason' => __('Zentyal will create a new table into its log database ' .
                       'to store printers logs'),
        'module' => 'printers'
    }
    ];
}

# Method: usedFiles
#
#	Override EBox::Module::Service::files
#
sub usedFiles
{
    return [
    {
        'file' => CUPSD,
        'reason' => __('To configure cupsd'),
        'module' => 'printers',
    },
    ];
}

# Method: enableActions
#
#	Override EBox::Module::Service::enableActions
#
sub enableActions
{
    root(EBox::Config::share() . '/ebox-printers/ebox-printers-enable');
}

# Method: enableService
#
# Overrides:
#
#  <EBox::Module::Service::enableService>
#
sub enableService
{
	my ($self, $status) = @_;

	$self->SUPER::enableService($status);

    my $samba = EBox::Global->modInstance('samba');
    $samba->setPrinterService($status);
}

sub restoreDependencies
{
    return [ 'network' ];
}

# Method: modelClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{
    my ($self) = @_;

    return [ 'EBox::Printers::Model::CUPS' ];
}

# Method: compositeClasses
#
# Overrides:
#
#       <EBox::Model::ModelProvider::compositeClasses>
#
sub compositeClasses
{
    my ($self) = @_;

    return [ 'EBox::Printers::Composite::General' ];
}

sub firewallHelper
{
    my ($self) = @_;

    if ($self->isEnabled()) {
        return new EBox::PrinterFirewall();
    }
    return undef;
}

# Method: _setConf
#
#	Override EBox::Module::Base::_setConf
#
sub _setConf
{
    my ($self) = @_;

    my $net = EBox::Global->modInstance('network');
    my $ifacesModel = $self->model('CUPS');
    my @addresses;
    foreach my $row (@{$ifacesModel->enabledRows()}) {
        my $iface = $ifacesModel->row($row)->valueByName('iface');
        my $address = $net->ifaceAddress($iface);
        next unless $address;
        push (@addresses, $address);
    }

    $self->writeConfFile(CUPSD,
                         'printers/cupsd.conf.mas',
                         [ addresses => \@addresses ]);
}

sub _daemons
{
    return [
        {
            'name' => 'ebox.cups'
        }
    ];
}

sub menu
{
	my ($self, $root) = @_;

	my $item = new EBox::Menu::Item('name' => 'Printers Sharing',
					    'url' => 'Printers/Composite/General',
					    'text' => $self->printableName(),
                        'separator' => 'Office',
                        'order' => 550);

	$root->add($item);
}

# Method: networkPrinters
#
#   Returns the printers configured as network printer
#
# Returns:
#
#   array ref - holding the printer id's
#
sub networkPrinters
{
    my ($self) = @_;

    my @ids;
# FIXME: This should be get using Net::CUPS as we are not storing
# printers in our config anymore
#    foreach my $printer (@{$self->printers()}) {
#        my $conf = $self->methodConf($printer->{id});
#        push (@ids, $printer->{id}) if ($conf->{method} eq 'network');
#    }

    return \@ids;
}


# Impelment LogHelper interface

sub tableInfo
{
	my ($self) = @_;

    my $titles = { 'job' => __('Job ID'),
                   'printer' => __('Printer'),
                   'username' => __('User'),
                   'timestamp' => __('Date'),
                   'event' => __('Event')
                 };
    my @order = ('timestamp', 'job', 'printer', 'username', 'event');
    my $events = {
                      'queued' => __('Queued'),
                      'completed' => __('Completed'),
                      'canceled' => __('Canceled'),
                     };

    return [{
             'name' => __('Printers'),
             'index' => 'printers_jobs',
             'titles' => $titles,
             'order' => \@order,
             'tablename' => 'printers_jobs',
             'timecol' => 'timestamp',
             'filter' => ['printer', 'username'],
             'events' => $events,
             'eventcol' => 'event'

            }];
}

sub consolidateReportQueries
{
    return [
            {
             'target_table' => 'printers_jobs_report',
             'query' => {
                         'select' => 'printer,event,count(*) as nJobs',
                         'from' => 'printers_jobs',
                         'group' => 'printer,event',
                        },
            },
            {
             'target_table' => 'printers_jobs_by_user_report',
             'query' => {
                         'select' => 'username,event,count(*) as nJobs',
                         'from' => 'printers_jobs',
                         'group' => 'username,event',
                        },
            },
            {
             target_table => 'printers_usage_report',
             'query' => {
                         'select' => 'printers_jobs.printer, SUM(pages) AS pages, COUNT(DISTINCT printers_jobs.username) AS users',
                          'from' => 'printers_pages,printers_jobs',
                          'group' => 'printers_jobs.printer',
                          'where' => q{(printers_jobs.job = printers_pages.job) and(event='queued')}
                        }
            }
#            {
#              target_table => 'printers_usage_per_user_report',
#              'query' => {
#                          'select' => 'username, SUM(pages) AS used_pages, COUNT(DISTINCT printers_jobs.printer) AS used_printers',
#                           'from' => 'printers_pages,printers_jobs',
#                           'group' => 'username',
#                           'where' => q{(printers_jobs.job = printers_pages.job) and(event='queued')}
#                         }
#             }

           ];
}

# Method: report
#
# Overrides:
#   <EBox::Module::Base::report>
sub report
{
    my ($self, $beg, $end, $options) = @_;

    my $report = {};

    my $db = EBox::DBEngineFactory::DBEngine();

    my @events = qw(queued canceled completed);

    my %eventsByPrinter;
    foreach my $event  (@events) {
        my $results = $self->runMonthlyQuery($beg, $end, {
           'select' => q{printer, SUM(nJobs)},
           'from' => 'printers_jobs_report',
           'group' => 'printer',
           'where' => qq{event='$event'},
                                                         },
           { 'key' => 'printer' });

        while (my ($printer, $res) = each %{ $results }) {
            if (not exists $eventsByPrinter{$printer}) {
                $eventsByPrinter{$printer} = {};
            }
            $eventsByPrinter{$printer}->{$event} = $res->{sum};
        }
    }

    $report->{eventsByPrinter} = \%eventsByPrinter;

    my %eventsByUsername;
    foreach my $event  (@events) {
        my $results = $self->runMonthlyQuery($beg, $end, {
           'select' => q{username, SUM(nJobs)},
           'from' => 'printers_jobs_by_user_report',
           'group' => 'username',
           'where' => qq{event='$event'},
                                                         },
           { 'key' => 'username' });

        while (my ($username, $res) = each %{ $results }) {
            if (not exists $eventsByUsername{$username}) {
                $eventsByUsername{$username} = {};
            }
            $eventsByUsername{$username}->{$event} = $res->{sum};
        }
    }

    $report->{eventsByUser} = \%eventsByUsername;

    my $printerUsage = $self->runMonthlyQuery($beg, $end, {
           'select' => q{printer, pages, users},
           'from' => 'printers_usage_report',
#           'group' => 'printer',
                                                         },
           { 'key' => 'printer' }
                                                    );
    # add job fields to usage report
    foreach my $printer (keys %{ $printerUsage} ) {
        if (not exists $eventsByPrinter{$printer}) {
            next;
        }

        my @jobs = @{ $eventsByPrinter{$printer}->{queued} };
        $printerUsage->{$printer}->{jobs} = \@jobs;
    }

    $report->{printerUsage} = $printerUsage;

    return $report;
}

sub logHelper
{
	my ($self) = @_;

	return (new EBox::Printers::LogHelper());
}

# Method: fetchExternalCUPSPrinters
#
#	This method returns those printers that haven been configured
#	by the user using CUPS.
#
# Returns:
#
#	Array ref - containing the printer names
#
sub fetchExternalCUPSPrinters
{
    my ($self) = @_;

	my $cups = Net::CUPS->new();

	my @printers;
	foreach my $printer ($cups->getDestinations()) {
		my $name = $printer->getName();
		push (@printers, $name);
	}
	return \@printers;
}

1;
