#!/usr/bin/perl
# --------------------------------------------------------------------------- #
# Jojess Fournier 20240614
# --------------------------------------------------------------------------- #
package Net::BBS::Nyxa;
# --------------------------------------------------------------------------- #
use strict;
use warnings;
use IO::Socket::INET;
use Storable qw(dclone);
use Text::Convert::PETSCII qw/:all/; # https://metacpan.org/pod/Text::Convert::PETSCII
# --------------------------------------------------------------------------- #
my %ServerParms = (
    # IO::Socket::INET
    # LocalHost => '127.0.0.1', # restrict to ip/iface
    LocalPort => '6400',
    Proto => 'tcp',
    Listen => SOMAXCONN,
    ReuseAddr => 1,
    verbose => 1,
    # JojessBBS
);
my %UserParmDefault = (
   user => undef,
   pass => undef,
   port => undef,
   ip   => undef,
   PETSCII => 0,
);
# --------------------------------------------------------------------------- #
my $server_socket = new IO::Socket::INET (
    %ServerParms
);

my $sock;
my $user_data;
# --------------------------------------------------------------------------- #
sub IO::Socket::INET::sendbbs {
   my $self       = shift;
   my $user_conf  = shift;
   my $msg        = shift;
   $msg =~ s/\n//g if $user_conf->{PETSCII};
   $msg = ascii_to_petscii($msg) if $user_conf->{PETSCII};
   $sock->send($msg);
   return 1;
}
# --------------------------------------------------------------------------- #
print "Jojess BBS Init :3\r\n";
# --------------------------------------------------------------------------- #
while(1) {

next unless $sock = $server_socket->accept();

   my %user_conf    = %{dclone \%UserParmDefault};

   my $user_ip      = $sock->peerhost();
   my $user_port    = $sock->peerport();

   $user_conf{ip}   = $user_ip;
   $user_conf{port} = $user_port;

   # 
   my $response = "Connected: $user_ip : $user_port. \r\n";
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
         my $res = "Enabling PETSCII...!\r\n";
         $user_conf{PETSCII} = 1;
         $sock->sendbbs(\%user_conf, $res);
         last;
      } elsif ( $user_data =~ /^.*[\r\n]*$/i ) {
         my $res = "No PETSCII\r\n";
         $user_conf{PETSCII} = 0;
         $sock->sendbbs(\%user_conf, $res);
         last
      }
   } # Net::BBS::Nyxa::PRE / while connected
   
   $response = "~ UwU ~ MAIN MENU ~ UwU ~\r\n";
   $response .= "[q]uit [l]ogin [s]tats\r\n";
   $sock->sendbbs(\%user_conf, $response);
   # --------------------------------------------------------------------------- #
   # Net::BBS::Nyxa::MAIN 
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
      # [s]tats 
      # ----------------------------- #
      if ( $user_data =~ /^(s|stats)[\r\n]*$/i ) {
         my $msg = "\n";
            $msg .= "stats WIP! ^^;\r\n";
         
         foreach my $key (sort keys %user_conf) {
            my $val   = $user_conf{$key};
               $val ||= "";
            my $smsg = "[ $key ] $val\r\n";
            $sock->sendbbs(\%user_conf, $smsg);
         }
         
         $sock->sendbbs(\%user_conf, $msg);
      } # stats

      # ----------------------------- #
      # REPRINT MAIN MENU
      # ----------------------------- #
      if ($user_data) {
         my $res = "\n ~ UwU ~ MAIN MENU ~ UwU ~ \r\n";
            $res .= "[q]uit [l]ogin [s]tats\r\n";
         $sock->sendbbs(\%user_conf, $res);
      }
      
   } # Net::BBS::Nyxa::MAIN / while connected 
   # --------------------------------------------------------------------------- #

   # last;
}
print "BBS Shutting Down!\r\n" if $ServerParms{verbose} >= 0;
exit;
