# Copyright (C) 2012 eBox Technologies S.L.
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

# Class: EBox::SysInfo::Model::HostName
#
#   This model is used to configure the host name and domain
#

package EBox::SysInfo::Model::HostName;

use strict;
use warnings;

use Error qw(:try);

use EBox::Gettext;
use EBox::SysInfo::Types::DomainName;
use EBox::Types::Host;

use Data::Validate::Domain qw(is_domain);

use base 'EBox::Model::DataForm';

use constant RESOLV_FILE => '/etc/resolv.conf';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Host( fieldName     => 'hostname',
                                            printableName => __('Hostname'),
                                            defaultValue  => \&_getHostname,
                                            editable      => 1),

                     new EBox::SysInfo::Types::DomainName( fieldName     => 'hostdomain',
                                                           printableName => __('Domain'),
                                                           defaultValue  => \&_getHostdomain,
                                                           editable      => 1,
                                                           help          => __('You will need to restart all the services or reboot the system to apply the hostname change.')));

    my $dataTable =
    {
        'tableName' => 'HostName',
        'printableTableName' => __('Hostname and Domain'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
        'confirmationDialog' => {
              submit => sub {
                  my ($self, $params) = @_;
                  my $new      = $params->{hostname};
                  my $old      = $self->value('hostname');
                  if ($new eq $old) {
                      # only dialog if it is a hostname change
                      return undef;
                  }

                  my $title = __('Change hostname');
                  my $msg = __x('Are you sure you want to change the hostname to {new}?. You may need to restart all the services or reboot the system to enforce the change',
                              new => $new
                             );
                  return  {
                      title => $title,
                      message => $msg,
                     }
                 }
            }
    };

    return $dataTable;
}

sub _getHostname
{
    my $hostname = `hostname`;
    chomp ($hostname);
    return $hostname;
}

sub _getHostdomain
{
    my $options = {
        domain_allow_underscore => 1,
        domain_allow_single_label => 0,
        domain_private_tld => qr /^[a-zA-Z]+$/,
    };

    my $hostdomain = `hostname -d`;
    chomp ($hostdomain);
    unless (is_domain($hostdomain, $options)) {
        my ($searchdomain) = @{_readResolv()};
        $hostdomain = $searchdomain if (is_domain($searchdomain, $options));
    }

    $hostdomain = 'zentyal.lan' unless (is_domain($hostdomain, $options));

    return $hostdomain;
}

sub _readResolv
{
    my $resolvFH;
    unless (open ($resolvFH, RESOLV_FILE)) {
        EBox::warn ("Couldn't open " . RESOLV_FILE);
        return [];
    }

    my $searchdomain = undef;
    my @dns = ();
    for my $line (<$resolvFH>) {
        $line =~ s/^\s+//g;
        my @toks = split (/\s+/, $line);
        if ($toks[0] eq 'nameserver') {
            push (@dns, $toks[1]);
        } elsif ($toks[0] eq 'search') {
            $searchdomain = $toks[1];
        }
    }
    close ($resolvFH);

    return [$searchdomain, @dns];
}

1;
