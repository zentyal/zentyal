# Copyright (C) 2005-2007 Warp Networks S.L.
# Copyright (C) 2008-2013 Zentyal S.L.
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

package EBox::LdapUserImplementation;

use base qw(EBox::LdapUserBase);

use EBox::Global;
use EBox::Gettext;
use EBox::Exceptions::External;
use EBox::Sudo;

sub _create
{
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub new
{
    my $class = shift;
    my $self  = {};
    my $global = EBox::Global->getInstance(0);
    $self->{samba} = $global->modInstance('samba');
    bless($self, $class);

    return $self;
}

sub _delGroupWarning
{
    my ($self, $group) = @_;

    if (@{$group->users()}) {
        return (__('This group contains members'));
    }

    return undef;
}

# Method: hiddenOUs
#
#   Returns the list of OUs to hide on the UI
#
sub hiddenOUs
{
    return [ 'Builtin', 'Kerberos' ];
}

# User and group addons

# Method: _groupShareEnabled
#
#   Check if there is a share configured for the group
#
# Returns:
#
#   The share name or undef if it is not configured
#
sub _groupShareEnabled
{
    my ($self, $groupName) = @_;

    my $sharesModel = $self->{samba}->model('SambaShares');
    foreach my $id (@{$sharesModel->ids()}) {
        my $row = $sharesModel->row($id);
        my $shareName  = $row->valueByName('share');
        my $groupShare = $row->valueByName('groupShare');
        if (length ($groupShare) and ($groupShare eq $groupName)) {
            return $shareName;
        }
    }

    return undef;
}

sub setGroupShare
{
    my ($self, $group, $shareName) = @_;

    if ((not defined $shareName) or ( $shareName =~ /^\s*$/)) {
        throw EBox::Exceptions::External("A name should be provided for the share.");
    }

    my $groupName = $group->name();
    my $oldName = $self->_groupShareEnabled($groupName);
    return if ($oldName and $oldName eq $shareName);

    my $sharesModel = $self->{samba}->model('SambaShares');

    # Create or rename the share for the group
    my $row = $sharesModel->findValue(groupShare => $groupName);
    if ($row) {
        # Rename the share
        EBox::debug("Renaming the share for group '$groupName' from '$oldName' to '$shareName'");
        $row->elementByName('share')->setValue($shareName);
        $row->store();
    } else {
        # Add the share
        my %params = ( share => $shareName,
                       path_selected => 'zentyal',
                       zentyal => $shareName,
                       comment => "Share for group $groupName",
                       guest => 0,
                       groupShare => $groupName );
        EBox::debug("Adding share named '$shareName' for group '$groupName'");
        my $shareRowId = $sharesModel->addRow(%params, readOnly => 1, enabled => 1);
        my $shareRow = $sharesModel->row($shareRowId);
        # And set the access control
        my $accessModel = $shareRow->subModel('access');
        %params = ( user_group_selected => 'group',
                    group => $groupName,
                    permissions => 'readWrite' );
        $accessModel->addRow(%params);
    }
}

sub removeGroupShare
{
    my ($self, $groupName) = @_;

    my $sharesModel = $self->{samba}->model('SambaShares');
    my $row = $sharesModel->findValue(groupShare => $groupName);
    $sharesModel->removeRow($row->id()) if $row;
}

sub _groupAddOns
{
    my ($self, $zentyalGroup) = @_;

    return unless ($self->{samba}->configured() and
                   $self->{samba}->isEnabled() and
                   $self->{samba}->isProvisioned());

    my $groupName = $zentyalGroup->name();
    my $share = $self->_groupShareEnabled($groupName);
    my $args =  {
        'groupname' => $zentyalGroup->dn(),
        'share'     => $share,
        'service'   => $self->{samba}->isEnabled(),
    };

    return {
        title => __('Sharing directory for this group'),
        path => '/samba/samba.mas',
        params => $args
       };
}


1;
