use Socket;

sub snd {
  my ($text) = @_;
  chomp ($text);
  $text = $text . $nl;
  if ($verbose eq "on") { print "SEND: $text" }
  send (SOCK,$text,0);
  return;
}

sub sndtxt {
  my ($i) = 0;
  my ($txt) = @_;
  my ($ch) = 0;
  if ($verbose eq "medium") {
    print "<${botname}> $txt\n";
  }
}


print "Connecting to server...   ";
$remote = $server;
$port = $serverport;
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

snd ("USER $botname $botemail $botname :SpartaX");


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

if ($line =~ /^PING :/) {
  $lastpong = time();
  snd ("PONG :" . substr($line,index($line,":")+1));

if ($command eq 'PRIVMSG') {
	
	
if (lc($mtext) eq "stats") {
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
