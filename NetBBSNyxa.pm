#!/usr/bin/perl
# --------------------------------------------------------------------------- #
# Jojess Fournier 20240614
# --------------------------------------------------------------------------- #
package Net::BBS::Nyxa;
# --------------------------------------------------------------------------- #
use strict;
use Storable qw(dclone);
use Data::Dumper;
use Text::Convert::PETSCII qw/:all/; # https://metacpan.org/pod/Text::Convert::PETSCII
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
      UserParmDefault => {
         'user' => undef,
         'pass' => undef,
         'port' => undef,
         'ip'   => undef,
         'PETSCII' => 0, # $user_conf{PETSCII}
      },
   };
   bless($self, $class);
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
   my $msg   = shift;
   my $lvl   = shift;
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

sub sleep {
   my $self  = shift;
   my $sleep = shift;
   select(undef,undef,undef,$sleep);
   return;
}

sub skipsplash {
   my $self = shift;
   $self->{skipsplash}++;
   return;
}

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
}

sub scrubcodes {
   my $self = shift;
   my $msg = shift;
   $msg =~ s/\@PCX{[a-zA-Z]+?}//g; # must be caps here! 
   return $msg;
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
         
         $self->menu_zero($pid);
      }

      $self->sleep(0.05); # sleep for 50ms between new sockets
   }
   return;
}
# --------------------------------------------------------------------------- #
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
      $self->menu_main($tid);
      last ZEROCON;
   } # Net::BBS::Nyxa::PRE / while connected
   
   return;
}

# --------------------------------------------------------------------------- #
# --------------------------------------------------------------------------- #
sub menu_main {
   my $self = shift;
   my $tid         = shift;
   my $sock        = $self->{threads}->{ $tid }->{sock};
   my $thread      = $self->{threads}->{ $tid }->{thread};
   my %user_conf   = %{ $self->{threads}->{ $tid }->{user_conf} };
   my %ServerParms = %{ $self->{ServerParms} };
   my $user_data   = undef;

      # --------------------------------------------------------------------------- #
      if ( $user_conf{PETSCII} ) {
         foreach my $pc (split/\r/, $ServerParms{PETSCIISplash00}) {$sock->send($pc."\r");}
      } else {
         $self->sendbbs(\%user_conf, "NO PETSCII\r\n");
      }
      $self->sendbbs(\%user_conf, $ServerParms{bbsmenumsg});
      # --------------------------------------------------------------------------- #
      # /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
      # --------------------------------------------------------------------------- #
      # Net::BBS::Nyxa::MAIN 
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
            $self->debug(Dumper([$self]),"dump");
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
         # [l]ogin
         # ----------------------------- #
         if ( $user_data =~ /^(l|login)[\r\n]*$/i ) {
            my $msg = "[l]ogin wip\r\n";
            $self->sendbbs(\%user_conf, $msg);
            $self->skipsplash;
         }

         # ----------------------------- #
         # [r]egister
         # ----------------------------- #
         if ( $user_data =~ /^(r|register)[\r\n]*$/i ) {
            my $msg = "[r]egistration wip\r\n";
            $self->sendbbs(\%user_conf, $msg);
            $self->skipsplash;
         }
         
         # ----------------------------- #
         # [s]tats 
         # ----------------------------- #
         if ( $user_data =~ /^(s|stats)[\r\n]*$/i ) {
            $self->sendbbs(\%user_conf, "\r\n");
            $user_conf{user}     ||= "Guest";
            $user_conf{USERSTAT} ||= "-" x 16;
            UCKey: foreach my $key ("USERSTAT", "user", "pass", "ip", "port") {
               my $val   = $user_conf{$key};
               $self->sendbbs(\%user_conf, "[ ".sprintf("%-8s", $key)." ] $val\r\n");
            }
            UCKey: foreach my $key (sort keys %user_conf) {
               next UCKey if $key =~ /^(sock|user|pass|ip|port|USERSTAT)/;
               my $val   = $user_conf{$key};
               $self->sendbbs(\%user_conf, "[ ".sprintf("%-8s", $key)." ] $val\r\n");
            }
            $self->sendbbs(\%user_conf, "\r\n");
            $self->skipsplash;
         } # stats

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
            $self->sendbbs(\%user_conf, $ServerParms{bbsmenumsg});
         }
         
      } # Net::BBS::Nyxa::MAIN / while connected 
      # --------------------------------------------------------------------------- #
      return;
}

1;