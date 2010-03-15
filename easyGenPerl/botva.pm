package botva;

use FormalInput;

sub ababaca {
   my $a = FormalInput::parserValidate "integer name = a, range = [0, 10]\n integer name = a, range = [0, 10]";
   if ($a) {
      my $s = FormalInput::errorMessageByCode(FormalInput::getErrCode($a));
      my $l = FormalInput::getErrLine($a);
      my $p = FormalInput::getErrPos($a);
      print "$s. Line: $l. Pos: $p.";
   } else {print "OK\n";}
}

1;