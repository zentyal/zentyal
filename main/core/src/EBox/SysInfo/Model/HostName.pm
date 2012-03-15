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

use base 'EBox::Model::DataForm';

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    return $self;
}

#<div class="note"><% __x('The hostname will be changed to {newHostname} after saving changes.', newHostname => "<b>$newHostname</b>") %></div>


sub _table
{
    my ($self) = @_;

    my @tableHead = (new EBox::Types::Text( fieldName      => 'hostname',
                                            printableValue => __('Host name'),
                                            editable       => 1),

                     new EBox::Types::Text( fieldName      => 'hostdomain',
                                            printableValue => __('Host domain'),
                                            editable       => 1,
                                            help           => __('You will need to restart all the services or reboot the system to apply the hostname change.')));

    my $dataTable =
    {
        'tableName' => 'HostName',
        'printableTableName' => __('Host name and domain'),
        'modelDomain' => 'SysInfo',
        'defaultActions' => [ 'editField' ],
        'tableDescription' => \@tableHead,
        'help' => __('On this page you can set different general system settings'),
    };

    return $dataTable;
}

# Method: formSubmitted
#
# Overrides:
#
#   <EBox::Model::DataForm::formSubmitted>
#
sub formSubmitted
{
    my ($self) = @_;

    #if (defined($self->param('sethostname'))) {
    #    my $hostname = $self->param('hostname');
    #    my $oldHostname = Sys::Hostname::hostname();
    #    if ($hostname ne $oldHostname) {
    #        EBox::Validate::checkHost($hostname, __('hostname'));
    #        my $global = EBox::Global->getInstance();
    #        my $apache = $global->modInstance('apache');
    #        $apache->set_string('hostname', $hostname);
    #        my $audit = EBox::Global->modInstance('audit');
    #        $audit->logAction('System', 'General', 'changeHostname', $hostname);
    #        $global->modChange('apache');
    #    }
    #}
}

1;
