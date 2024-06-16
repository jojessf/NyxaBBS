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
# TODO: 
#  * limit concurrent connections 
#  * limit connections per IP 
#  * post/reader
#  * dates
#  * add server info to stats:  user/post counts, last login
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

   mkdir $self->{ServerParms}->{confdir} if ! -d $self->{ServerParms}->{confdir};
   die "$class FATAL no confdir ".$self->{ServerParms}->{confdir}." \@"   . __LINE__ if ! -d $self->{ServerParms}->{confdir};
   
   mkdir $self->{ServerParms}->{logdir} if ! -d $self->{ServerParms}->{logdir};
   die "$class FATAL no logdir  ".$self->{ServerParms}->{logdir}." \@" . __LINE__ if ! -d $self->{ServerParms}->{logdir};
   
   return $self;
};


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

sub debug {
   my $self  = shift;
   my $lvl   = shift;
   my $msg   = shift;
      $lvl //= "debug";
   if ( $lvl =~ /[a-zA-Z]/ ) {
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
   my $hash  = {};
   my $filepath = $self->{ServerParms}->{confdir} . "/" . $file;
   
   $self->debug("conf", "getconf - $filepath");
     
   if ( ! -e $filepath ) {
      $self->debug("conf", "getconf - $filepath - failed");
      return 0;
   }
   
   my $slurp;
   open IF, "<", $filepath;
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
   my $filepath = $self->{ServerParms}->{confdir} . "/" . $file;
   my $testpath = $filepath;
      $testpath =~ s/^(.*)\/.*/$1/;

   $self->debug("conf", "saveconf - $filepath");

   make_path($testpath) if ! -d $testpath;
   die $self->{class} . "ERROR - can't make_path $testpath" if ! -d $testpath;
      
   my $jsonstr = $self->{json}->pretty->encode( $hash );
   
   open OF, ">", $filepath;
   print OF $jsonstr;
   close OF;
   
   select(undef,undef,undef,0.05);
   return 1;
} # saveconf

sub post_put {
   my $self      = shift;
   my $user_conf = shift;
   
   
   return 1;
}

sub post_get {
   my $self      = shift;
   my $user_conf = shift;
   
   
   return 1;
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
   $msg =~ s/\@pcx{white}/\x05/g; # must be lc here!
   $msg =~ s/\@pcx{red}/\x1C/g;
   $msg =~ s/\@pcx{green}/\x1E/g;
   $msg =~ s/\@pcx{blue}/\x1F/g;
   $msg =~ s/\@pcx{orange}/\x81/g;
   $msg =~ s/\@pcx{black}/\x90/g;
   $msg =~ s/\@pcx{brown}/\x95/g;
   $msg =~ s/\@pcx{pink}/\x96/g;
   $msg =~ s/\@pcx{darkgray}/\x97/g;
   $msg =~ s/\@pcx{gray}/\x98/g;
   $msg =~ s/\@pcx{lightgreen}/\x99/g;
   $msg =~ s/\@pcx{lightblue}/\x9A/g;
   $msg =~ s/\@pcx{lightgray}/\x9B/g;
   $msg =~ s/\@pcx{purple}/\x9C/g;
   $msg =~ s/\@pcx{yellow}/\x9E/g;
   $msg =~ s/\@pcx{cyan}/\x9F/g;
   return $msg;
} # colorcodes

sub scrubcodes {
   my $self = shift;
   my $msg = shift;
   $msg =~ s/\@PCX{[a-zA-Z]+?}//g; # must be caps here! 
   return $msg;
} # scrubcodes
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
      $self->menu_main($user_conf, $tid);
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
   $self->sendbbs(\%user_conf, "Confirm:" . Dumper([$user_file]) . "\r\n");
   
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
   
   return if $username !~ m/^[a-zA-Z0-9]{1,32}$/;
   return if $password !~ m/^[a-zA-Z0-9]{1,32}$/;
   
   my $userfile = $self->getconf("user/$username");
   
   if ( ( $userfile ) && ( $userfile->{pass} eq $password ) ) {
      $self->sendbbs(\%user_conf, "Welcome, $username! :3c\r\n");
      $user_conf{loggedin} = 1;
      UFK: foreach my $key ( keys %{$userfile} ) {
         next UFK if $key =~ m/^(ip|port|PETSCII|tid)$/;
         $user_conf{$key} = $userfile->{$key};
         $self->menu_bbs(\%user_conf, $tid);
      }
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
   $self->sendbbs(\%user_conf, "\r\n");
   $user_conf{user}     //= "Guest - $tid";
   $user_conf{USERSTAT} ||= "-" x 16;
   UCKey: foreach my $key ("USERSTAT", "user", "pass", "ip", "port", "loggedin") {
      my $val   = $user_conf{$key};
      $val =~ s/./*/g if $key =~ /pass/;
      $self->sendbbs(\%user_conf, "[ ".sprintf("%-8s", $key)." ] $val\r\n");
   }
   UCKey: foreach my $key (sort keys %user_conf) {
      next UCKey if $key =~ /^(sock|user|pass|ip|port|USERSTAT|add[12]|city|computer|country|state|zip|tid|loggedin)$/;
      my $val   = $user_conf{$key};
      next if (( ! defined($val) ) || ( $val eq '' ))  ;
      $self->sendbbs(\%user_conf, "[ ".sprintf("%-8s", $key)." ] $val\r\n");
   }
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
            $self->skipsplash;
            last MMCON;
         } # quit 

         # ----------------------------- #
         # [l]ogin
         # ----------------------------- #
         if ( $user_data =~ /^(l|login)[\r\n]*$/i ) {
            %user_conf = %{ $self->menu_login(\%user_conf, $tid) };
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
      return;
} # menu_main

# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #

sub menu_bbs {
   my $self = shift;
   my %user_conf   = %{+shift};
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
            $self->skipsplash;
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
         # [r]ead
         # ----------------------------- #
         if ( $user_data =~ /^(r|read)[\r\n]*$/i ) {
            # %user_conf = %{ $self->menu_read(\%user_conf, $tid) };
         }

         # ----------------------------- #
         # [p]ost
         # ----------------------------- #
         if ( $user_data =~ /^(p|post)[\r\n]*$/i ) {
            # %user_conf = %{ $self->menu_post(\%user_conf, $tid) };
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
            $self->sendbbs(\%user_conf, $ServerParms{menumsg_bbs});
         }
         
      } # Net::BBS::Nyxa::MAIN / while connected 
      # --------------------------------------------------------------------------- #
      return;
} # menu_bbs


1;

# uwu