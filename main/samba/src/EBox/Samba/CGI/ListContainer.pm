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

package EBox::Samba::CGI::ListContainer;

use base 'EBox::CGI::ClientPopupBase';

use EBox::Global;
use EBox::Samba;
use EBox::Samba::User;
use EBox::Gettext;
use POSIX qw(ceil setlocale LC_ALL);


sub _checkForbiddenChars
{
    my ($self, $value) = @_;
    # POSIX::setlocale(LC_ALL, EBox::locale());

    # unless ( $value =~ m{^[\w /.?&]+[:\-\@,=\{\}]*$} ) {
    #     my $logger = EBox::logger;
    #     $logger->info("Invalid characters in param value $value.");
    #     $self->{error} ='The input contains invalid characters';
    #     throw EBox::Exceptions::External(__("The input contains invalid " .
    #         "characters. All alphanumeric characters, plus these non " .
    #        "alphanumeric chars: ={},/.?&+:-\@ and spaces are allowed."));
    #     if (defined($self->{redirect})) {
    #         $self->{chain} = $self->{redirect};
    #     }
    #     return undef;
    # }
    # no locale;
}
sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, $class);
    return  $self;
}

sub _process
{
    my ($self) = @_;
    my $global = EBox::Global->getInstance();
    my $samba  = $global->modInstance('samba');

    my @array = ();
    my $dn = $self->param('dn');
    my $tablename = $self->param('tablename');
    my $check = 0;

    if ( defined $self->param('editid') and !($self->param('editid') eq 'undefined')){
        $dn = $self->param('editid');
    }

    my @dnSplit = split(',',$dn);
    my $customCN = undef;

    if ( grep { $_ eq 'CN=Users'} @dnSplit) {
        $check = 1;
    }
    elsif (grep {$_ eq 'CN=Groups'} @dnSplit){
        $check = 1;
        $customCN = $dn;
    }elsif (grep {$_ =~ /^OU=/i} @dnSplit){
        if (! grep { $_ eq 'OU=Domain Controllers'} @dnSplit){
            $check = 1;
            $customCN = $dn;
        }
    }else{

    }

    if($check){
        $self->{template} = '/samba/listusers.mas';
        my $page;
        my $tpages;
        my $pageSize = EBox::Samba::User->defaultPageSize();
        my $tempPageSize = $pageSize;
        my $filter = $self->param('filter');
        my @users;
        if (defined $filter or defined $customCN){
            @users = $samba->usersToTable($filter, $customCN);
        }else{
            @users = $samba->usersToTable();
        }

        my $sizeUsers = scalar @users;

        my $aux = 0;
        $page = $self->param('page');
        unless ($page){
            $page = 0;
        }
        if ($page eq -1){
            EBox::info("ES LA ULTIMA PAGINAAAAAAA");
            $page = $tpages;
        }

        if ($self->param('pageSize')){
            $pageSize = $self->param('pageSize');
            if ($pageSize eq '_all'){
                $tempPageSize = $sizeUsers;
                $tpages = 1;
                $aux = 0;
            }else{
                $tempPageSize = $pageSize;
                $tpages = ceil( $sizeUsers / $pageSize);
                $aux = $page * $pageSize;
            }
        }else{
            $tpages = ceil($sizeUsers / $pageSize);
        }

        my @usersToShow;
        if ($aux + $tempPageSize >= $sizeUsers){
            @usersToShow = @users[$aux..($sizeUsers - 1)];
        }else{
            @usersToShow = @users[$aux..($aux + $tempPageSize - 1)];
        }
        push(@array,'model' => "EBox::Samba::User");
        push(@array,'dn' => $dn);
        push(@array,'page' => $page);
        push(@array,'pageSize' => $pageSize);
        push(@array,'filter' => $filter);
        if ($sizeUsers eq 0) {
            push(@array, 'tpages' => $tpages);
        }else{
            push(@array, 'tpages' => $tpages - 1);
        }
        push(@array,'users' => \@usersToShow);
    }
    $self->{params} =\@array;
}

1;
