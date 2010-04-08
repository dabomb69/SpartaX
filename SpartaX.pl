#!/usr/bin/perl
#
#       SpartaX.pl
#       
#       Copyright 2010 Chazz Wolcott <root@spartairc.org>
#       
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#       
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#       
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.

use strict;
use warnings;
use POE;
use POE::Component::IRC::State;
use POE::Component::IRC::Plugin::NickServID;

my $nickname = 'Karmic';
 my $ircname = 'Ubuntu Karmic Koala!';
 my $ircserver = 'irc.freenode.net';
 my $port = 6667;

 my @channels = ( '#botters', '#spartanix', '#dosh' );

 # We create a new PoCo-IRC object and component.
 my $irc = POE::Component::IRC::State->spawn( 
     nick => $nickname,
     server => $ircserver,
     port => $port,
     ircname => $ircname,
 ) or die "Oh noooo! $!";

 POE::Session->create(
     package_states => [
         main => [ qw(_default _start irc_001) ],
     ],
     heap => { irc => $irc },
 );

 $poe_kernel->run();

 sub _start {
     my ($kernel, $heap) = @_[KERNEL, HEAP];

     # We get the session ID of the component from the object
     # and register and connect to the specified server.
     my $irc_session = $heap->{irc}->session_id();
     $kernel->post( $irc_session => register => 'all' );
     #Add plugins
     $irc->plugin_add( 'NickServID', POE::Component::IRC::Plugin::NickServID->new(
     Password => 'kaboom666'
 ));
 #connect!
     $kernel->post( $irc_session => connect => { } );
     return;
 }

 sub irc_001 {
     my ($kernel, $sender) = @_[KERNEL, SENDER];

     # Get the component's object at any time by accessing the heap of
     # the SENDER
     my $poco_object = $sender->get_heap();
     print "Connected to ", $poco_object->server_name(), "\n";

     # In any irc_* events SENDER will be the PoCo-IRC session
     $kernel->post( $sender => join => $_ ) for @channels;
     return;
 }


 # We registered for all events, this will produce some debug info.
 sub _default {
     my ($event, $args) = @_[ARG0 .. $#_];
     my @output = ( "$event: " );

     for my $arg ( @$args ) {
         if (ref $arg  eq 'ARRAY') {
             push( @output, '[' . join(', ', @$arg ) . ']' );
         }
         else {
             push ( @output, "'$arg'" );
         }
     }
     print join ' ', @output, "\n";
     return 0;
 }
