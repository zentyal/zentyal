# Copyright (C) 2013 Zentyal S. L.
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

package EBox::OpenChange::Model::Configuration;

use base 'EBox::Model::DataForm';

use EBox::DBEngineFactory;
use EBox::Exceptions::Sudo::Command;
use EBox::Gettext;
use EBox::MailUserLdap;
use EBox::Samba::User;
use EBox::Types::MultiStateAction;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::Union;

use TryCatch::Lite;

# Method: new
#
#   Constructor, instantiate new model
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    bless ($self, $class);

    $self->{global} = $self->global();
    $self->{openchangeMod} = $self->parentModule();

    return $self;
}

# Method: _table
#
#   Returns model description
#
sub _table
{
    my ($self) = @_;

    my @tableDesc = ();
    push (@tableDesc, new EBox::Types::Select(
        fieldName     => 'outgoingDomain',
        printableName => __('Outgoing Mail Domain'),
        foreignModel  => $self->modelGetter('mail', 'VDomains'),
        foreignField  => 'vdomain',
        editable      => 1,
        help          => __('Outgoing mail domain of emails sent from this ' .
                            'server will be overwritten with this one.'),
    ));

    my $dataForm = {
        tableName          => 'Configuration',
        printableTableName => __('Configuration'),
        modelDomain        => 'OpenChange',
        defaultActions     => [ 'editField' ],
        tableDescription   => \@tableDesc,
        help               => __x('Configure an {oc} server.',
                                  oc => 'OpenChange Groupware'),
    };

    return $dataForm;
}



1;
