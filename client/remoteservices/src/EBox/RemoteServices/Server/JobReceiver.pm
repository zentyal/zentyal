#!/usr/bin/perl -w

# Copyright (C) 2008-2010 eBox Technologies S.L.
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

# Class: EBox::RemoteServices::Server::JobReceiver
#
#      This is a WS server to receive jobs from the control center to
#      dispatch to the runner daemon which must provide results in
#      some way
#

package EBox::RemoteServices::Server::JobReceiver;

use strict;
use warnings;

use base 'EBox::RemoteServices::Server::Base';

use EBox::Exceptions::MissingArgument;
use EBox::Config;

# Dependencies
use File::Slurp;
use Fcntl ':mode'; 
use File::Path;
use YAML::Tiny;

use constant JOBS_DIR     => EBox::Config::conf() . 'remoteservices/jobs/';
use constant INCOMING_DIR => JOBS_DIR . 'incoming/';

# Group: Public class methods

# Method: runJob
#
#     Control panel will send jobs to the Zentyal servers to be run in the
#     host. The request is completely asynchronous, therefore this WS
#     only ask to a daemon to run this job some time in the future. If there
#     is a job with the same identifier, new script and arguments are
#     overriden and the returned value is 1.
#
# Parameters:
#
#     jobId - Int the unique identifier for a job
#
#     script - String the script to be run in your favourite script language (perl, awk,
#              ruby, python, bash, tcl...)
#
#     arguments - String the arguments in a single string, an empty
#                 string means no arguments
#
#     - Named parameters
#
# Returns:
#
#     0 - in operation success
#     1 - if the jobId was already deployed
#
# Exceptions:
#
#      <EBox::Exceptions::MissingArgument> - thrown if any compulsory
#      argument is missing
#
sub runJob
{
    my $class = shift(@_);
    my ($jobId, $script, $arguments, $dataFile) =
      @{$class->_gatherParams([ qw(jobId script arguments dataFile) ], @_)};

    my $retValue = _addJob($jobId, $script, $arguments, $dataFile, 0);
    return $class->_soapResult($retValue);

}


sub runInternalJob
{
    my ($class, $jobId, $script, $arguments, $dataFile) = @_;
    my $retValue = _addJob($jobId, $script, $arguments, $dataFile, 1);
    return $retValue    
}


sub _addJob
{
    my ($jobId, $script, $arguments, $dataFile, $internal) = @_;


    unless (defined($jobId)) {
        throw EBox::Exceptions::MissingArgument('jobId');
    }
    unless (defined($script)) {
        throw EBox::Exceptions::MissingArgument('script');
    }
    unless (defined($arguments)) {
        throw EBox::Exceptions::MissingArgument('arguments');
    }

    # TODO: Implement a better way to communicate
    unless ( -d JOBS_DIR ) {
        mkdir(JOBS_DIR);
    }
    unless ( -d INCOMING_DIR ) {
        mkdir(INCOMING_DIR);
    }

    my $jobDirPath = JOBS_DIR . "$jobId/";
    my $retValue = 0;
    if ( -d $jobDirPath ) {
        $retValue = 1;
    } else {
        mkdir($jobDirPath);
    }
    # Dump the script and set as executable
    File::Slurp::write_file( "$jobDirPath/script", $script);
    chmod(0700, "$jobDirPath/script");
    # write the arguments file
    File::Slurp::write_file( "$jobDirPath/args", $arguments);
    # Dump the data file if is supplied, if otherwise create the noDataFile
    # file as mark
    if ($dataFile) {
        File::Slurp::write_file( "$jobDirPath/dataFile", $dataFile);
    } else {
        File::Slurp::write_file( "$jobDirPath/noDataFile", '');
    }


    if ($internal) {
        # add the internal file to signal its status
        File::Slurp::write_file( "$jobDirPath/internal", '');    
    }


    # Create the symlink to incoming directory to make it notify to
    # the ebox-runnerd
    symlink( $jobDirPath, INCOMING_DIR . $jobId);



    return $retValue;
}

# XXX todo change _addJobs so addCronJobs could use it
# XXX make starting hour for first time execution choosable  (via lastTimestamp ?)
sub addCronJobs
{
    my ($class, $cronJobs) = @_;

    foreach my $cronJob (@{$cronJobs}) {
        my $jobId    = $cronJob->{jobId};
        my $dirName  = EBox::RemoteServices::Configuration::CronJobPrefix() . $jobId;
        my $dirPath  = EBox::RemoteServices::Configuration::JobsDir() . $dirName;

        # Write down the YAML cron job metadata file
        my $yaml;
        if ( -d $dirPath and -f "$dirPath/conf.yaml") {
            $yaml = YAML::Tiny->read("$dirPath/conf.yaml");
        } else {
            unless ( -d $dirPath ) {
                File::Path::mkpath($dirPath);
            }
            $yaml = new YAML::Tiny();
            $yaml->[0]->{lastTimestamp} = 0;
        }

        $yaml->[0]->{period} = $cronJob->{period};



        $yaml->[0]->{fromControlCenter} = exists $cronJob->{fromControlCenter} ?
                                                 $cronJob->{fromControlCenter} :
                                                 1  ;
        $yaml->write("$dirPath/conf.yaml");

        if (exists $cronJob->{internal} and $cronJob->{internal}) {
            # add internal file flag
            File::Slurp::write_file( "$dirPath/internal", '');   
        }


        # Write down the script
        File::Slurp::write_file( "$dirPath/script", $cronJob->{script});
        # Make the script executable to everyone
        my $perm = (stat("$dirPath/script"))[2];
        chmod($perm | S_IXUSR | S_IXGRP | S_IXOTH , "$dirPath/script");
        # No arguments yet
        File::Slurp::write_file( "$dirPath/args",  '');
    }

}

sub removeJob
{
    my ($id) = @_;

    my $incomingDirLink = EBox::RemoteServices::Configuration::IncomingJobDir() . $id;
    if (-e $incomingDirLink) {
        unlink $incomingDirLink;
    }

    my $outcomingDirLink = EBox::RemoteServices::Configuration::OutcomingJobDir() . $id;
    if (-e $outcomingDirLink) {
        unlink $outcomingDirLink;
    }

    my $dirPath  = EBox::RemoteServices::Configuration::JobsDir() . $id;
    system "rm -rf $dirPath";
}


# Method: URI
#
# Overrides:
#
#      <EBox::RemoteServices::Server::Base>
#
sub URI {
    return 'urn:EBox/Services/Jobs';
}

# Group: Private class methods

1;
