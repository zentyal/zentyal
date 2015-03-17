#!/usr/bin/perl
# Copyright (C) 2014 Zentyal S.L.
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
# This a pure-raw PSGI application using Plack directly
# TODO: Use a proper web framework is a must here

no warnings 'experimental::smartmatch';
use feature qw(switch);
use EBox;
use EBox::HA::Server::Auth;
use EBox::HA::Server::Router;
use Hash::MultiValue;
use JSON::XS;
use Plack::Builder;
use Plack::Request;
use Plack::Response;

my $app = sub {
    my ($env) = @_;

    my $req = new Plack::Request($env);
    my $res = new Plack::Response();
    my $ret;
    my $pathInfo = $req->path_info();
    if (EBox::HA::Server::Router::routeExists($pathInfo)) {
        my ($routeConf, $namedPathParams) = EBox::HA::Server::Router::routeConf($pathInfo);
        if (exists($routeConf->{$req->method()})) {
            my $body;
            if (($req->content_type() ~~ 'application/json') and ($req->raw_body())) {
                $body = new JSON::XS()->decode($req->raw_body());
            }
            my $joinedParams = new Hash::MultiValue($req->parameters()->flatten(), %{$namedPathParams});
            $ret = EBox::HA::Server::Router::route($routeConf->{$req->method()},
                                                   $joinedParams,
                                                   $body,
                                                   $req->uploads());
            $res->status(200);
        } else {
            $res->status(405);
            $res->content_type('text/plain');
            $res->body('405 Method Not Allowed');
        }
    } else {
        $res->status(404);
        $res->content_type('text/plain');
        $res->body('404 Not Found');
    }
    if ($res->status() == 200) {
        if (defined($ret) and ref($ret)) {
            my $retJSON = JSON::XS->new()->encode($ret);
            $res->body($retJSON);
            $res->content_length(length($retJSON));
            $res->content_type('application/json');
        } else {
            # Simple scalar, then return it as it is
            $res->body($ret);
            $res->content_type('text/plain');
        }
    }
    return $res->finalize();
};

# Turn into ebox user
EBox::init();

builder {
    enable "Auth::Basic", authenticator => \&EBox::HA::Server::Auth::authenticate;
    $app;
};
