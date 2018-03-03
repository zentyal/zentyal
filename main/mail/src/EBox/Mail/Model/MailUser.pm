# Copyright 2010-2013 Zentyal S.L.
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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

# Class: EBox::Mail::Model::MailUser
#
#   TODO: Document class
#

use strict;
use warnings;

package EBox::Mail::Model::MailUser;

use EBox::Gettext;
use EBox::Validate qw(:all);
use EBox::Types::Port;
use EBox::Types::Select;
use EBox::Global;

use base 'EBox::Model::DataForm';

sub new
{
        my $class = shift;
        my %parms = @_;

        my $self = $class->SUPER::new(@_);
        bless($self, $class);

        return $self;
}

sub _table
{

    my @tableHead =
    (
        new EBox::Types::Boolean(
            'fieldName' => 'enabled',
            'printableName' => __('Mail Account'),
            'editable' => 1,
            'defaultValue' => 1,
            'help' => __('Create mail account user@domain'),
        ),
        new EBox::Types::Select(
            'fieldName' => 'domain',
            'printableName' => __('Default Domain'),
            'editable' => 1,
            'disableCache' => 1,
            'populate' => \&domains,
        ),
    );
    my $dataTable =
    {
        'tableName' => 'MailUser',
        'printableTableName' => __('Mail'),
        'pageTitle' => undef,
        'modelDomain' => 'Mail',
        'defaultActions' => ['add', 'del', 'editField', 'changeView' ],
        'tableDescription' => \@tableHead,
    };

    return $dataTable;
}

sub domains
{
    my @options;

   for my $domain ( EBox::Global->modInstance('mail')->{vdomains}->vdomains()) {
       my $printableValue = '@' . $domain;
        push (@options, { value => $domain, printableValue => $printableValue });
    }

    return \@options;
}

sub precondition
{
    return (scalar(@{domains()}) > 0);
}

sub preconditionFailMsg
{
    return __("You haven't create a mail domain yet");
}
1;
