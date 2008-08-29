# Copyright (C) 2008 eBox technologies 
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

# Class: EBox::L7Protocols
#   
#   FIXME
#

package EBox::L7Protocols;

use strict;
use warnings;

use base qw(EBox::GConfModule EBox::Model::ModelProvider);


use EBox::Validate qw( :all );
use EBox::Global;
use EBox::Services::Model::ServiceConfigurationTable;
use EBox::Services::Model::ServiceTable;
use EBox::Gettext;

use EBox::Exceptions::InvalidData;
use EBox::Exceptions::MissingArgument;
use EBox::Exceptions::DataExists;
use EBox::Exceptions::DataMissing;
use EBox::Exceptions::DataNotFound;

use constant PROTOCOL_DIRS => ('/etc/l7-protocols/protocols', 
                               '/etc/l7-protocols/extra');
use constant INITIAL_GROUPS => qw(streaming_audio remote_access mail
                                  streaming_video chat voip game p2p);


sub _create
{
    my $class = shift;
    my $self = $class->SUPER::_create(name => 'l7-protocols',
            printableName => __('Layer-7 protocols'),
            domain => 'ebox-l7-protocols',
            @_);
    bless($self, $class);
    return $self;
}

## api functions

# Method: models
#
# Overrides:
#
#       <EBox::Model::ModelProvider::modelClasses>
#
sub modelClasses
{

    my ($self) = @_;
    
    return  [
               'EBox::L7Protocols::Model::Protocols',
               'EBox::L7Protocols::Model::Groups',
               'EBox::L7Protocols::Model::GroupProtocols',
           ];

}

# Method: menu 
#
#       Overrides EBox::Module method.
#   
#
sub menu
{
    my ($self, $root) = @_;
    my $item = new EBox::Menu::Item(
    'url' => 'l7-protocols/View/Groups',
    'text' => __('Application based protocols'),
    'order' => 3);
    $root->add($item);
}

# Method: populateProtocols
#
#   This method is meant to be used by the migration script to
#   populate the models with the protocols and groups created
#   by the l7-filter package
#
sub populateProtocols
{
    my ($self) = @_;

    my $packageProtocols = _fetchProtocols();
    my $protocolModel = $self->model('Protocols');
    
    for my $protocol (sort @{$packageProtocols->{protocols}}) {
        next if ($protocolModel->row($protocol));
        $protocolModel->addRow(id => $protocol, protocol => $protocol);
    }

    my $groupModel = $self->model('Groups');
    for my $group (INITIAL_GROUPS) {
        my $row = $groupModel->find(group => $group);
        unless (defined($row)) {
           my $id = $groupModel->addRow(group => $group);
           $row = $groupModel->row($id);
        }
        my $subModel = $row->subModel('protocols');
        for my $protocol (sort @{$packageProtocols->{groups}->{$group}}) {
            next if ($subModel->find(protocol => $protocol));
            $subModel->addRow(protocol => $protocol);
        }
    }
}

# Private methods
#

sub _fetchGroups
{
    my ($filename) = @_;
    
    open (my $fd, $filename) or return;

    for my $line (<$fd>) {
        if ($line =~ /# Protocol groups: (.+)\n/) {
            my  @groups = split (' ', $1);
            close ($fd);
            return @groups;
        }
    }
    close ($fd);
    return ();
}

sub _fetchProtocols
{
    my $groups;
    my @protocols;
    for my $dirname (PROTOCOL_DIRS) {
        opendir ( my $DIR, $dirname ) || next;
        while((my $filename = readdir($DIR))){
            next unless ($filename =~ /\.pat$/);
            my ($protocol) = $filename =~ m/(.*).pat$/;
            push (@protocols, $protocol);
            for my $group (_fetchGroups("$dirname/$filename")) {
                push (@{$groups->{$group}}, $protocol);
            }

        }
        closedir($DIR); 
    }

    return { groups => $groups, protocols => \@protocols };
}

1;
