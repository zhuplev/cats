#!perl -w


my $rank = 2;
my $s = 'file: %0n';
$s =~ s/%0n/sprintf("%02d", $rank)/eg;
print $s;
1;