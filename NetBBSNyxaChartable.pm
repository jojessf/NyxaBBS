#!/usr/bin/perl
# --------------------------------------------------------------------------- #
# Jojess Fournier 20240619 - Happy Juneteenth!
# --------------------------------------------------------------------------- #
package Net::BBS::Nyxa::CharTable;

# --------------------------------------------------------------------------- #
sub ascii2hexr{my$m;foreach my$c(split//,shift){$m.=uc unpack"H*",$c;$m.=" "};return$m}

# --------------------------------------------------------------------------- #
# ColorByName
# --------------------------------------------------------------------------- #
#     keys %Net::BBS::Nyxa::CharTable::ColorByName
#          $Net::BBS::Nyxa::CharTable::ColorByName{$key}
#     $msg =~ s/\@pcx{$key}/$val/g;
# --------------------------------------------------------------------------- #
our %ColorByName = (
   'white'        =>   "\x05",
   'red'          =>   "\x1C",
   'green'        =>   "\x1E",
   'blue'         =>   "\x1F",
   'orange'       =>   "\x81",
   'black'        =>   "\x90",
   'brown'        =>   "\x95",
   'pink'         =>   "\x96",
   'darkgray'     =>   "\x97",
   'gray'         =>   "\x98",
   'lightgreen'   =>   "\x99",
   'lightblue'    =>   "\x9A",
   'lightgray'    =>   "\x9B",
   'purple'       =>   "\x9C",
   'yellow'       =>   "\x9E",
   'cyan'         =>   "\x9F",
);


# --------------------------------------------------------------------------- #
# PETSCiiHex2ASCII, ASCII2PETSCiiHex - hex code conversion
#  my $ascii   = $Net::BBS::Nyxa::CharTable::PETSCiiHex2ASCII{$petscii}
#  my $petscii = $Net::BBS::Nyxa::CharTable::PETSCiiHex2ASCII{$ascii}
# --------------------------------------------------------------------------- #
our %PETSCiiHex2ASCII = (
   # "\xC1" => "A", 
   #  ...
   # "\xDA" => "Z",
   
   # x30-x39	 ~ 0-9
   
   "\x0D" => "\r",
   
   "\x2B" => '+',
   "\xDB" => '+', # shift plus 
   "\x2D" => '-',
   "\xDD" => '|', # shift minus 
   "\x5C" => '£',
   "\xA9" => '£', # shift pound [actually block]
   "\x40" => '@',
   "\x2A" => '*',
   "\xBA" => ' ', # shift @, checkmark  # TODO 
   "\x2C" => ',',
   "\x3C" => '<',
   "\x2E" => '.',
   "\x3E" => '>',
   "\x25" => '/',
   "\x3F" => '?',
   "\x3A" => ':',
   "\x3B" => ';',
   "\x3D" => '=',
   "\x5B" => '[', # shift :, [
   "\x5D" => ']', # shift ;, ]
   "\x5E" => '^', # up arrow 
   "\xDE" => ' ', # shift up arrow  [ actually block, TODO ]
   
   # "\x11" => ' ', # UP 
   # "\x1D" => ' ', # LEFT
   # "\x9D" => ' ', # RIGHT
   # "\x91" => ' ', # DOWN
   # "\x85" => ' ', # F1
   # "\x86" => ' ', # F3 
   # "\x87" => ' ', # F5
   # "\x??" => ' ', # F7 # ????
   # "\x89" => ' ', # F2
   # "\x8A" => ' ', # F4
   # "\x8B" => ' ', # F6
   # "\x8C" => ' ', # F8
   
   "\x21" => '!', # shift+1
   "\x22" => '"', # shift+2
   "\x23" => '#', # shift+3
   "\x24" => '$', # shift+4
   "\x25" => '%', # shift+5
   "\x26" => '&', # shift+6
   "\x27" => "'", # shift+7
   "\x28" => '(', # shift+8
   "\x29" => ')', # shift+9
   
   # "\x81" => ' ', # C+1, BLK
   # "\x95" => ' ', # C+2, WHT
   # "\x96" => ' ', # C+3, RED
   # "\x97" => ' ', # C+4, CYN
   # "\x98" => ' ', # C+5, PUR
   # "\x99" => ' ', # C+6, GRN
   # "\x9A" => ' ', # C+7, BLU
   # "\x9B" => ' ', # C+8, YEL
   
   
);
our %ASCII2PETSCiiHex = (
   # "\xC1" => "A", 

);

# Generate uc
# uc - 0xC1 ~ PETSCII(A) .. 0xDA ~ PETSCII(Z) 
my $ucDec = 193;
for ( "A" .. "Z" ) {
   my $l  = $_;
   my $hx = pack"H*",sprintf("%02X", $ucDec);
   $PETSCiiHex2ASCII{$hx} = $l;
   $ASCII2PETSCiiHex{$l}  = $hx;
   $ucDec++;
}
# Generate lc 
# uc - 0x56 ~ PETSCII(A) .. 0xDA ~ PETSCII(Z) 
my $lcDec = 65;
for ( "a" .. "z" ) {
   my $l  = $_;
   my $hx = pack"H*",sprintf("%02X", $lcDec);
   $PETSCiiHex2ASCII{$hx} = $l;
   $ASCII2PETSCiiHex{$l}  = $hx;
   $lcDec++;
}
# 
# 0x30 ~ PETSCII(0) .. 0x39 ~ PETSCII(9)
my $numDec = 48;
for ( "0" .. "9" ) {
   my $l  = $_;
   my $hx = pack"H*",sprintf("%02X", $numDec);
   $PETSCiiHex2ASCII{$hx} = $l;
   $ASCII2PETSCiiHex{$l}  = $hx;
   $numDec++;
}

# 0x41 ~ PETSCII(a) .. 0x5A ~ PETSCII(z)

# foreach my $key (sort keys %PETSCiiHex2ASCII ) {
#    my $val = $tab{$key};
#    print ascii2hexr($key) . "\t" . $val . "\n";
# }


1;