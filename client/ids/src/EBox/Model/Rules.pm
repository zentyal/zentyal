# Copyright (C) 2009 eBox Technologies S.L.
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

package EBox::IDS::Model::Rules;

# Class: EBox::IDS::Model::Rules
#
#   Class description
#

use base 'EBox::Model::DataTable';

use strict;
use warnings;

use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::Select;

use constant DEFAULT_RULES => qw(local bad-traffic exploit community-exploit
    scan finger ftp telnet rpc rservices dos community-dos ddos dns tftp
    web-cgi web-coldfusion web-iis web-frontpage web-misc web-client web-php
    community-sql-injection community-web-client community-web-dos
    community-web-iis community-web-misc community-web-php sql
    x11 icmp netbios misc attack-responses oracle community-oracle mysql
    snmp community-ftp smtp community-smtp imap community-imap pop2
    pop3 nntp community-nntp community-sip other-ids web-attacks backdoor
    community-bot community-virus);

# Group: Public methods

# Constructor: new
#
#       Create the new model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
# Returns:
#
#       <EBox::IDS::Model::Model> - the recently
#       created model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    my %default = map { $_ => 1 } DEFAULT_RULES;
    $self->{enableDefault} = \%default;

    bless ( $self, $class );

    return $self;

}

# Method: syncRows
#
#   Overrides <EBox::Model::DataTable::syncRows>
#
sub syncRows
{
    my ($self, $currentRows) = @_;

    # If the GConf module is readonly, return current rows
    if ( $self->{'gconfmodule'}->isReadOnly() ) {
        return undef;
    }

    my $modIsChanged = EBox::Global->getInstance()->modIsChanged('ids');

    my @files = </etc/snort/rules/*.rules>;

    my @names;
    foreach my $file (@files) {
        my $slash = rindex ($file, '/');
        my $dot = rindex ($file, '.');
        my $name = substr ($file, ($slash + 1), ($dot - $slash - 1));
        next if $name =~ /deleted/;
        push (@names, $name);
    }
    my %newNames = map { $_ => 1 } @names;

    my %currentNames =
        map { $self->row($_)->valueByName('name') => 1 } @{$currentRows};

    my $modified = 0;

    my @namesToAdd = grep { not exists $currentNames{$_} } @names;
    foreach my $name (@namesToAdd) {
        my $enabled = $self->{enableDefault}->{$name} or 0;
        $self->add(name => $name, enabled => $enabled);
        $modified = 1;
    }

    # Remove old rows
    foreach my $id (@{$currentRows}) {
        my $row = $self->row($id);
        my $name = $row->valueByName('name');
        if (not exists $newNames{$name} or ($name =~ /deleted/)) {
            $self->removeRow($id);
            $modified = 1;
        }
    }

    if ($modified and not $modIsChanged) {
        $self->{'gconfmodule'}->_saveConfig();
        EBox::Global->getInstance()->modRestarted('ids');
    }

    return $modified;
}

# Method: headTitle
#
#   Overrides <EBox::Model::DataTable::headTitle>
#
sub headTitle
{
    return undef;
}

# Group: Protected methods

# Method: _table
#
#       Model description
#
# Overrides:
#
#      <EBox::Model::DataTable::_table>
#
sub _table
{
    my @tableHeader = (
        new EBox::Types::Text(
            'fieldName' => 'name',
            'printableName' => __('Rule Set'),
            'unique' => 1,
            'editable' => 0),
        new EBox::Types::Boolean (
            'fieldName' => 'enabled',
            'printableName' => __('Enabled'),
            'defaultValue' => 0,
            'editable' => 1
        ),
    );

    my $dataTable =
    {
        tableName          => 'Rules',
        printableTableName => __('Rules'),
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableHeader,
        class              => 'dataTable',
        modelDomain        => 'IDS',
        printableRowName   => __('rule'),
        help               => __('help message'),
    };
    return $dataTable;
}

1;
