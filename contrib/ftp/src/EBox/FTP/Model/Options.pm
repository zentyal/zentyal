# Copyright (C) 2010-2013 Zentyal S. L.
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

package EBox::FTP::Model::Options;

use base 'EBox::Model::DataForm';

use EBox::Global;
use EBox::Gettext;
use EBox::Types::Select;
use EBox::Types::Boolean;
use EBox::View::Customizer;
use EBox::Exceptions::External;

sub new
{
    my $class = shift @_;

    my $self = $class->SUPER::new(@_);
    bless($self, $class);

    return $self;
}

# Method: viewCustomizer
#
# Overrides:
#
#       <EBox::Model::DataTable::viewCustomizer>
#
# XXX FIXME not working
sub viewCustomizer
{
    my ($self) = @_;

    my $customizer = new EBox::View::Customizer();
    $customizer->setModel($self);

    my @fields = ('chrootUsers', 'ssl');

    $customizer->setOnChangeActions(
            { 'userHomes' =>
                {
                  'on' => {
                        enable  => \@fields,
                        disable => [],
                    },
                  'off' => {
                        enable  => [],
                        disable => \@fields,
                    },
                }
            });
    return $customizer;
}

# Method: validateTypedRow
#
#   Check if configuration is consistent.
#
# Overrides:
#
#       <EBox::Model::DataTable::validateTypedRow>
#
sub validateTypedRow
{
    my ($self, $action, $params_r, $actual_r) = @_;

    my $anonymous = exists $params_r->{anonymous} ? $params_r->{anonymous}->value() :
                                                    $actual_r->{anonymous}->value();

    my $userHomes= exists $params_r->{userHomes} ? $params_r->{userHomes}->value() :
                                                   $actual_r->{userHomes}->value();

   if ($anonymous eq 'disabled' and not $userHomes) {
        throw EBox::Exceptions::External(__('Your configuration doesn\'t allow anonymous neither authenticated FTP access.'));
   }
}

sub _populateAnonymous
{
    my @values = (
        {
          'value' => 'disabled',
          'printableValue' => __('Disabled'),
        },
        {
          'value' => 'readonly',
          'printableValue' => __('Read only'),
        },
        {
          'value' => 'write',
          'printableValue' => __('Read/Write'),
        },
    );

    return \@values;
}

sub _populateSSLsupport
{
    my @options = (
                       { value => 'disabled' , printableValue => __('Disabled')},
                       { value => 'allowssl', printableValue => __('Allow SSL')},
                       { value => 'forcessl', printableValue => __('Force SSL')},
                  );
    return \@options;
}

sub _table
{
    my @tableDesc =
        (
         new EBox::Types::Select(
                fieldName => 'anonymous',
                printableName => __('Anonymous access'),
                populate => \&_populateAnonymous,
                editable => 1,
                defaultValue => 'disabled',
                help => __('Enable anonymous FTP access to the /srv/ftp directory.'),
               ),
         new EBox::Types::Boolean(
                fieldName => 'userHomes',
                printableName => __('Personal directories'),
                editable => 1,
                defaultValue => 1,
                help => __('Enable authenticated FTP access to each user home directory.'),
               ),
         new EBox::Types::Boolean(
                fieldName => 'chrootUsers',
                printableName => __('Restrict to personal directories'),
                editable => 1,
                defaultValue => 1,
                help => __('Restrict access to each user home directory. Take into account that this restriction can be circumvented under some conditions.'),
               ),
         new EBox::Types::Select(
                fieldName     => 'ssl',
                printableName => __('SSL support'),
                editable      => 1,
                populate => \&_populateSSLsupport,
                defaultValue => 'forcessl',
                help => __('Enable FTP SSL support for authenticated users.'),
               ),
        );

    my $dataForm = {
                tableName          => 'Options',
                printableTableName => __('General configuration settings'),
                pageTitle          => __('FTP Server'),
                modelDomain        => 'FTP',
                defaultActions     => [ 'editField', 'changeView' ],
                tableDescription   => \@tableDesc,
                help               => __('The anonymous directory is /srv/ftp, make sure that the files you create there have read permissions for everybody (sudo chmod o+r /srv/ftp/*). If you also want to grant write permissions you need to create a subdirectory with write permissions for everybody, for example: sudo mkdir /srv/ftp/incoming ; sudo chmod o+rwx /srv/ftp/incoming. Anonymous access won\'t be able to rename or delete files in any case.'),
    };

    return $dataForm;
}

sub anonymous
{
    my ($self) = @_;

    return $self->row()->valueByName('anonymous');
}

sub userHomes
{
    my ($self) = @_;

    return $self->row()->valueByName('userHomes');
}

sub chrootUsers
{
    my ($self) = @_;

    return $self->row()->valueByName('chrootUsers');
}

sub ssl
{
    my ($self) = @_;

    return $self->row()->valueByName('ssl');
}

1;
