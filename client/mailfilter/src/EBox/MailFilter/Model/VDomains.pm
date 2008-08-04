# Copyright (C) 2008 Warp Networks S.L.
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

package EBox::MailFilter::Model::VDomains;
use base 'EBox::Model::DataTable';


# eBox uses
use EBox;

use EBox::Exceptions::Internal;
use EBox::Gettext;
use EBox::Types::Boolean;
use EBox::Types::DomainName;
use EBox::Types::Select;
use EBox::Types::Text;
use EBox::Types::Union;
use EBox::Types::Union::Text;
use EBox::Types::HasMany;

use EBox::MailVDomainsLdap;

# Group: Public methods

# Constructor: new
#
#       Create the new  model
#
# Overrides:
#
#       <EBox::Model::DataTable::new>
#
sub new
{
    my $class = shift;

    my $self = $class->SUPER::new(@_);
    
    bless $self, $class;
    return $self;
}

# Group: Protected methods

# Method: _table
#
#       The table description 
#
sub _table
{
  my @tableHeader =
    (
     new EBox::Types::Select(
                             fieldName     => 'vdomain',
                             printableName => __('Domain'),

                             foreignModel  => \&_vdomainModel,
                             foreignField  => 'vdomain',

                             unique        => 1,
                             editable      => 1,
                            ),
     new EBox::Types::Boolean(
                              fieldName     => 'antivirus',
                              printableName => __('Use virus filtering'),
                              editable      => 1,
                              defaultValue  => 1,
                             ),
     new EBox::Types::Boolean(
                              fieldName     => 'antispam',
                              printableName => __('Use spam filtering'),
                              editable      => 1,
                              defaultValue  => 1,
                             ),
     new EBox::Types::Union(
                            fieldName => 'spamThreshold',
                            printableName => __('Spam threshold'),
                            editable  => 1,
                            subtypes => [
                                         new EBox::Types::Union::Text(
                                                               'fieldName' => 
                                                              'defaultThreshold',
                                                               'printableName' =>
                                                                  __('default'),
                                                              ),
                                new EBox::MailFilter::Types::AntispamThreshold (
                                          'fieldName' => 'customThreshold', 
                                          'printableName' => __('custom threshold'), 
                                           'editable' => 1,
               
                                                                               ),


                                            ],

                               ),
     new EBox::Types::Boolean(
                              fieldName     => 'hamAccount',
                              printableName => __('Learning ham account'),
                              help => __('An address (ham@domain) will be made in this domain, ham messages incorreclty classified as spam may be forwarded to this addres to train the filter'),
                              
                              defaultValue => 0,
                              editable     => 1,
                              
                             ),
     new EBox::Types::Boolean(
                              fieldName     => 'spamAccount',
                              printableName => __('Learning spam account'),
                              help => __('An address (spam@domain) will be made in this domain, ham messages incorreclty classified as ham may be forwarded to this addres to train the filter'),
                              
                              defaultValue => 0,
                              editable     => 1,
                              
                             ),
            new EBox::Types::HasMany (
                                      'fieldName' => 'acl',
                                      'printableName' => __('Antispam sender policy'),
                                      'foreignModel' => 'AntispamACL',
                                      'view' => '/ebox/MailFilter/View/AntispamACL',
                                      'backView' => '/ebox/MailFilter/View/VDomain',
                                      'editable'  => 1,
                            ),
    );

  my $dataTable =
    {
     tableName          => __PACKAGE__->nameFromClass,
     printableTableName => __(q{Virtual domains configuration}),
     modelDomain        => 'mail',
     'defaultController' => '/ebox/MailFilter/Controller/VDomains',
     'defaultActions' => [      
                          'add', 'del',
                          'editField',
                          'changeView'
                         ],
     tableDescription   => \@tableHeader,
     class              => 'dataTable',
     order              => 0,
     printableRowName   => __("virtual domain"),
     help               =>'',
    };

}




sub _vdomainModel
{
    my $mail = EBox::Global->getInstance()->modInstance('mail');
    return $mail->model('VDomains');
}


sub _findRowByVDomain
{
    my ($self, $vdomain) = @_;
    
    my $id = $self->_vdomainId($vdomain);
    return $self->findRow(vdomain => $id);
}

sub _vdomainId
{
    my ($self, $vdomain) = @_;

    my $vdomainsModel = $self->_vdomainModel();
    return $vdomainsModel->findId(vdomain => $vdomain);
}


sub spamThreshold
{
    my ($self, $vdomain) = @_;

    my $row = $self->_findRowByVDomain($vdomain);

    return $self->spamThresholdFromRow($row);
}


sub spamThresholdFromRow
{
    my ($self, $row) = @_;

    my $threshold = $row->elementByName('spamThreshold');

    if ($threshold->selectedType() eq 'defaultThreshold') {
        return undef;
    }

    my $addr = $threshold->subtype()->value();
    return $addr;
}



# return the row for a given vdomain. If the vdomain has not a configuration row
# it creates it with the default values
sub vdomainRow
{
    my ($self, $vdomain) = @_;

    my $vdRow;
  
    $vdRow = $self->_findRowByVDomain($vdomain);
    if (not $vdRow) {
        my $vdomainId      = $self->_vdomainId($vdomain);
        # create a row for the vdomain
        $self->add(
                   vdomain => $vdomainId,
#                    antivirus => 1,
#                    antispam  => 1,
                   
                   spamThreshold => { defaultThreshold => '' },

   #                 hamAccount  => 0,
#                    spamAccount => 0,
                   

                  );

        $vdRow = $self->_findRowByVDomain($vdomain);
    }


    return $vdRow;
}

sub removeVDomain
{
    my ($self, $vdomain) = @_;

    my $row = $self->_findRowByVDomain($vdomain);

    my $id = $row->id();
    defined $id or
        throw EBox::Exceptions::Internal("Not existent- vdomain $vdomain");

    $self->removeRow($id, 1);
}

sub nameFromRow
{
    my ($self, $row) = @_;

    my $vdomainsModel = $self->_vdomainModel();
    my $vdomainId = $row->elementByName('vdomain')->value();
    my $vdomainRow = $vdomainsModel->row($vdomainId);

    return $vdomainRow->elementByName('vdomain')->value();
}


sub addVDomainSenderACL
{
    my ($self, $vdomain, $sender, $policy) = @_;

    my $vdRow = $self->vdomainRow($vdomain);
    my $acl = $vdRow->subModel('acl');
    my $aclRow = $acl->findRow(sender => $sender);
    if ($aclRow) {
        $aclRow->elementByName('policy')->setValue($policy);
        $aclRow->store();
    }
    else {
        $acl->addRow(
                     sender => $sender,
                     policy => $policy,
                    );
    }

}


1;

