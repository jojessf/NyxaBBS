#!/usr/bin/perl
# --------------------------------------------------------------------------- #
# Jojess Fournier 20240614
# --------------------------------------------------------------------------- #
package Net::BBS::Nyxa;
# --------------------------------------------------------------------------- #
use strict;
# use warnings;
use Storable qw(dclone);
use Thread;
use IO::Socket::INET;                # https://metacpan.org/pod/IO::Socket::INET
use Text::Convert::PETSCII qw/:all/; # https://metacpan.org/pod/Text::Convert::PETSCII
# --------------------------------------------------------------------------- #
my %ServerParms = (
    # IO::Socket::INET
    # LocalHost => '8.8.8.8',
    # LocalHost => '127.0.0.1', # restrict to ip/iface
    LocalPort => '6400',
    Proto => 'tcp',
    Listen => SOMAXCONN, # 4096
    ReuseAddr => 1,
    verbose => 1,
    Threads => {},
    PETSCIISplash00FI => "testbbs_nyxa05_splash",
    bbsmenumsg => "\r\n\r\n\@PCX{CYAN}~\@PCX{LIGHTBLUE}UwU\@PCX{CYAN}~\@PCX{PURPLE}".
                  "NyxaBBS\@PCX{LIGHTGRAY}:\@PCX{LIGHTGREEN}MainMenu".
                  "\@PCX{CYAN}~\@PCX{LIGHTGRAY}\@PCX{LIGHTBLUE}UwU\@PCX{CYAN}~\@PCX{LIGHTGRAY} \r\n\r\n" . 
                  "[\@PCX{RED}q\@PCX{LIGHTGRAY}]uit [\@PCX{CYAN}l\@PCX{LIGHTGRAY}]ogin [\@PCX{GREEN}r\@PCX{LIGHTGRAY}]egister [\@PCX{PURPLE}s\@PCX{LIGHTGRAY}]tats\r\n",  # $ServerParms{bbsmenumsg}
    # JojessBBS
);

my %UserParmDefault = (
   user => undef,
   pass => undef,
   port => undef,
   ip   => undef,
   PETSCII => 0, # $user_conf{PETSCII}
);
# --------------------------------------------------------------------------- #
if ( -e $ServerParms{PETSCIISplash00FI} ) {
   open IF, "<" . $ServerParms{PETSCIISplash00FI};
   while (<IF>) { $ServerParms{PETSCIISplash00} .= $_; }
   close IF;
   $ServerParms{PETSCIISplash00} =~ s/\n/\r/g; # trim first 6 chars of basic file
   $ServerParms{PETSCIISplash00} = "\x9F".$ServerParms{PETSCIISplash00}."\x9B"
}
print "ingested " . $ServerParms{PETSCIISplash00FI} . "\t" . length($ServerParms{PETSCIISplash00}) . " B\n";
# exit;
# --------------------------------------------------------------------------- #
# Server Socket 
# --------------------------------------------------------------------------- #
$ServerParms{Threads} = {} if $ServerParms{Threads} eq undef;
my $server_socket = new IO::Socket::INET (
    %ServerParms
);
$server_socket || die $IO::Socket::errst; # works

# --------------------------------------------------------------------------- #
sub colorcodes {
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
   my $msg = shift;
   $msg =~ s/\@PCX{[a-zA-Z]+?}//g; # must be caps here! 
   return $msg;
}

# --------------------------------------------------------------------------- #
# IO::Socket::INET "sendbbs" wrapper sub~ 
# --------------------------------------------------------------------------- #
sub IO::Socket::INET::sendbbs {
   my $self       = shift;
   my $user_conf  = shift;
   my $msg        = shift;
   my $sock       = $user_conf->{sock};
   $msg =~ s/\n//g if $user_conf->{PETSCII};
   # ---------------------- #
   $msg = ascii_to_petscii($msg) if $user_conf->{PETSCII};
   
   if ( $user_conf->{PETSCII} )   { $msg = colorcodes($msg) };
   if ( ! $user_conf->{PETSCII} ) { $msg = scrubcodes($msg) };
   
   print "PCX>>$msg<<\n" if $ENV{DEBUG} eq 'sendbbs';
   
   $sock->send($msg);
   # ---------------------- #
   return 1;
}
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
print "Jojess BBS Init :3\r\n";
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
CONNECTION: while(1) {

   next CONNECTION unless my $sock = $server_socket->accept();
   my $user_data;
   my %user_conf    = %{dclone \%UserParmDefault};

   my $user_ip      = $sock->peerhost();
   my $user_port    = $sock->peerport();

   $user_conf{ip}   = $user_ip;
   $user_conf{port} = $user_port;
   $user_conf{sock} = $sock;

   # 
   my $response = "CONNECTED: $user_ip : $user_port. \r\n";
      print "$response" if $ServerParms{verbose} >= 1;
      $response .= "[c]64 to enable PETSCII\r\n";
      $response .= " ... ENTER/RETURN to continue\r\n";
   # $response .= "[q]uit [l]ogin [s]tats\n";
   $sock->sendbbs(\%user_conf, $response);
   
   # --------------------------------------------------------------------------- #
   # Net::BBS::Nyxa::PRE
   # --------------------------------------------------------------------------- #
   while ($sock->connected()) {
      $sock->recv( $user_data,  1024 );
      # ----------------------------- #
      if ( $user_data =~ /^(c|c64)[\r\n]*$/i ) {
         my $res = "Enabling PETSCII...!\r\n\r\n";
         $user_conf{PETSCII} = 1;
         $sock->sendbbs(\%user_conf, $res);
         last;
      } elsif ( $user_data =~ /^.*[\r\n]*$/i ) {
         my $res = "No PETSCII - You should try with a C64, though!\r\n";
         $user_conf{PETSCII} = 0;
         $sock->sendbbs(\%user_conf, $res);
         last
      }
   } # Net::BBS::Nyxa::PRE / while connected
   
   # --------------------------------------------------------------------------- #
   if ( $user_conf{PETSCII} ) {
      foreach my $pc (split/\r/, $ServerParms{PETSCIISplash00}) {$sock->send($pc."\r");}
   }
   $sock->sendbbs(\%user_conf, $ServerParms{bbsmenumsg});
   # --------------------------------------------------------------------------- #
   # /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
   # --------------------------------------------------------------------------- #
   # Net::BBS::Nyxa::MAIN 
   # --------------------------------------------------------------------------- #
   # /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
   # --------------------------------------------------------------------------- #
   while ($sock->connected()) {
      $sock->recv( $user_data,  1024 );

      # ----------------------------- #
      # [q]uit 
      # ----------------------------- #
      if ( $user_data =~ /^(q|quit|exit)[\r\n]*$/i ) {
         my $msg = "Disconnecting $user_ip : $user_port\r\n";
         print $msg if $ServerParms{verbose} >= 1;
         $sock->sendbbs(\%user_conf, $msg);
         $sock->close();
         # $server_socket->close(); # no lol
         last;
      } # quit 

      # ----------------------------- #
      # [c]olortest
      # ----------------------------- #
      if ( $user_data =~ /^(c|colortest)[\r\n]*$/i ) {
         my $msg = "\r\n[c]olortest\r\n";
         $sock->sendbbs(\%user_conf, $msg);
         
         $msg = "";
         $msg .= "\@PCX{RED}...\@PCX{CYAN}UWU\@PCX{LIGHTGRAY}OWO";
         $sock->sendbbs(\%user_conf, $msg);
         
         $msg = "\r\n...\r\n\r\n";
         $sock->sendbbs(\%user_conf, $msg);
      }

      # ----------------------------- #
      # [l]ogin
      # ----------------------------- #
      if ( $user_data =~ /^(l|login)[\r\n]*$/i ) {
         my $msg = "[l]ogin wip\r\n";
         $sock->sendbbs(\%user_conf, $msg);
      }

      # ----------------------------- #
      # [r]egister
      # ----------------------------- #
      if ( $user_data =~ /^(r|register)[\r\n]*$/i ) {
         my $msg = "[r]egistration wip\r\n";
         $sock->sendbbs(\%user_conf, $msg);
      }
      
      # ----------------------------- #
      # [s]tats 
      # ----------------------------- #
      if ( $user_data =~ /^(s|stats)[\r\n]*$/i ) {
         my $msg = "\r\n";
         UCKey: foreach my $key (sort keys %user_conf) {
            next UCKey if $key eq "sock";
            my $val   = $user_conf{$key};
            my $smsg = "[ $key ] $val\r\n";
            $sock->sendbbs(\%user_conf, $smsg);
         }
         $sock->sendbbs(\%user_conf, $msg);
      } # stats

      # ----------------------------- #
      # REPRINT MAIN MENU
      # ----------------------------- #
      if ($user_data) {
         
         if ( $user_conf{PETSCII} ) {
            foreach my $pc (split/\r/, $ServerParms{PETSCIISplash00}) {$sock->send($pc."\r");}
         }
         
         
         $sock->sendbbs(\%user_conf, $ServerParms{bbsmenumsg});
      }
      
   } # Net::BBS::Nyxa::MAIN / while connected 
   # --------------------------------------------------------------------------- #

   # last;
}
print "BBS Shutting Down!\r\n" if $ServerParms{verbose} >= 0;
exit;
