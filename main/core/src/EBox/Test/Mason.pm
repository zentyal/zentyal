# Copyright (C) 2006-2007 Warp Networks S.L.
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

package EBox::Test::Mason;

# package: EBox::Test::Mason
#  to ease the testing of mason components. This does NOT test all the content (use HTML::Maason::Test for this) but only checks if compiles.
#  You can revise the output files by eye after running the tests
#
# This currently depends from exec-mason-template tool

use Data::Dumper;
use File::Slurp;
use File::Basename;
use HTML::Mason;
use Test::More;
use TryCatch;
use Dir::Self;
use Cwd 'abs_path';

sub checkTemplateExecution
{
    my %args = @_;
    my $template       = $args{template};
    my $templateParams = exists $args{templateParams} ? $args{templateParams} : [];
    my $compRoot      =  exists $args{compRoot}       ? $args{compRoot} : [];
    ref $compRoot or $compRoot = [ $compRoot ];

    my $paramsAsText =  @{$templateParams};
    my $testName       = exists $args{name} ? $args{name} : "Testing if execution of template $template with params $paramsAsText was successful";
    my $printOutput    = $args{printOutput};
    my $outputFile     = exists $args{outputFile} ? $args{outputFile} : '/tmp/' . basename($template);

    my $templateOutput;
    my $templateError;

    my $templateExecutionOk = 0;
    try {
        $templateOutput = executeTemplate(template => $template, templateParams => $templateParams, compRoot => $compRoot);
        $templateExecutionOk = 1;
    } catch ($e) {
        $templateError = "$e";
        $templateOutput = \$templateError; # templateOutput must be a scalar ref to be in the same form that the return value of executeTemplate
    }

    ok $templateExecutionOk, $testName;

    if ($printOutput || $templateError) {
        diag "Template $template with parameters @$templateParams output:\n$$templateOutput\n";
    }
    if ($outputFile) {
        _printOutputFile($outputFile, $templateOutput);
    }

    return $templateExecutionOk;
}

sub executeTemplate
{
    my %args = @_;
    my $template        = $args{template};
    my @params          = exists $args{templateParams} ?  @{ $args{templateParams} } : ();
    my $additionalRoots = exists $args{compRoot}       ?  $args{compRoot}            : [];

    my $comp_root = _comp_root($additionalRoots);
    my $templateOutput;

    my $interp = HTML::Mason::Interp->new(comp_root => $comp_root, out_method => \$templateOutput);
    my $comp = $interp->make_component(comp_file => $template);

    $interp->exec($comp, @params);

    return \$templateOutput;
}

sub testComponent
{
    my ($component, $cases_r, %params) = @_;
    my $printOutput = $params{printOutput};
    my $compRoot = $params{compRoot};

    my ($componentWoExt) = split '\.', (basename $component);
    my $outputFile  = "/tmp/$componentWoExt.html";
    system "rm -rf $outputFile";

    foreach my $params (@{ $cases_r }) {
        my @caseParams = (template => $component, templateParams => $params, printOutput => $printOutput, outputFile => $outputFile);
        push @caseParams, (compRoot => $compRoot) if $compRoot;
        EBox::Test::Mason::checkTemplateExecution(@caseParams);
    }
}

sub _comp_root
{
    my ($root_paths_r) = @_;
    my @root_paths = @{ $root_paths_r } ;

    my $i = 0; # counter to generate comp_root ids
    my @roots = map {
        my $dir = abs_path($_);
        $i++;
        [ "user-$i" => $dir ]
    } @root_paths;

    return \@roots;
}

sub _printOutputFile
{
    my ($outputFile, $data) = @_;
    my $separator;

    if ($outputFile =~ m/\.html?$/) {
        $separator = '<hr/>';
    }
    else {
        $separator = "---------------\n";
    }

    write_file($outputFile, { append => 1}, $separator );
    write_file($outputFile, {append =>  1 }, $data );
}

1;
