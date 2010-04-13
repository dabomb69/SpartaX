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

use Socket;
use POSIX ":sys_wait_h";
use MIME::Base64;

#Wee, lines 26 - 75 are just telling Perl what to do if we get a SIGINT or SIGHUP or something like that. :p
sub REAPER {
  my $waitedpid;
  $waitedpid = wait;
  # loathe sysV: it makes us not only reinstate
  # the handler, but place it after the wait
  $SIG{CHLD} = \&REAPER;
}

sub INT_handler {
    print("\nSpartaX: caught SIGINT, dying\n");
    snd("QUIT :Ack! SIGINT!!");
    sleep 1;
    &Cleanup;
    exit;
}

sub KILL_handler {
    print("\nSpartaX: caught SIGKILL, dying\n");
    snd("QUIT :Caught a SIGKILL");
    sleep 1;
    &Cleanup;
    exit;
}

sub HUP_handler {
  print "SpartaX: Caught a SIGHUP, becoming a semi daemon.\n";
	open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
	open STDOUT, '>/dev/null' or die "Can't write to /dev/null: $!";
	open STDERR, '>&STDOUT'	or die "Can't dup stdout: $!";
}

sub PWR_handler {
  snd ("QUIT :Hmm, my UPS claims the power is failing. I'm gonna go hide.");
  open (NOSPAWN, ">${win321}nospawn");
  print NOSPAWN "powerfail";
  close (NOSPAWN);
  sleep 1;
  &Cleanup;
  exit;
}

$SIG{PWR} = \&PWR_handler;
$SIG{INT} = \&INT_handler;
$SIG{KILL} = \&KILL_handler;
$SIG{TERM} = \&KILL_handler;
$SIG{ALRM} = \&ALARM_handler;
$SIG{CHLD} = \&REAPER;
$SIG{HUP} = \&HUP_handler;

#Wee, establishing Terminal colors. :p
if (lc($^O) eq 'mswin32') {
  $win321 = '';
  $mfail = "[FAILED]";
  $mok =   "[  OK  ]";
} else {
  $win321 = './';
  $mfail = "[[31mFAILED[0m]";
  $mok =   "[  [32mOK[0m  ]";
}

sub snd {
  my ($text) = @_;
  chomp ($text);
  $text = $text . $nl;
  print "SEND: $text";
  send (SOCK,$text,0);
  return;
}

sub sndtxt {
  my ($i) = 0;
  my ($txt) = @_;
  my ($ch) = 0;
  print "<${botname}> $txt\n";
  snd("NOTICE $channel :$txt");
}

sub Cleanup {
#What to do when the bot goes kersplat and needs to close.
  close (SASLOG); #SASL Log
  close (CONNLOG);# Connection Log
  close (CHATLOG);#Chat log
  close (STATUS);#Close status log
  close (SOCK);#Connection to IRC
}

sub logline {
	my($logfile, $log)=@_;
	print $logfile time() . " $log\n";
}

print "Reading config...	\n";
do "./bot.conf";
print "Opening log files...		\n";
open (CHATLOG, ">>\.\/logs\/$botname.log") or die "$mfail can't output to logfile: $!\n";#Open the chatlog
open (CONNLOG, ">>\.\/logs\/connection.log") or die "$mfail can't output to logfile: $!\n";#Open the Connection log
open (SASLOG, ">>\.\/logs\/sasl.log") or die "$mfail can't output to logfile: $!\n";#Open the SASL log
open (STATUS, ">>\.\/logs\/status.log") or die "$mfail can't output to logfile: $!\n";#Open the SASL log

print "Connecting to server...   \n";
if ($srv) {
	  use Net::DNS;
  use Net::DNS::Resolver;
  use Net::DNS::RR;
  my $res   = Net::DNS::Resolver->new;
  my $query = $res->query("_irc._tcp.".$srvserv, "SRV");
  
  if ($query) {
      foreach $rr (grep { $_->type eq 'SRV' } $query->answer) {
           #print "priority = ", $rr->priority, "\n";
           #print "weight = ", $rr->weight, "\n";
           #print "port = ", $rr->port, "\n";
           #print "target = ", $rr->target, "\n";
		$port=$rr->port;
		$server=$rr->target;
      }
  }
  else {
     warn "query failed: ", $res->errorstring, "\n";
 }
logline('CONNLOG', "Using SRV records, connecting to $server on port $port");
}
$remote = $server; #<--Why did I need to do that?
$port = $serverport;#<--Same as above...?
print("Connecting to ".$remote.":".$port);
#Wee, time for some FUN socket crap! :p (Note, I should really clean this up to use IO::Socket or something...)
if ($port =~ /\D/) { $port = getservbyname($port, 'tcp') }
$iaddr = inet_aton($remote) or die "$mfail (invalid host: $remote)\n"; #Crap, that doesn't exist, WAT DO?
$paddr = sockaddr_in($port,$iaddr);
$proto = getprotobyname('tcp');
socket (SOCK,PF_INET,SOCK_STREAM,$proto) or die "$mfail (socket error: $!)\n"; #Crap, something broke our socket, WAT DO?
connect (SOCK, $paddr) or die "$mfail (connect error: $!)\n"; #Meh, something else is broke, DIIIIIE!
print "$mok (connected to ${server}:${serverport})\n"; #Oh... yay. We actually connected.

$nl = chr(13); #Ok, I've got no clue what this is for.
$nl = $nl . chr(10);#Same.

$msgto = $channel; #Who/what's stuff going to?

###############################
#SEND CAP LS (START SASL AUTH)#
###############################
snd("CAP LS");
snd ("NICK $botname");
snd ("USER $botname SpartaX SpartaX :SpartaX");

######################
#####################
####################
#START OF SOCKET READ LOOP
####################
#####################
######################


STARTOFLOOP: while ($line = <SOCK>) {
$lastmsgtime = time();
$line =~ s/\027-\036\004-\025\376\377//gi;

$silent = 0;  
$usermode = "";
undef $nickname;
undef $command;
undef $mtext;
undef $hostmask;

################
# EXTRACT VARS #
################
$hostmask = substr($line,index($line,":"));
$mtext = substr($line,index($line,":",index($line,":")+1)+1);
($hostmask, $command) = split(" ",substr($line,index($line,":")+1));
($nickname) = split("!",$hostmask);

@spacesplit = split(" ",$line);

$mtext =~ s/[\r|\n]//g;

  print "RAW : $line\n\n";
  print "TEXT: $mtext\n";
  print "MSG2: $msgto\n";
  print "NICK: $nickname ($hostmask)\n";
  print "CMND: $command\n";
  print "USER: $usermode\n\n";

#--------------------
#------SASL-CRAP!----
#--------------------
	
#:bartol.freenode.net CAP * LS :identify-msg multi-prefix sasl

	$tosend = '';
	if ($command eq 'CAP') { #Ok, now for some /fun/ crap. :D
	#Starting off, did the server send the command CAP? If so, read down.
		if ($line =~ / LS /) { #Did it do CAP LS or something similar?
			$tosend .= ' multi-prefix' if $line =~ /multi-prefix/i;
			$tosend .= ' sasl' if $line =~ /sasl/i; #Does it /support/ sasl?
			$tosend =~ s/^ //;
			logline("SASLOG", "CLICAP: supported by server:$mtext"); #Log report! <3
				if ($tosend eq '') {
					snd("CAP END");
				} else {
					logline('SASLOG', "CLICAP: requesting: $tosend");
					snd("CAP REQ :$tosend");
				}
		} elsif ($line =~ / ACK /) {
			logline('SASLOG', "CLICAP: now enabled:$mtext");
			if ($mtext =~ /sasl/i) {
				snd("AUTHENTICATE PLAIN");
			}
		} elsif ($line =~ / NAK /) {
			logline('SASLOG', "CLICAP: refused:$caps");

				snd("CAP END");
		} elsif ($line =~ / LIST /) {
			logline('SASLOG', "CLICAP: currently enabled:$mtext");
		}
	}
	
#OK, see ./docs/sasl.txt or something for more info, documenting this crap within the code will be a pita.
if (uc($line) =~ /AUTHENTICATE /) {
	logline('SASLOG', "AUTHENTICATE: Starting SASL Authentication");
	$u = $sasl_user;
	$p = $sasl_passwd;
	$out = join("\0", $u, $u, $p);
	$out = encode_base64($out, "");
	
		if(length $out == 0) {
		snd("AUTHENTICATE +");
		return;
	}else{
		while(length $out >= 400) {
			$subout = substr($out, 0, 400, '');
			snd("AUTHENTICATE $subout");
		}
		if(length $out) {
			snd("AUTHENTICATE $out");
		}else{ # Last piece was exactly 400 bytes, we have to send some padding to indicate we're done
			snd("AUTHENTICATE +");
		}
	}
}

if ($command eq 903) {
	logline('SASLOG', "SASL Authentication successful, connecting to IRC.");
	snd ("CAP END");

}

if ($command eq 904) {
	logline('SASLOG', "SASL Authentication failed, disconnecting from IRC.");
	snd("CAP END");
	snd("QUIT :SASL failed");
	&Cleanup;
	die;
}

if ($command eq '001') {
	logline('CONNLOG'. 'Joining channels - More info in status.log');
	foreach $channel (@channels) {
	snd("JOIN $channel");
	logline('STATUS', "Joining $channel");
	}
}

if ($command eq 'INVITE') {
	snd("JOIN $mtext");
	logline('STATUS', "Invited to $mtext by $nickname - Joining");
}

if ($command eq 473) {
	@tmp=split(/ /,$line);
	logline('STATUS', "Cannot join $tmp[3] - Invite only");
	logline('STATUS', "Attempting to send KNOCK to $tmp[3]");
	snd("KNOCK $tmp[3]");
	undef @tmp;
}

if ($line =~ /^PING :/) {
  $lastpong = time();
  snd ("PONG :" . substr($line,index($line,":")+1));

if ($command eq 'PRIVMSG') {
	
	
if (lc($mtext) eq "\?stats") {
  local $stats = "no stats available";
  foreach $_ (`ps u $$ | awk '{print "I am using "\$3"% of cpu and "\$4"% of mem I was started at "\$9" my pid is "\$2" i was run by "\$1}'`) {
    $stats = $_;
  }
  sndtxt($stats);
  next;
}
}

  foreach $iponly ( keys (%ignore )) {
    if (($ignore{$iponly} - time) <= 0) {
      delete $ignore{$iponly};
    }
  }
}
}
