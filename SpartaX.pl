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
}

sub Cleanup {
  close (SASLOG);
  close (CONNLOG);
  close (CHATLOG);
  #dbmclose (%access);
  #dbmclose (%servers);
  #dbmclose (%ignore);
  #dbmclose (%seen);
  #dbmclose (%profiles);
  #dbmclose (%hosts);
  close (SOCK);
}

sub logline {
	my($logfile, $log)=@_;
	print $logfile time() . " $log\n";
}

print "Reading config...	\n";
do "./bot.conf";
print "Opening log files...		\n";
open (CHATLOG, ">>\.\/logs\/$botname.log") or die "$mfail can't output to logfile: $!\n";
open (CONNLOG, ">>\.\/logs\/connection.log") or die "$mfail can't output to logfile: $!\n";
open (SASLOG, ">>\.\/logs\/sasl.log") or die "$mfail can't output to logfile: $!\n";

print "Connecting to server...   \n";
#FAIL!
$remote = $server;
$port = $serverport;
print("Connecting to ".$remote.":".$port);
if ($port =~ /\D/) { $port = getservbyname($port, 'tcp') }
$iaddr = inet_aton($remote) or die "$mfail (invalid host: $remote)\n";
$paddr = sockaddr_in($port,$iaddr);
$proto = getprotobyname('tcp');
socket (SOCK,PF_INET,SOCK_STREAM,$proto) or die "$mfail (socket error: $!)\n";
connect (SOCK, $paddr) or die "$mfail (connect error: $!)\n";
print "$mok (connected to ${server}:${serverport})\n";

$nl = chr(13);
$nl = $nl . chr(10);

$lastpong = time();
$msgto = $channel;
snd("CAP LS");

snd ("USER $botname SpartaX SpartaX :SpartaX");

snd ("NICK $botname");


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
	if ($command eq 'CAP') {
		if ($line =~ / LS /) {
			$tosend .= ' multi-prefix' if $line =~ /multi-prefix/i;
			$tosend .= ' sasl' if $line =~ /sasl/i; # && defined($sasl_auth{$server->{tag}})
			$tosend =~ s/^ //;
			logline("SASLOG", "CLICAP: supported by server:$mtext");
				if ($tosend eq '') {
					snd("CAP END");
				} else {
					logline('SASLOG', "CLICAP: requesting: $tosend");
					snd("CAP REQ :$tosend");
				}
		} elsif ($line =~ / ACK /) {
			logline('SASLOG', "CLICAP: now enabled:$mtext");
			if ($mtext =~ / sasl /i) {
				snd("AUTHENTICATE PLAIN");
			}
		} elsif ($line =~ / NAK /) {
			logline('SASLOG', "CLICAP: refused:$caps");

				snd("CAP END");
		} elsif ($line =~ / LIST /) {
			logline('SASLOG', "CLICAP: currently enabled:$mtext");
		}
	}
	
if (uc($line) =~ /AUTHENTICATE /) {
	print("Ohai, duz this work?");
}


if ($command eq '001') {
	foreach $channel (@channels) {
		snd("JOIN $channel");
	}
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
