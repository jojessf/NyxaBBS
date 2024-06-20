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
our $C64ColorByName = {
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
};


# --------------------------------------------------------------------------- #
# PETSCiiHex2ASCII, ASCII2PETSCiiHex - hex code conversion
#  my $ascii   = $Net::BBS::Nyxa::CharTable::PETSCiiHex2ASCII{$petscii}
#  my $petscii = $Net::BBS::Nyxa::CharTable::PETSCiiHex2ASCII{$ascii}
# --------------------------------------------------------------------------- #
our $PETSCII2ASCII = {
   # "\xC1" => "A", 
   #  ...
   # "\xDA" => "Z",
   
   # x30-x39	 ~ 0-9
   
   "\x20" => "\x20",
   
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

   "\x21" => '!', # shift+1
   "\x22" => '"', # shift+2
   "\x23" => '#', # shift+3
   "\x24" => '$', # shift+4
   "\x25" => '%', # shift+5
   "\x26" => '&', # shift+6
   "\x27" => "'", # shift+7
   "\x28" => '(', # shift+8
   "\x29" => ')', # shift+9
   
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

   # "\x14" => ' ', # DEL  !!!  TODO 

   "\x81" => '\@PCX{ORANGE}',     # C+1, C=BLK ~ ORANGE
   "\x95" => '\@PCX{BROWN}',      # C+2, C=WHT ~ BROWN 
   "\x96" => '\@PCX{PINK}',       # C+3, C=RED ~ pink
   "\x97" => '\@PCX{DARKGRAY}',   # C+4, C=CYN ~ DARK GRAY 
   "\x98" => '\@PCX{GRAY}',       # C+5, C=PUR ~ GRAY 
   "\x99" => '\@PCX{LIGHTGREEN}', # C+6, C=GRN ~ LIGHT GREEN
   "\x9A" => '\@PCX{LIGHTBLUE}',  # C+7, C=BLU ~ LIGHT BLUE 
   "\x9B" => '\@PCX{LIGHTGRAY}',  # C+8, C=YEL ~ lightgray
   "\x90" => '\@PCX{BLACK}',      # Ctrl+1, Ct BLK ~ Black 
   "\x05" => '\@PCX{WHITE}',      # Ctrl+2, Ct WHT ~ 
   "\x1C" => '\@PCX{RED}',        # Ctrl+3, Ct RED ~ Red 
   "\x9F" => '\@PCX{CYAN}',       # Ctrl+4, Ct CYN ~ Cyan 
   "\x9C" => '\@PCX{PURPLE}',     # Ctrl+5, Ct PUR ~ 
   "\x1E" => '\@PCX{GREEN}',      # Ctrl+6, Ct GRN ~ 
   "\x1F" => '\@PCX{BLUE}',       # Ctrl+7, Ct BLU ~ BLUE 
   "\x9E" => '\@PCX{YELLOW}',     # Ctrl+8, Ct YEL ~ YELLOW
   
   
};
our %ASCII2PETSCII = {
   # "\xC1" => "A", 

};

# Generate uc
# uc - 0xC1(193) ~ PETSCII(A) .. 0xDA(218) ~ PETSCII(Z) 
my $ucDec = 193;
for ( "A" .. "Z" ) {
   my $l  = $_;
   my $hx = pack"H*",sprintf("%02X", $ucDec);
   $PETSCII2ASCII->{$hx} = $l;
   $ASCII2PETSCII->{$l}  = $hx;
   $ucDec++;
}
# Generate lc 
# uc - 0x41(65) ~ PETSCII(A) .. 0x5A(90) ~ PETSCII(Z) 
my $lcDec = 65;
for ( "a" .. "z" ) {
   my $l  = $_;
   my $hx = pack"H*",sprintf("%02X", $lcDec);
   $PETSCII2ASCII->{$hx} = $l;
   $ASCII2PETSCII->{$l}  = $hx;
   $lcDec++;
}
# Generate Numbers
# 0x30(48) ~ PETSCII(0) .. 0x39(57) ~ PETSCII(9)
my $numDec = 48;
for ( "0" .. "9" ) {
   my $l  = $_;
   my $hx = pack"H*",sprintf("%02X", $numDec);
   $PETSCII2ASCII->{$hx} = $l;
   $ASCII2PETSCII->{$l}  = $hx;
   $numDec++;
}

# 0x41 ~ PETSCII(a) .. 0x5A ~ PETSCII(z)

# foreach my $key (sort keys %PETSCiiHex2ASCII ) {
#    my $val = $tab{$key};
#    print ascii2hexr($key) . "\t" . $val . "\n";
# }


1;