system "copy $ARGV[0] __tmp";
open(OUTP,">$ARGV[0]"); open(TMP,"<__tmp");

print OUTP "$ARGV[1]\n";
while (<TMP>) {print OUTP $_};

close OUTP; close TMP;
system "del __tmp"