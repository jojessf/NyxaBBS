#!/usr/bin/perl
# --------------------------------------------------------------------------- #
# Jojess Fournier 20240614
# --------------------------------------------------------------------------- #
package Net::BBS::Nyxa;
# --------------------------------------------------------------------------- #
use strict;
use Storable qw(dclone);
use JSON;
use Data::Dumper;
use Text::Convert::PETSCII qw/:all/; # https://metacpan.org/pod/Text::Convert::PETSCII
use File::Path qw(make_path);
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
sub new {
   my $class = shift;
   my $server_socket = shift;
   my $serverparm = shift;
   my $self = {
      class           => $class,
      server_socket   => $server_socket,
      ServerParms     => $serverparm,
      threads         => {},
      threadq         => 0,
      json            => JSON->new->allow_nonref,
      
      list_lim        => 8,
      list_showdate   => 1,
      
      
      PETSCII2ASCII    => $Net::BBS::Nyxa::CharTable::PETSCII2ASCII,
      ASCII2PETSCII    => $Net::BBS::Nyxa::CharTable::ASCII2PETSCII,
      C64ColorByName   => $Net::BBS::Nyxa::CharTable::C64ColorByName,
      
      UserParmDefault => {
         'user' => undef,
         'pass' => undef,
         'port' => undef,
         'ip'   => undef,
         'loggedin' => 0,
         'PETSCII' => 0, # $user_conf{PETSCII}
      },
   };
   bless($self, $class);

   # init dirs 
   mkdir $self->{ServerParms}->{confdir} if ! -d $self->{ServerParms}->{confdir};
   die "$class FATAL no confdir ".$self->{ServerParms}->{confdir}." \@"   . __LINE__ if ! -d $self->{ServerParms}->{confdir};
   
   mkdir $self->{ServerParms}->{logdir} if ! -d $self->{ServerParms}->{logdir};
   die "$class FATAL no logdir  ".$self->{ServerParms}->{logdir}." \@" . __LINE__ if ! -d $self->{ServerParms}->{logdir};
         
   # init vars 
   
   $self->{bbs}->{postq} //= 0;
   my $test_postq = $self->getconf("bbs/postq");
   if ( $test_postq == 0 ) {
      $self->saveconf("bbs/postq", {postq=> $self->{bbs}->{postq} });
   } else {
      $self->{bbs}->{postq} = $test_postq;
   }
   
   # BBS Stats =====================================================
   my $postq = $self->getconf("bbs/postq")->{postq};
   $self->{bbs}->{postq} = $postq;
   
   # lastmsg [date] 
   if ( $postq > 1 ) {
      PQCHK: for (my $pq = $postq; $pq>=0; $pq--) {
         my $lastmsg = $self->getconf("msg/".$self->postqfile($pq));
         if ( $lastmsg ne 0 ) {
            $self->{bbs}->{lastmsg} = $lastmsg->{date};
            last PQCHK;
         }
      }
   }
   
   return $self;
};

sub quit {
   my $self = shift;
   my $user_conf = shift;
      $user_conf->{quit} = 1;
   return;
}

sub sendbbs {
   my $self       = shift;
   my $user_conf  = shift;
   my $msg        = shift;
   my $sock       = $user_conf->{sock};
   $msg =~ s/\n//g if $user_conf->{PETSCII};
   # ---------------------- #
   $msg = ascii_to_petscii($msg) if $user_conf->{PETSCII};
   
   if ( $user_conf->{PETSCII} )   { $msg = $self->colorcodes($msg) };
   if ( ! $user_conf->{PETSCII} ) { $msg = $self->scrubcodes($msg) };
   
   print "PCX>>$msg<<\n" if $ENV{DEBUG} eq 'sendbbs';
   
   $sock->send($msg);
   # ---------------------- #
   return 1;
}

sub sendbbs {
   my $self       = shift;
   my $user_conf  = shift;
   my $msg        = shift;
   my $sock       = $user_conf->{sock};
   $msg =~ s/\n//g if $user_conf->{PETSCII};
   # ---------------------- #
   $msg = ascii_to_petscii($msg) if $user_conf->{PETSCII};
   
   if ( $user_conf->{PETSCII} )   { $msg = $self->colorcodes($msg) };
   if ( ! $user_conf->{PETSCII} ) { $msg = $self->scrubcodes($msg) };
   
   print "PCX>>$msg<<\n" if $ENV{DEBUG} eq 'sendbbs';
   
   $sock->send($msg);
   # ---------------------- #
   return 1;
}


sub postqfile {
   my $self = shift;
   my $postq = shift;
   return sprintf("%07d", $postq);
}

sub debug {
   my $self  = shift;
   my $lvl   = shift;
   my $msg   = shift;
      $lvl //= "debug";
   if ( $lvl eq 'serv' ) {
      print $msg . "\n";
   } elsif ( $lvl =~ /[a-zA-Z]/ ) {
      print $msg . "\n" if $ENV{DEBUG} eq $lvl; 
   } else {
      print $msg . "\n" if $ENV{DEBUG} >= $lvl; 
   }
   
   if ( ! -d $self->{ServerParms}->{debugdir} ) {
      mkdir($self->{ServerParms}->{debugdir}) or die "can't mkdir" . __LINE__ . "\n";
   }
   open DLOG, ">>" . $self->{ServerParms}->{debugdir}."/".$lvl.".".$self->{threadq}.".log";
   print DLOG $msg . "\n";
   close DLOG;
   return;
}

sub getconf {
   my $self  = shift;
   my $file  = shift;
   my $gopt  = shift;
   my $hash  = {};
   my $filepath = $self->{ServerParms}->{confdir} . "/" . $file;

   if ( ! -e $filepath ) {
      $self->debug("conf", "getconf - $filepath - failed");
      return 0;
   }
   
   $self->debug("conf", "getconf - $filepath");
   
   my $slurp;
   open IF, "<", $filepath or $self->debug("serv", "getconf - $filepath - failed spectacularly");
   while(<IF>) {$slurp .= $_}
   close IF;
   
   $hash = $self->{json}->decode( $slurp );
   
   $self->debug("conf", "getconf - OK - $slurp");
   
   select(undef,undef,undef,0.05);
   return $hash;
} # getconf

sub saveconf {
   my $self  = shift;
   my $file  = shift;
   my $hash  = shift;
   my $opt   = shift; 
   my $filepath = $self->{ServerParms}->{confdir} . "/" . $file;
   my $testpath = $filepath;
      $testpath =~ s/^(.*)\/.*/$1/;

   $self->debug("conf", "saveconf - $filepath");

   make_path($testpath) if ! -d $testpath;
   die $self->{class} . "ERROR - can't make_path $testpath" if ! -d $testpath;
      
   my $jsonstr = $self->{json}->pretty->encode( $hash );
   if ( -e $filepath ) { return 0; } 
   
   open OF, ">", $filepath;
   print OF $jsonstr;
   close OF;
   
   select(undef,undef,undef,0.05);
   return 1;
} # saveconf

sub msg_put {
   my $self      = shift;
   my $user_conf = shift;
   my $post      = shift;
   my $putopt    = shift;
      $putopt->{draft} //= 0;
      $putopt->{postq} //= $self->{bbs}->{postq};
      
   my $postq   = $putopt->{postq};
      $postq //= $self->{bbs}->{postq};
   my $date    = localtime;
   my $msg = {
      msg   => $post,
      user  => $user_conf->{user},
      date  => $date,
   };
   
   foreach my $key (sort keys %{$putopt}) { # see: subject, draft 
      $msg->{$key} = $putopt->{$key};
   }
   
   my $fi      = $self->postqfile($postq);
   my $write = 0;
   while ( ! $write ) {
      $postq++;
      $self->saveconf("bbs/postq", {postq=>$postq});
      $self->{bbs}->{postq} = $postq;
      $msg->{postq}         = $postq;
      $fi    = $self->postqfile($postq);
      $write = $self->saveconf("msg/$fi", $msg, {noclobber=>1});
   }
   
   $self->{bbs}->{lastmsg} = $date;   
   return 1;
}

sub msg_get {
   my $self      = shift;
   my $user_conf = shift;
   my $msgno     = shift;
   my $mopt      = shift;
   $msgno = sprintf("%07d", $msgno);
   return $self->getconf("msg/$msgno", $mopt);
}

sub sleep {
   my $self  = shift;
   my $sleep = shift;
   select(undef,undef,undef,$sleep);
   return;
} # sleep

sub skipsplash {
   my $self = shift;
   $self->{skipsplash}++;
   return;
} # skipsplash

sub colorcodes {
   my $self = shift;
   my $msg = shift;
   foreach my $key ( keys %{ $self->{C64ColorByName} } ) {
      my $val = $self->{C64ColorByName}->{$key};
      $msg =~ s/\@pcx{$key}/$val/g; # must be lc here!
   }
   return $msg;
} # colorcodes

sub scrubcodes {
   my $self = shift;
   my $msg = shift;
   $msg =~ s/\@PCX{[a-zA-Z]+?}//g; # must be caps here! 
   return $msg;
} # scrubcodes

sub ascii2hexr{shift;my$m;foreach my$c(split//,shift){$m.=uc unpack"H*",$c;$m.=" "};return$m}
sub ascii2hex {shift; return uc(unpack("H*", +shift))}
sub ascii2hexl{shift;my $l=shift;return if length($l)>1;return uc(unpack("H*", $l))}

sub petscii2asciil {
   my $self = shift;
   return $self->{PETSCII2ASCII}->{ +shift };
}

sub ascii2petscii {
   my $self = shift;
   return $self->{ASCII2PETSCII}->{ +shift };
}

# --------------------------------------------------------------------------- #
# --------------------------------------------------------------------------- #
sub listen {
   my $self = shift;
   CONNECTION: while(1) {

      next CONNECTION unless my $sock = $self->{server_socket}->accept();
      
      $sock->send("[ [ [ [ nyxabbs queue ] ] ] ]\r\n");
      
      my $pid = fork();
      die "cannot fork $!" unless defined($pid);
      
      if ( $pid == 0 ) {
         $pid = $$;
         
         my $user_data;
         my %user_conf       = %{dclone $self->{UserParmDefault}};
            $user_conf{ip}   = $sock->peerhost();
            $user_conf{port} = $sock->peerport();
            $user_conf{sock} = $sock;

         $self->{threadq}++;
         $self->{threadopenq}++;

         $self->{threads}->{ $pid }->{sock}      = $sock;
         $self->{threads}->{ $pid }->{user_conf} = dclone $self->{UserParmDefault};
         $self->{threads}->{ $pid }->{user_conf}->{ip}   = $sock->peerhost();
         $self->{threads}->{ $pid }->{user_conf}->{port} = $sock->peerport();
         $self->{threads}->{ $pid }->{user_conf}->{sock} = $sock;
         $self->{threads}->{ $pid }->{user_conf}->{tid}  = $pid;
         
         $self->menu_zero($pid);
         return; # we never wanna recover from here uwu
      }

      $self->sleep(0.05); # sleep for 50ms between new sockets
   }
   return;
} # listen
# --------------------------------------------------------------------------- #

sub prompt {
   my $self       = shift;
   my $user_conf  = shift;
   my $msg        = shift;
   my $prompt_opt = shift;
   my $sock       = $user_conf->{sock};
   
   my $userinput;
   $self->sendbbs($user_conf, $msg);
   
   my $user_data;
   my ($charq, $charlim) = (1,2048);
   
   $charlim = $prompt_opt->{charlim} if $prompt_opt->{charlim};
   
   PromptCharIn: until ( $user_data =~ m/[\r\n]/ ) {
      $sock->recv( $user_data, 8 );
      
      if ( ($user_conf->{PETSCII}) && ( $prompt_opt->{noecho} == 2) ) {
         $self->sendbbs($user_conf, "*");
      }
      if ( ($user_conf->{PETSCII}) && ( ! $prompt_opt->{noecho} ) ) {
         $self->sendbbs($user_conf, $user_data);
      }
      
      $userinput .= $user_data;
      $charq++;
      last PromptCharIn if $charq>=$charlim;
   }
   
   $userinput =~ s/[\r\n]$//g;
   $userinput = lc($userinput);
   $self->sendbbs($user_conf, "\r\n");
   return $userinput;
} # prompt
# --------------------------------------------------------------------------- #
sub menu_zero {
   my $self        = shift;
   my $tid         = shift;
   my $sock        = $self->{threads}->{ $tid }->{sock};
   my $thread      = $self->{threads}->{ $tid }->{thread};
   
   my $user_conf   = $self->{threads}->{ $tid }->{user_conf};
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;
   
   my $response = "CONNECTED: ".$user_conf->{ip}." : ".$user_conf->{port}.". \r\n";
      print "$response" if $ServerParms{verbose} >= 1;
      $response .= "[c]64 to enable PETSCII\r\n";
      $response .= " ... ENTER/RETURN to continue\r\n";
   # $response .= "[q]uit [l]ogin [s]tats\n";
   $self->sendbbs($user_conf, $response);
   # --------------------------------------------------------------------------- #
   # Net::BBS::Nyxa::PRE
   # --------------------------------------------------------------------------- #
   ZEROCON: while ($sock->connected()) {
      $sock->recv( $user_data,  1024 );
      # ----------------------------- #
      my $res; 
      if ( $user_data =~ /^(c|c64)[\r\n]*$/i ) {
         $res = "Enabling PETSCII...!\r\n";
         $user_conf->{PETSCII} = 1;
      } elsif ( $user_data =~ /^.*[\r\n]*$/i ) {
         $res = "No PETSCII - You should try with a C64, though!";
         $user_conf->{PETSCII} = 0;
      }   
      $self->sendbbs($user_conf, $res . "\r\n");
      
      if ( $ENV{DEBUG_POST} == 1 ) { # userless posting danger 
         $user_conf->{user} //= "Debug - $tid";
         $self->debug("serv", "WARNING - userless DEBUG_POST menu mode");
         $self->skipsplash;
         $self->menu_post($user_conf, $tid); # test post menu w/o login
         $self->skipsplash;
         $self->menu_bbs($user_conf, $tid);
      } elsif ( $ENV{DEBUG_BBS} ) {
         $user_conf->{user} //= "Debug - $tid";
         $self->debug("serv", "WARNING - userless DEBUG_BBS menu mode");
         $self->skipsplash;
         $self->menu_bbs($user_conf, $tid);
         $self->skipsplash;
      } else {
         $self->menu_main($user_conf, $tid);
      }
      
      last ZEROCON;
   } # Net::BBS::Nyxa::PRE / while connected
   
   return;
} # menu_zero

# --------------------------------------------------------------------------- #

sub menu_register {
   my $self = shift;
   my %user_conf   = %{ +shift };
   my $tid         = shift;
   my $sock        = $self->{threads}->{ $tid }->{sock};
   my $thread      = $self->{threads}->{ $tid }->{thread};
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;
   
   $self->sendbbs(\%user_conf, "OwO * REGISTRATION TIME * OwO\r\n");
   $self->sendbbs(\%user_conf, "Who are you tho?\r\n"),
   
   my $username = $self->prompt(\%user_conf, "username     : ", {charlim=>24});
   if ( $self->getconf("user/$username") ) {
      $self->sendbbs(\%user_conf, "Invalid user: ".$username."\r\n");
      return \%user_conf;
   }
   
   my $password = $self->prompt(\%user_conf, "password     : ", {charlim=>24,noecho=>1});
   if ( length($password) < 4 ) {
      $self->sendbbs(\%user_conf, "Invalid password, maybe too short?  Try again, please.  QwQ\r\n");
      return \%user_conf;
   }
   
   my $pass2    = $self->prompt(\%user_conf, "confirm pass : ", {charlim=>24,noecho=>1});
   if ( $password ne $pass2 ) {
      $self->sendbbs(\%user_conf, "Password mismatch\r\n");
      return \%user_conf;
   }
   
   $self->sendbbs(\%user_conf, "Optional stuff:\r\n");
   my $user_file = {
         "user"      => $username,
         "pass"      => $password,
         "computer"  => $self->prompt(\%user_conf, "computer     : ", {charlim=>32}),
         "fullname"  => $self->prompt(\%user_conf, "full name    : ", {charlim=>32}),
         "email"     => $self->prompt(\%user_conf, " email       : ", {charlim=>48}),
         "phone"     => $self->prompt(\%user_conf, " phone       : ", {charlim=>48}),
         "add1"      => $self->prompt(\%user_conf, "address 1    : ", {charlim=>48}),
         "add2"      => $self->prompt(\%user_conf, "address 2    : ", {charlim=>48}),
         "city"      => $self->prompt(\%user_conf, " city        : ", {charlim=>48}),
         "state"     => $self->prompt(\%user_conf, " state       : ", {charlim=>32}),
         "zip"       => $self->prompt(\%user_conf, " postcode    : ", {charlim=>12}),
         "country"   => $self->prompt(\%user_conf, " country     : ", {charlim=>48}),
   };
   # my $confirmstr = Dumper([$user_file]);
   # $confirmstr =~ s/^\$VAR1.=.//;
   # $confirmstr =~ s/\n/\r\n/g;
   # $self->sendbbs(\%user_conf, "Confirm:" . $confirmstr . "\r\n");
   
   if ( $self->getconf("user/".$user_file->{user}) ) {
      $self->sendbbs(\%user_conf, "Invalid user: ".$user_file->{user}."\r\n");
      return \%user_conf;
   }
   
   foreach my $field ( "user", "pass", "computer","fullname","email", "phone", "add1", "add2", "city", "state", "zip", "country" ) {
      $user_file->{$field} = $user_file->{$field};
      $self->sendbbs(\%user_conf, " $field :".$user_file->{$field}."\r\n");
   }
   my $okay = $self->prompt(\%user_conf, "Everything lookin' good? ([Y|N]) : ", {charlim=>4});

   if ( $okay =~ /y|yes|ja|hai|si/i ) {
      $self->sendbbs(\%user_conf, "Saving user: ".$user_file->{user}."\r\n");
      $self->saveconf("user/$username", $user_file);
   } else {
      $self->sendbbs(\%user_conf, "Aborting registration.\r\n");
   }

   return \%user_conf;
} # menu_register

sub menu_login {
   my $self = shift;
   my %user_conf   = %{ +shift };
   my $tid         = shift;
   my $sock        = $self->{threads}->{ $tid }->{sock};
   my $thread      = $self->{threads}->{ $tid }->{thread};
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;
   
   my $username = $self->prompt(\%user_conf, "username: ", {charlim=>24});
   my $password = $self->prompt(\%user_conf, "password: ", {charlim=>24,noecho=>1});
   
   return \%user_conf if $username !~ m/^[a-zA-Z0-9]{1,32}$/;
   return \%user_conf if $password !~ m/^[a-zA-Z0-9]{1,32}$/;
   
   my $userfile = $self->getconf("user/$username");
   
   if ( ( $userfile ) && ( $userfile->{pass} eq $password ) ) {
      $self->sendbbs(\%user_conf, "Welcome, $username! :3c\r\n");
      $user_conf{loggedin} = 1;
      UFK: foreach my $key ( keys %{$userfile} ) {
         next UFK if $key =~ m/^(ip|port|PETSCII|tid)$/;
         $user_conf{$key} = $userfile->{$key};
      }
      %user_conf = %{ $self->menu_bbs(\%user_conf, $tid) };
      return \%user_conf if $user_conf{quit};
   } else {
      $self->sendbbs(\%user_conf, "Failed to auth. =<\r\n");
      $sock->close() if $ServerParms{authfaildie};
   }
      
   return \%user_conf;
} # menu_login

sub menu_stats {
   my $self      = shift;
   my %user_conf = %{ +shift };
   my $tid = $user_conf{tid};
   $self->{bbs}->{BBSTAT} //= "\@PCX{PURPLE}" . "-" x 16 . "\@PCX{LIGHTGRAY}";
   $self->{bbs}->{laststat} = localtime;
   $self->sendbbs(\%user_conf, "\r\n");
   $user_conf{user}     //= "Guest - $tid";
   $user_conf{USERSTAT} ||= "\@PCX{PURPLE}" . "-" x 16 . "\@PCX{LIGHTGRAY}";
   UCKey: foreach my $key ("USERSTAT", "user", "pass", "ip", "port", "loggedin") {
      my $val   = $user_conf{$key};
      $val =~ s/./*/g if $key =~ /pass/;
      $self->sendbbs(\%user_conf, "[ \@PCX{LIGHTGREEN}".sprintf("%-8s", $key)."\@PCX{LIGHTGRAY} ]\@PCX{CYAN} $val\@PCX{LIGHTGRAY}\r\n");
   }
   UCKey: foreach my $key (sort keys %user_conf) {
      next UCKey if $key =~ /^(sock|user|pass|ip|port|USERSTAT|add[12]|city|computer|country|state|zip|tid|loggedin)$/;
      my $val   = $user_conf{$key};
      next if (( ! defined($val) ) || ( $val eq '' ))  ;
      $self->sendbbs(\%user_conf, "[ \@PCX{GREEN}".sprintf("%-8s", $key)."\@PCX{LIGHTGRAY} ] \@PCX{CYAN}$val\@PCX{LIGHTGRAY}\r\n");
   }
   
   ServKey: foreach my $key ("BBSTAT", "postq", "lastmsg", "now") {
      my $val = $self->{bbs}->{$key};
      my $pkey = $key;
      next if (( ! defined($val) ) || ( $val eq '' ));
      $pkey =~ s/postq/msg count/;
      $self->sendbbs(\%user_conf, "[ \@PCX{LIGHTGREEN}".sprintf("%-8s", $key)."\@PCX{LIGHTGRAY} ] \@PCX{CYAN}$val\@PCX{LIGHTGRAY}\r\n");
   }
   
   $self->sendbbs(\%user_conf, "\r\n \@PCX{LIGHTGREEN}The time is \@PCX{LIGHTBLUE}".localtime."\@PCX{LIGHTGRAY}\r\n");
   
   $self->sendbbs(\%user_conf, "\r\n");
   $self->skipsplash;
} # menu_stats
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
sub menu_main {
   my $self = shift;
   my %user_conf   = %{ +shift };
   my $tid         = shift;
   my $sock        = $self->{threads}->{ $tid }->{sock};
   my $thread      = $self->{threads}->{ $tid }->{thread};
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;

      # --------------------------------------------------------------------------- #
      if ( $user_conf{PETSCII} ) {
         foreach my $pc (split/\r/, $ServerParms{PETSCIISplash00}) {$sock->send($pc."\r");}
      } else {
         $self->sendbbs(\%user_conf, "NO PETSCII\r\n");
      }
      $self->sendbbs(\%user_conf, $ServerParms{menumsg_land});
      # --------------------------------------------------------------------------- #
      # Net::BBS::Nyxa::MAIN                                                        #
      # --------------------------------------------------------------------------- #
      # /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
      # --------------------------------------------------------------------------- #
      MMCON: while ($sock->connected()) {
         $sock->recv( $user_data,  1024 );

         # ----------------------------- #
         # [q]uit 
         # ----------------------------- #
         if ( $user_data =~ /^(q|quit|exit)[\r\n]*$/i ) {
            my $msg = "Disconnecting ".$user_conf{ip}." : ".$user_conf{port}."\r\n";
            print $msg if $ServerParms{verbose} >= 1;
            $self->sendbbs(\%user_conf, $msg);
            $sock->close();
            $self->quit(\%user_conf);
            return \%user_conf;
         } # quit 

         # ----------------------------- #
         # [l]ogin
         # ----------------------------- #
         if ( $user_data =~ /^(l|login)[\r\n]*$/i ) {
            %user_conf = %{ $self->menu_login(\%user_conf, $tid) };
            return \%user_conf if $user_conf{quit};
         }

         # ----------------------------- #
         # [r]egister
         # ----------------------------- #
         if ( $user_data =~ /^(r|register)[\r\n]*$/i ) {
            %user_conf = %{ $self->menu_register(\%user_conf, $tid) };
         }
         
         # ----------------------------- #
         # [s]tats 
         # ----------------------------- #
         if ( $user_data =~ /^(s|stats)[\r\n]*$/i ) {
            $self->menu_stats(\%user_conf);
         }

         # ----------------------------- #
         # REPRINT MAIN MENU
         # ----------------------------- #
         if ($user_data) {
            if ( $user_conf{PETSCII} ) {
               if ( $self->{skipsplash} ) {
                  $self->{skipsplash} = 0;
               } else {
                  foreach my $pc (split/\r/, $ServerParms{PETSCIISplash00}) {$sock->send($pc."\r");}
               }
            }
            $self->sendbbs(\%user_conf, $ServerParms{menumsg_land});
         }
         
      } # Net::BBS::Nyxa::MAIN / while connected 
      # --------------------------------------------------------------------------- #
      return \%user_conf;
} # menu_main

# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #

sub menu_bbs {
   my $self = shift;
   my %user_conf   = %{+shift};
   my $tid         = $user_conf{tid};
   my $sock        = $user_conf{sock};
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;
      
      $self->debug("sessionstart", Dumper([\%user_conf]));
      
      # --------------------------------------------------------------------------- #
      if ( $user_conf{PETSCII} ) {
         foreach my $pc (split/\r/, $ServerParms{PETSCIISplash00}) {$sock->send($pc."\r");}
      } else {
         $self->sendbbs(\%user_conf, "NO PETSCII\r\n");
      }
      $self->sendbbs(\%user_conf, $ServerParms{menumsg_bbs});
      # --------------------------------------------------------------------------- #
      # Net::BBS::Nyxa::BBS                                                         #
      # --------------------------------------------------------------------------- #
      # /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
      # --------------------------------------------------------------------------- #
      MMCON: while ($sock->connected()) {
         $sock->recv( $user_data,  1024 );

         # ----------------------------- #
         # [q]uit 
         # ----------------------------- #
         if ( $user_data =~ /^(q|quit|exit)[\r\n]*$/i ) {
            my $msg = "Disconnecting ".$user_conf{ip}." : ".$user_conf{port}."\r\n";
            print $msg if $ServerParms{verbose} >= 1;
            $self->sendbbs(\%user_conf, $msg);
            $sock->close();
            $self->quit(\%user_conf);
            last MMCON;
         } # quit 

         # ----------------------------- #
         # [debug]
         # ----------------------------- #
         if ( $user_data =~ /^(debug)[\r\n]*$/i ) {
            $self->debug("dump",Dumper([$self]));
            $self->sendbbs(\%user_conf, "Running DEBUG dump");
            $self->skipsplash;
         }

         # ----------------------------- #
         # [c]olortest
         # ----------------------------- #
         if ( $user_data =~ /^(c|colortest)[\r\n]*$/i ) {
            my $msg = "\r\n[c]olortest\r\n";
            $self->sendbbs(\%user_conf, $msg);
            
            $msg = "";
            $msg .= "\@PCX{RED}...\@PCX{CYAN}UWU\@PCX{LIGHTGRAY}OWO";
            $self->sendbbs(\%user_conf, $msg);
            
            $msg = "\r\n...\r\n\r\n";
            $self->sendbbs(\%user_conf, $msg);
            $self->skipsplash;
         }

         # ----------------------------- #
         # [l]ist
         # ----------------------------- #
         if ( $user_data =~ /^(l|list)[\r\n]*$/i ) {
            %user_conf = %{ $self->menu_list_byNum(\%user_conf, $tid) };
            $self->skipsplash;
         }

         
         # ----------------------------- #
         # [r]ead
         # ----------------------------- #
         if ( $user_data =~ /^(r|read)[\r\n]*$/i ) {
            %user_conf = %{ $self->menu_read_byNum(\%user_conf, $tid) };
            $self->skipsplash;
         }

         # ----------------------------- #
         # [p]ost
         # ----------------------------- #
         if ( $user_data =~ /^(p|post)[\r\n]*$/i ) {
            %user_conf = %{ $self->menu_post(\%user_conf, $tid) };
            $self->skipsplash;
         }
         
         # ----------------------------- #
         # [s]tats 
         # ----------------------------- #
         if ( $user_data =~ /^(s|stats)[\r\n]*$/i ) {
            $self->menu_stats(\%user_conf);
            $self->skipsplash;
         }

         # ----------------------------- #
         # REPRINT BBS MENU
         # ----------------------------- #
         if ($user_data) {
            if ( $user_conf{PETSCII} ) {
               if ( $self->{skipsplash} ) {
                  $self->{skipsplash} = 0;
               } else {
                  foreach my $pc (split/\r/, $ServerParms{PETSCIISplash00}) {$sock->send($pc."\r");}
               }
            }
            $self->sendbbs(\%user_conf, $ServerParms{menumsg_bbs});
         }
         
      } # Net::BBS::Nyxa::MAIN / while connected 
      # --------------------------------------------------------------------------- #
      return \%user_conf
} # menu_bbs

# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #

sub menu_post {
   my $self = shift;
   my %user_conf   = %{+shift};
   my $tid         = $user_conf{tid};
   my $sock        = $user_conf{sock};
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;
   
   $self->{bbs}->{postq}++;
   my $postq = $self->{bbs}->{postq};
   $self->saveconf("bbs/postq", {postq=>$self->{bbs}->{postq}});
   
   $self->debug("poststart", Dumper([\%user_conf]));
   
   $self->sendbbs(\%user_conf, "\@PCX{CYAN}What's on your mind, cutie? :3\@PCX{LIGHTGRAY}\r\n");
   
   my $subject = $self->prompt(\%user_conf, "msg subject  : ", {charlim=>24});
   
   
   if ( $user_conf{PETSCII} ) {
      my $L = "\x5c"; # quid
      # $self->sendbbs(\%user_conf, "\@PCX{RED}" . $L ."q\@PCX{LIGHTGRAY} to bail; \@PCX{GREEN}". $L ."s\@PCX{LIGHTGRAY} to save; \@PCX{ORANGE}". $L ."d\@PCX{LIGHTGRAY} to draft[wip]\r\n");
      $self->sendbbs(\%user_conf, "\@PCX{RED}" . $L ."q\@PCX{LIGHTGRAY} to bail; \@PCX{GREEN}". $L ."s\@PCX{LIGHTGRAY} to save; \@PCX{ORANGE}"."\r\n");
      # TODO - fix 
   } else {
      # $self->sendbbs(\%user_conf, "\@PCX{RED}\\q\@PCX{LIGHTGRAY} to bail; \@PCX{GREEN}\\s\@PCX{LIGHTGRAY} to save; \@PCX{ORANGE}/d\@PCX{LIGHTGRAY} to draft[wip]\r\n");
      $self->sendbbs(\%user_conf, "\@PCX{RED}\\q\@PCX{LIGHTGRAY} to bail; \@PCX{GREEN}\\s\@PCX{LIGHTGRAY} to save;\r\n");
   }
   
   my $post    = "";
   my $postop = undef;
   
   my $nilcount =0;
   PCON: while ($sock->connected()) {
      $sock->recv( $user_data,  1024 );
      
      $nilcount++ if $user_data eq '';
      return if $nilcount >= 32;  # leave or increase pls :3 20240619
      
      if ( $user_conf{PETSCII} ) {
         my $rawchar = $user_data;
         my $asciich = $self->petscii2asciil( $rawchar );
         $self->debug("CHAR", "$nilcount <".$asciich.">" . $self->ascii2hexl($asciich) ) if $rawchar;
         $sock->send($rawchar);
         $asciich = undef if $asciich eq '';     # if it doesn't match our table, nothing!  
         $post .= $asciich if defined($asciich); # ignore nil but not 0, which we want!
         chop($post) if $rawchar eq "\x14";
      } else {
         $post .= $user_data;
      }
      if ( $post =~ s/(.*)[\\£]q.{,5}$/$1/i ) { $postop = "q"; last PCON };
      if ( $post =~ s/(.*)[\\£]s.{,5}$/$1/i ) { $postop = "s"; last PCON };
      if ( $post =~ s/(.*)[\\£]d.{,5}$/$1/i ) { $postop = "d"; last PCON };
   
   } # CONNECTED 
   
   my $ch; 
   $ch = chop($post);
   $post .= $ch if $ch ne "\xC2";
   $ch = chop($post);
   $post .= $ch if $ch ne "\x20";
   
   
   my $draft = 0;
   if ( $postop =~ /[ds]/ ) {
      $draft = 1 if $postop eq 'd';
      $post =~ s/\s*(\r\n|\r|\n){3,}/\r\n\r\n/g; # limit to two consecutive line feeds
      
      $self->sendbbs(\%user_conf, "\r\n\r\n");
      $self->sendbbs(\%user_conf, "\@PCX{LIGHTGRAY}");
      # my $postq = $self->{bbs}->{postq};
      $self->msg_put(\%user_conf, $post, {draft=>$draft,subject=>$subject});
   }
   
   $self->sendbbs(\%user_conf, "\r\n\r\n");
   
   $self->debug("postend", Dumper([\%user_conf, $post]));
   return \%user_conf;
} # menu_post



sub menu_read_byNum {
   my $self = shift;
   my %user_conf   = %{+shift};
   my $tid         = $user_conf{tid};
   my $sock        = $user_conf{sock};
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;
      
   $self->sendbbs(\%user_conf, "\@PCX{LIGHTGRAY}Last msg : \@PCX{GREEN}".$self->{bbs}->{postq}."\@PCX{LIGHTGRAY}\r\n\r\n");  
   $self->sendbbs(\%user_conf, "\@PCX{CYAN}Enter message number\@PCX{LIGHTGRAY}\r\n");
   
   my $msgno = $self->prompt(\%user_conf, "msg num: ", {charlim=>7});
   my $msg   = $self->msg_get(\%user_conf, $msgno);
   
   if ( ref($msg) =~ /HASH/ ) {
      # $msg->{user} //= "unknown";
      $msg->{user}    //= "spaceboyfriend";
      $msg->{subject} //= "mysterious message";
      
      $self->debug("msgget", Dumper([\%user_conf, $msg]));
      
      $self->sendbbs(\%user_conf, "\@PCX{PURPLE}"."-" x 35 . "\@PCX{LIGHTGRAY}\r\n");
      $self->sendbbs(\%user_conf, "\@PCX{BLUE}From: \@PCX{CYAN}".$msg->{user}."\@PCX{LIGHTGRAY}\r\n");
      $self->sendbbs(\%user_conf, "\@PCX{BLUE}Date: \@PCX{CYAN}".$msg->{date}."\@PCX{LIGHTGRAY}\r\n");
      $self->sendbbs(\%user_conf, "\@PCX{BLUE}Subject: \@PCX{ORANGE}".$msg->{subject}."\@PCX{LIGHTGRAY}\r\n");
      $self->sendbbs(\%user_conf, "\@PCX{PURPLE}"."-" x 35 . "\@PCX{LIGHTGRAY}\r\n");
      $self->sendbbs(\%user_conf, "\r\n\r\n");
      $msg->{msg} =~ s/\x5c\x5c/\x5c/g; # clean up escaped slashies
      $self->sendbbs(\%user_conf, $msg->{msg});
   }
   
   
   $self->sendbbs(\%user_conf, "\r\n\r\n");
   
   return \%user_conf;
} # menu_read


sub menu_list_byNum {
   my $self = shift;
   my %user_conf   = %{+shift};
   my $tid         = $user_conf{tid};
   my $sock        = $user_conf{sock};
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;
      
   my @nums = ();
   while (<conf/msg/*>) {
      s/^conf\/msg\///;
      s/^[ 0]+//g;
      if ( $_ > $self->{bbs}->{postq} ) { 
         $self->{bbs}->{postq} = $_;
      }
      push(@nums, $_);
   }
   # @nums = reverse @nums; # breaks q aaa x3 fix this
   
   $self->sendbbs(\%user_conf, "\@PCX{LIGHTGRAY}Last msg : \@PCX{GREEN}".$self->{bbs}->{postq}."\@PCX{LIGHTGRAY}\r\n\r\n");  
   $self->sendbbs(\%user_conf, "\@PCX{CYAN}Enter message number\@PCX{LIGHTGRAY}\r\n");
   
   my $start = $self->prompt(\%user_conf, "starting msg num: ", {charlim=>7});   
   $start ||= $self->{bbs}->{postq} - $self->{list_lim} + 1;
   
   
   my $q = 0;
   LIST: foreach my $msgno ( @nums ) {
      last LIST if $q >= $self->{list_lim};
      next LIST if $msgno < $start - 1;
      # --------- #
      my $msg   = $self->msg_get(\%user_conf, $msgno, {quiet=>1});
      # --------- #
      next LIST if ref($msg) !~ /HASH/;
      $msg->{user}    //= "spaceboyfriend";
      $msg->{subject} //= "mysterious messagez";
      # --------- #
      if ( $self->{list_showdate} ) {
         $self->sendbbs(\%user_conf, "\@PCX{LIGHTBLUE}" . "-" x 3 . "\@PCX{BLUE}". $msg->{date} . "\@PCX{LIGHTBLUE}". "-" x 9 . "\@PCX{LIGHTGRAY}\r\n");
      }
      # --------- #
      $self->sendbbs(\%user_conf, "\@PCX{CYAN}". sprintf("%4s","".$msgno) );
      $self->sendbbs(\%user_conf, " \@PCX{GREEN}" . sprintf("%12s",substr($msg->{user},0,12)) );
      $self->sendbbs(\%user_conf, "\@PCX{PURPLE}: \@PCX{LIGHTGREEN}" . substr($msg->{subject}, 0, 17) );
      $self->sendbbs(\%user_conf, "\@PCX{LIGHTGRAY}");
      $self->sendbbs(\%user_conf, "\r\n");         
      # --------- #
      $q++;
   }
   
   # $self->sendbbs(\%user_conf, "\r\n");
   
   return \%user_conf;
} # menu_read

# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #


1;

# uwu