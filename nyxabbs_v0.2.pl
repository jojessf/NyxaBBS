#!/usr/bin/perl
# --------------------------------------------------------------------------- #
# Jojess Fournier 20240614
# --------------------------------------------------------------------------- #
use strict;
use IO::Socket::INET;                # https://metacpan.org/pod/IO::Socket::INET
$SIG{CHLD} = sub { wait; };
require("./NetBBSNyxa.pm"); 
# --------------------------------------------------------------------------- #
my %ServerParms = (
    # LocalHost         => '127.0.0.1', # restrict to ip/iface
    LocalPort         => '6400',
    Proto             => 'tcp',
    Listen            => SOMAXCONN, # 4096
    ReuseAddr         => 1,
    verbose           => 0,
    # --------------------- #
    authfaildie       => 0,
    registrationopen  => 0,
    # --------------------- #
    debugdir          => 'debug',
    logdir            => 'log',
    confdir           => 'conf',
    PETSCIISplash00FI => "nyxabbs.splash",
    bbsmenumsg => "\r\n\r\n\@PCX{CYAN}~\@PCX{LIGHTBLUE}UwU\@PCX{CYAN}~\@PCX{PURPLE}".
                  "NyxaBBS\@PCX{LIGHTGRAY}:\@PCX{LIGHTGREEN}MainMenu".
                  "\@PCX{CYAN}~\@PCX{LIGHTGRAY}\@PCX{LIGHTBLUE}UwU\@PCX{CYAN}~\@PCX{LIGHTGRAY} \r\n\r\n" . 
                  "[\@PCX{RED}q\@PCX{LIGHTGRAY}]uit [\@PCX{CYAN}l\@PCX{LIGHTGRAY}]ogin [\@PCX{GREEN}r\@PCX{LIGHTGRAY}]egister [\@PCX{PURPLE}s\@PCX{LIGHTGRAY}]tats\r\n",  # $ServerParms{bbsmenumsg}
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
# --------------------------------------------------------------------------- #
# Server Socket 
# --------------------------------------------------------------------------- #
$ServerParms{Threads} = {} if $ServerParms{Threads} eq undef;
my $server_socket = new IO::Socket::INET (
    %ServerParms
);
$server_socket || die $IO::Socket::errst; # works
# --------------------------------------------------------------------------- #
# NyxaBBS Init
# --------------------------------------------------------------------------- #
print "NyxaBBS Init :3\r\n";
my $NyxaBBS = Net::BBS::Nyxa->new($server_socket, \%ServerParms);
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #


# my $userprofile = $NyxaBBS->getconf("user/test");
# if ( ! $userprofile ) {
#    $NyxaBBS->saveconf("user/test", {
#       user => 'test',
#       pass => 'meowmix',
#    });
# }


# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #
$NyxaBBS->listen();
# --------------------------------------------------------------------------- #
# /\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/\/ #
# --------------------------------------------------------------------------- #

print "Good night NyxaBBS!\r\n" if $ServerParms{verbose} >= 0;
exit;
