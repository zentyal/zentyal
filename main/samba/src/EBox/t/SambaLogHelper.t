# Copyright (C) 2010 EBox Technologies S.L.
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

use lib '../..';

use Test::More qw(no_plan);
use Test::MockObject;
use EBox::SambaLogHelper;

my $maxResourceLength = EBox::SambaLogHelper::RESOURCE_FIELD_MAX_LENGTH();

my $resourceWithMaxLength = '';
for (1 .. $maxResourceLength) {
    $resourceWithMaxLength .= 'z';
}

my $resourceOverflowLength = $resourceWithMaxLength . 'overflow';
# CAUTION the followng line must be in sync with SambaLogHelper
my $abbrvResourceOverflowLength = '(..) ' . substr($resourceOverflowLength, -($maxResourceLength - 5));
my $logHelper = EBox::SambaLogHelper->new();

my @cases = (

             {
              line => 'Jan 31 15:57:04 ubuntu202 smbd_audit: macaco|192.168.100.113|disconnect|ok|IPC$',
              inserted => 0,
             },
             {
              line => 'Jan 31 15:57:04 ubuntu202 smbd_audit: macaco|192.168.100.113|connect|ok|macaco',
             },
             {
              line => 'Jan 31 15:57:05 ubuntu202 smbd_audit: macaco|192.168.100.113|opendir|ok|./',
              resource => './',
             },
             {
                 line => 'Jan 31 15:57:24 ubuntu202 smbd_audit: macaco|192.168.100.113|opendir|ok|.',
              resource => '.',
             },
             {
              line => 'Jan 31 15:57:24 ubuntu202 smbd_audit: macaco|192.168.100.113|open|ok|w|16_Boris-Luna.mp3',
              resource => '16_Boris-Luna.mp3',
             },
             {
              line => 'Jan 31 15:57:28 ubuntu202 smbd_audit: macaco|192.168.100.113|disconnect|ok|macaco',
              resource => 'macaco',
             },

             # max length resource
             {
              line => "Jan 31 15:57:24 ubuntu202 smbd_audit: macaco|192.168.100.113|open|ok|w|$resourceWithMaxLength",
              resource => $resourceWithMaxLength,
             },

             # max+n length resource
             {
              line => "Jan 31 15:57:24 ubuntu202 smbd_audit: macaco|192.168.100.113|open|ok|w|$resourceOverflowLength",
              resource => $abbrvResourceOverflowLength,
             },
            );


my $dbEngine = Test::MockObject->new();
$dbEngine->mock('clean',
                sub {
                 my ($self) = @_;
                 delete  $self->{insert};
                }
               );
$dbEngine->mock('insert',
                sub {
                 my ($self, $table, $line) = @_;
                 $self->{insert} = $line;
                }
               );
$dbEngine->mock('lastInsert',
                sub {
                 my ($self) = @_;
                 return $self->{insert};
                }
               );


foreach my $case (@cases) {
    my $file = $case->{file};
    defined $file or
        $file = '/var/log/syslog';
    
    $dbEngine->clean();
    $logHelper->processLine($file, $case->{line}, $dbEngine);

    my $lastInsert = $dbEngine->lastInsert();

    my $inserted = $case->{inserted};
    defined $inserted or
        $inserted = 1;

    if ($inserted) {
        ok $lastInsert, 'Record inserted';
    } else {
        my $notInserted = not $lastInsert;
        ok $notInserted, 'Record should NOT be inserted';        
    }

    if (exists $case->{resource}) {
        is $lastInsert->{resource}, $case->{resource}, 'checking resource field';
    }
    
}

1;
