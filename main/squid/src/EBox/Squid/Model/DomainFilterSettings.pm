# Copyright (C) 2007 Warp Networks S.L.
# Copyright (C) 2009-2013 Zentyal S.L.
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

package EBox::Squid::Model::DomainFilterSettings;

use base 'EBox::Model::DataForm';

use EBox;
use EBox::Gettext;
use EBox::Validate;
use EBox::Types::Text;
use EBox::Exceptions::Internal;

# Group: Public methods

sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);

    bless $self, $class;
    return $self;
}

# Method: _table
#
#
sub _table
{
    my ($self) = @_;

    my @tableDesc;

    unless ($self->global()->communityEdition()) {
        push (@tableDesc,
            new EBox::Types::Boolean(
                fieldName     => 'httpsBlock',
                printableName => __('Block HTTPS traffic by domain'),
                defaultValue     => 0,
                editable         => 1,
                help             => __('If this is enabled, any domain (not applicable to URLs) which is <b>denied</b> in the ' .
                                       '<i>Domains and URL rules</i> will be blocked at firewall level.'),
                                  ),
        );
    }

    push (@tableDesc,
        new EBox::Types::Boolean(
            fieldName     => 'blanketBlock',
            printableName => __('Block not listed domains and URLs'),
            defaultValue     => 0,
            editable         => 1,
            help             => __('If this is enabled, ' .
                                   'any domain or URL which is neither present neither in the ' .
                                   '<i>Domains and URL rules</i> nor in the <i>Domain list files</i> sections below will be ' .
                                   'forbidden.'),
                              ),
        new EBox::Types::Boolean(
            fieldName     => 'blockIp',
            printableName => __('Block sites specified only as IP'),
            defaultValue  => 0,
            editable      => 1,
           ),
    );

    my $dataForm = {
        tableName          => 'DomainFilterSettings',
        printableTableName => __('Domain filter settings'),
        modelDomain        => 'Squid',
        defaultActions     => [ 'editField', 'changeView' ],
        tableDescription   => \@tableDesc,

        messages           => {
            update => __('Filtering settings changed'),
        },
    };

    return $dataForm;
}

# Method: viewCustomizer
#
#   Overrides <EBox::Model::DataTable::viewCustomizer>
#   to show breadcrumbs
#
sub viewCustomizer
{
    my ($self) = @_;

    my $custom =  $self->SUPER::viewCustomizer();
    $custom->setHTMLTitle([]);

    return $custom;
}

sub usesFilter
{
    my ($self) = @_;
    return $self->value('blockIp');
}

sub squidRulesStubs
{
    my ($self, $profileId) = @_;
    my $policy;
    if ($self->value('blanketBlock')) {
        $policy = 'deny';
    } else {
        $policy = 'allow';
    }

    my $rule = {
        type => 'http_access',
        acl => '',
        policy => $policy,
    };
    return [ $rule ];
}

1;
