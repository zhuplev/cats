package CATS::Diff;

use CATS::Misc qw(:all);
use File::Temp;
use Text::Balanced qw(extract_tagged extract_bracketed);

BEGIN
{
  use Exporter;

  @ISA = qw ( Exporter );
  @EXPORT = qw (check_diff 
		diff_table
		diff
		prepare_src
		prepare_src_show
		pas_normalize
		clean_src
		delete_obsolete_begins
		replace_proc
		replace_func
		create_new_code
		compare_subs
		cmp_advanced
		);
  %EXPORT_TAGS = ( all => [ @EXPORT, @EXPORT_OK ] );
}

our @keywords_pas = (
    "begin",
    "end",
    "if",
    "then",
    "else",
    "for",
    "downto",
    "to", 
    "do",    
    "while", 
    "repeat",
    "until", 
    "write", 
    "writeln",
    "read",   
    "readln",
    "random",
    "procedure",
    "function",
    "and",
    "or",
    "xor",
    "var",
    "const",
    "program",
    "goto",
    "label",
    "uses"
                     );

our @subs;
our $id;
our @rec_proc;
our @rec_func;
our $max;

#���������� ������� diff'��
sub cmp_diff
{
#  return 100; # �������
  
  my $tmp1 = shift;
  my $tmp2 = shift;

  $tmp1 eq $tmp2 and return 100;
  `diff -u $tmp1 $tmp2 >0000.txt`;
  open (DIFF_FILE, '<', '0000.txt');
  my $line = <DIFF_FILE>;	# � 1-� ������ - ���� � 1-� �����
  !$line and return 100;
  $line = <DIFF_FILE>;	# �� 2-� ������ - ���� � 2-� �����
  $line = <DIFF_FILE>;	# � 3-� ������ - ��������� �����
  $line = <DIFF_FILE>;	# c 4-� ������ �� ����������
  my $plus=-1;
  my $minus=-1;
  my $lines=1;
  while ($line)
  {
    $line !~ /^@@/ and $lines++;
    
    $line =~ /^\+/ and $plus++;
    $line =~ /^\-/ and $minus++;
    
    $line = <DIFF_FILE>;
  }
  int 100 * (0.99 - ($plus>$minus? $plus/($lines-$minus) : $minus/($lines-$plus)));
}

# ���������� ����������� ����������
sub cmp_advanced
{
  my $tmp1 = shift;
  my $tmp2 = shift;
  
  $tmp1 eq $tmp2 and return 100;	# ���� ���� � ��� �� ����

  open (FILE, $tmp1);			# ������ �� ����� ������ �����
  $/=undef;				# ����� ���������
  my $src1 = <FILE>;	
  $src1 = replace_proc($src1);		# ���������������� ���������
  $src1 = replace_func($src1);		# ���������������� �������
  $src1 = create_new_code($src1);	# ������������ ��������� ���

  open (FILE, $tmp2);			# �� �� ����� ������ �� ������
  $/=undef;
  my $src2 = <FILE>;
  $src2 = replace_proc($src2);
  $src2 = replace_func($src2);
  $src2 = create_new_code($src2);

  my $comp = compare_subs($src1,$src2);	# ����������
  int $comp*100/$max;		# ������ ������� ����������
}

# ������� ��� �� ����� ���������, ���������� � tmp-���� � ���������� ��� ����� tmp-�����
sub prepare_src
{
  my ($src, $algorythm) = @_;
  
  $src = clean_src($src);
  $src = pas_normalize($src);
  
  #$algorythm eq 'diff' and
  $src =~ s/;(\w)/;\n$1/g;	#�������� �� �� �������� (��������� ������ ���� ���������� diff'��)
  
  my ($fh, $fname) = tmpnam;
  syswrite $fh, $src, length($src);
  $fname;
}

# ������� �� ���� ��� ������ !!
sub clean_src
{
  my $src = shift;
  $src =~ s/^program.*?;//i;	# ������� PROGRAM, ���� ����
  $src =~ s/\/\/.*//gs;		# ������������ ����������� �����������
  $src =~ s/\{[^\}]*?\}//gs;		# � ������������� ������������ �����������

  $src =~ s/assign.*?\(.*?;//gi;	# assign ���� ����� ������, �.�. ��� ����� �����
  $src =~ s/assignfile.*?\(.*?;//gi;	# assignfile - �� �� �����, ������ � ������
  $src =~ s/close.*?\(.*?;//gi;		# � close ����
  $src =~ s/reset[\s,\(].*?;//gi;	# reset/rewrite
  $src =~ s/rewrite[\s,\(].*?;//gi;
  
  # ����������� �����-������, ������ � ������� ��� ��������� ����������� (���� ����)
  $src =~ s/\s/ /g;
  $src =~ s/begin/begin;/gi;
  $src =~ s/else/;else/gi;
  foreach ('read','write')			# ������, ���� ������ ��������� � read/write, � readln/writeln
  {
    while ($src =~ s/;[^;]*?$_.*?;/;/gi){}	# ��� ���� ������ ������ ���, ��� while �� ��������
  }
  
  $src =~ s/;else/else/gi;
  $src =~ s/begin;/begin/gi;
  $src =~ s/;;/;/g;				# �� ������ ������
  
  $src;
}

#������ �������� �����, ��� ���������� ����� ������� ��� ��������� !!
sub call_brackets
{
  my $src = shift;
  
  my @names;
  push @names, $src =~ m/PROCEDURE(\w+)[^\w\(]/g;	# ����� ���� �������� ��� ����������
  push @names, $src =~ m/FUNCTION(\w+)[^\w\(]/g;	# ����� ���� ������� ��� ����������
  
  foreach (@names)
  {
    $src =~ s/([A-Z\W]$_)([A-Z\W])/$1\(\)$2/g ;
  }
  
  $src =~ s/(([A-Z\W])\w*)\(\):=/$1:=/g;	# ��� �� ������� ������ �������� �� ����������� �������
  
  $src;
}

# ����������� �������������� ������ !!
sub pas_normalize
{
  my $src = shift;
  #$src = clean_src($src);
  
  $src = ';'.$src;
  $src =~ tr/A-Z/a-z/;		# ����������� ���� ��� � ������ �������
# �������� ��� �������� ����� �� ������� �������
  $src =~ s/(\W$_\W)/\U$1\L/g foreach (@keywords_pas);
  $src =~ s/program .*?;//;
  
# �������� div � mod �� ������
  $src =~ s/(\W)div(\W)/$1\\$2/g;	# div �� \
  $src =~ s/(\W)mod(\W)/$1%$2/g;	# mod �� %
  
# ������� inc � dec
  $src =~ s/(\W)inc\((\w*?)\)/$1$2:=$2+1/g;
  $src =~ s/(\W)dec\((\w*?)\)/$1$2:=$2-1/g;
  
  #$src =~ s/[a-z]+\w*?\s*?\(/f\(/g;			# ��� ������ ������� �������� �� f
  $src =~ s/[a-z]+\w*?\s*?([^a-zA-Z_0-9(])/\$$1/g;	# ��� ����� ���������� �������� �� $
  $src =~ s/\$\[/\@[/g;					# ��� ����� ������ �������� �� @
  #$src =~ s/[+-]?[0-9]+/n/g;				# ��� ����� ����� �������� �� n
  #$src =~ s/[+-]?\d+\.\d?([eE][+-]?\d)?/r/g;		# ��� ������������ ����� �������� �� r
  
  $src =~ s/\s//gs;		#������� �������

# ��������� �������� ����� � ������� ��������
  $src = call_brackets($src);
  
  $src =~ s/(PROCEDURE\w*?\(.*?)VAR(.*?\))/$1$2/g;	# �������� VAR �� ������ ���������� �������� � �������
  $src =~ s/(FUNCTION\w*?\(.*?)VAR(.*?\))/$1$2/g;	# �������� VAR �� ������ ���������� �������� � �������
  $src =~ s/$_.*?([A-Z])/$1/g foreach ('CONST','VAR','LABEL','USES'); # ������� ����� VAR, CONST, LABEL
  #$src =~ s/$_;//g foreach ('CONST','VAR','LABEL','USES');

  $src =~ s/END([^;])/END;$1/g;	# ��������� ; ����� END ���, ��� �� ����
  $src =~ s/([^;])END/$1;END/g;	# ��������� ; ����� END ���, ��� �� ���� � ��� �� ����� ���� ����
  $src =~ s/([^;])UNTIL/$1;UNTIL/g;	# ��������� ; ����� END ���, ��� �� ���� � ��� �� ����� ���� ����
  $src =~ s/;ELSE/ELSE/;	# ������� ; ����� ELSE
  $src =~ s/BEGIN/BEGIN;/g;
  #$src =~ s/[^;]END;/\nEND;/g;
  #$src =~ s/([^A-Z]DO)([^\n])/$1\n$2/g;
  #$src =~ s/([^A-Z]THEN)([^\n])/$1\n$2/g;
  #$src =~ s/DOBEGIN/DO BEGIN/g;	# ���� BEGIN ��������� � ���������� DO, ����� ��� ����� �� ����� �������
  #$src =~ s/THENBEGIN/THEN BEGIN/g;	# ���������� ��� THEN
  chop $src  ;
  
  #$src =~ s/\s/ /gs;

  $src;
}

# ���������� ������ ��������� � ������ ����, ����� ����� ���� ���������� �����
# � Misc?
sub prepare_src_show
{
  my $src = shift;
  $src =~ tr/A-Z/a-z/;		# ����������� ���� ��� � ������ �������

  $src = '<pre>'.$src.'</pre>';
  $src =~ s/(\W)($_)(\W)/$1<b>\U$2\L<\/b>$3/g foreach (@keywords_pas);	#�������� ����� ������ ������� ��������� � ������ �������
  
  $src;
}

# ����������� ����������� ���������� � ��������� ������ ���������� !! 
sub subst_params
{
  my $src = shift;	# ����� ���������
  my $formals = shift;	# ������ ���������� ����������
  my $facts = shift;	# ������ ���������� ����������

  my @formal_list = split /,/,$formals;
  my @fact_list = split /,/,$facts;
  
  while(@fact_list)
  {
    $src =~ s/([^a-z])$formal_list[0]([^a-z])/$1$fact_list[0]$2/g;
    shift @formal_list;
    shift @fact_list;
  }  
  $src;
}

# ���������������� �������� !!
sub replace_proc
{
  my $src = shift;
  my ($body, $pname, $formals, $n, @extr, $pos, $len, $facts, $body2subst);
  
  while ($src =~ s/PROCEDURE(\w*?)(\(.*?\))?;(.*?)BEGIN/$1 BEGIN/)
  {
    $pname = $1;		# ��� ���������
    $formals = $2;		# ������ ���������� ����������
    $body = 'BEGIN'.$';		# ���� ���������
    
    $formals =~ s/;/,/g;		# ������ ����������� ���������� - ������, ����������� ��������
    $formals =~ s/:.*?(,|\))/$1/g;
    $formals =~ s/^\(//;		# ������ ���������� � ����������� ��������
    $formals =~ s/\)$//;
      
    @extr = extract_tagged($body, 'BEGIN','END', undef);	# �������� ���� ���������
    $body = $extr[0].';';
    $n = length($body)+length($pname)+1;
    
    substr ($src, index($src,$pname), $n, '');		# ������� ����������� ���������
    
    if ($body =~ m/$pname\(/)	# ��������� � ���� ��������� ����� � �� => ��� ��������
    {
      $body =~ s/([A-Z\W])$pname\(/$1call\(/g;	# ���������� ����������� ����� ��� call
      push @rec_proc, $body;		# ��������� ���� ��������� � ������ ����������� ��������
      my $i = $#rec_proc;		# ����� ������
      $src =~ s/$pname/prec$i/g;		# �������� ��� � ������ ���������
      
      return $src;		# ������ ������ �� ����� ������ � ���������
    }
    
    # ������ ����� ��� ��������� ��������� ����������������
    while ($src =~ m/$pname(\(.*?\))?;/)
    {
      $pos = length ($`);	# ����� �������, � ������� ����������� ����� ���������
      $len = length ($&);	# �����, �� ����� �����������
      $facts = $1;		# ������ ����������� ����������
      $facts =~ s/^\(//;
      $facts =~ s/\)$//;
      
      $body2subst = subst_params($body, $formals, $facts);
      substr ($src, $pos, $len, $body2subst);
    }
  }
  
  $src;
}

# ���������������� �������
# ������
#	use (func(...))
# ��
#	f = func(...)
#	use (f)
sub replace_func
{
  my $src = shift;
  my ($body, $fname, $formals, $ftype, $n, @extr, $pos, $len, $facts, $body2subst);
  
  while ($src =~ s/FUNCTION(\w*?)(\(.*?\))?:(\w*?);(.*?)BEGIN/$1 BEGIN/)
  {
    $fname = $1;		# ��� �������
    $formals = $2;		# ������ ���������� ����������
    $ftype = $3;		# ��� ������������� ��������
    $body = 'BEGIN'.$';		# ���� �������
    
    $formals =~ s/;/,/g;		# ��������� ������ ������, ����������� ��������
    $formals =~ s/:.*?(,|\))/$1/g;
    $formals =~ s/^\(//;		# ������ ���������� � ����������� ��������
    $formals =~ s/\)$//;
    
    @extr = extract_tagged($body, 'BEGIN','END', undef);	# �������� ���� ���������
    $body = $extr[0].';';
    
    $n = length($body)+length($fname)+1;
    
    substr ($src, index($src,$fname), $n, '');		# ������� ����������� ���������
    
    if ($body =~ m/$fname\(/)	# ��������� � ���� ������� ����� � �� => ��� ��������
    {
      $body =~ s/([A-Z\W])$fname\(/$1call(/g;	# ���������� ��� ����������� �����
      $body =~ s/([A-Z\W])$fname/$1result/;	# ���, ��� �� ����� => ������ ����������
      push @rec_func, $body;		# ������� � ������ ����������� �������
      $src =~ s/$fname/frec$#rec_func/g;	# �������� � ������ ���������
      return $src;		# ������ ������ �� ����� ������ � ���������
    }
    $body =~ s/([A-Z\W])$fname(\W)/$1result$2/g;	# ����� ��������� ������������ � ����������� ����������, ��� � Delphi   
    
    # ������ ����� ��� ��������� ������� ����������������
    while ($src =~ m/(;([^;]*?[^a-z;])?)$fname(\(.*?\))(.*?);/)
    {
      $pos = length ($`);	# ����� �������, � ������� ����������� ����� ���������
      my $plus = length ($1);
      $facts = $3;		# ������ ����������� ����������
      $facts =~ s/^\(//;
      $facts =~ s/\)$//;
      
      $body2subst = subst_params($body, $formals, $facts);
      substr ($src, $pos+1, 0, $body2subst);		# ���������� ���� ������� ����� ��� ������, ��� ��� ���� �������
      substr ($src, $pos+length($body2subst)+$plus, length($fname)+length($facts)+2, 'result');	# ������ ����� �������
    }
  }
  $src;
}


# �������� ����������� �������� � �������� ������ � �������� ���������� !!
sub check_cond_brackets
{
  my $src = shift;
  my $kw1 = shift;
  my $kw2 = shift;
  
  my ($cond,$pos,$len);
  my @conds = $src =~ m/$kw1(.*?)$kw2/g;
  foreach (@conds)
  {
    $cond = $_;
    $pos = index($src, $_);	# �������, � ������� ���������� �������
    $len = length ($cond);
    my @extr = extract_bracketed($cond,'()');
    if ($extr[0] ne $cond)
    {
      $cond = '('.$cond.')';
      substr ($src, $pos, $len, $cond);
    }
  }
  
  $src;
}

# �������� �������� ����������� �������� !!
sub delete_obsolete_begins
{
  my $src = shift;

  $src =~ s/BEGIN(([^;])*?;)END;/$1/g;
  $src =~ s/^BEGIN/;BEGIN/;		# ����� �������� � ������ ������, ������� �������������� ����
  
  while ($src =~ m/;BEGIN/)		# ���� ������� ����� ����� �����, ����� BEGIN �� ����� ���� ; (�.�. ���� DO BEGIN, ����  THEN BEGIN)
  {
    my $beg = 'BEGIN'.$';		# ������� ������ ���������, ������������ � BEGIN
    
    my @extr = extract_tagged($beg, 'BEGIN', 'END', undef);	# �������� ���� ���� ���� �������
    
    my $n = index($src, ';BEGIN');
    substr($src, $n, 7, ';');			# ������� BEGIN
    $n += length($extr[0])-8;
    substr($src, $n, 3, '');	# ������� END
    substr($src, $n, 1) eq ';' and substr($src, $n, 1, '');	# ���� ����� END ����� ; � ���� �������
  }
  substr($src,0,1) eq ';' and substr($src,0,1,'');
  $src;  
}

# �������� ����� BEGIN-END � �������� �� � ������ �� sub !!
sub block2sub
{
  my $src = shift;
  $src = delete_obsolete_begins($src);
  $src =~ m/BEGIN/ or return $src;	# �����, ������������ � BEGIN ���
  my $beg = 'BEGIN'.$';		# ������� ������ ���������, ������������ � BEGIN
  
  my @extr = extract_tagged($beg, 'BEGIN', 'END', undef);	# �� �� ���� ����� �� ����������������� �������� BEGIN-END
  my $block = $extr[4];		# ��� ��, ��� ����� BEGIN � END
  my $fullblock = $extr[0];	# ��� ��� ������ � BEGIN � END
  
  $block = block2sub($block) while ($block =~ m/BEGIN/);	# ���������� ������� ��� ����� BEGIN-END ������ ������
  
  push @subs, $block;		# ���������� ���� � ����������� �������
  
  $id++;
  my $n=index($src, $fullblock);# �������� ��� ������������������ �� sub<�����>
  while ($n+1)	#������ ���������� ���������� ��� ������-�� �� ��������, ������� �������� �������� �� ��������� ���
  {
    substr($src, $n, length($fullblock), 'sub'.$id);
    $n=index($src, $fullblock);
  }
  
  $src;
}

#��������� ����� REPEAT � WHILE �� �����:
# REPEAT <body> UNTIL <cond>; => <body>; WHILE <cond> DO <body>; !!
sub repeat2while
{
  my $src = shift;
  $src =~ m/REPEAT/ or return $src;
  while ($src =~ m/(.)?REPEAT/)
  {
    my $symb = $1;	#��������� �� ������ ������ ������ ����� ������ (���� ��� ;, �� ����� ��� ������� �������)
    
    my $repeat = 'REPEAT'.$';
    
    my @extr = extract_tagged($repeat, 'REPEAT', '_REP', undef);
    my $body = $extr[4];		# ���� ����� ��� ����������� ��������
    my $fullblock = $extr[0];		# ���� �� ����������
    
    $body =~ s/UNTIL([^;]*?);$//;
    my $cond = $1;			# ������� �����
    
    $body = delete_obsolete_begins($body);
# ���������� ������� ����� REPEAT �� ���� ������ ����� (�����, �������, ����� �����
# �� ������, �� ����� ��� ��������, �� ���������, �.�. ���� ������������� ��� ���� �
# ������� ���� ����� ��� �� ���� ����)
    $body = repeat2while($body);
    $body = for2while($body);
    #$body = construct($body);
    if ($body =~ m/;.+?/g )
    {
      push @subs,$body;
      $id++;
      $body = 'sub'.$id;
    }
    my $n=index($src, $fullblock);	# �����, ��� ���� �����
    if ($symb eq ';' or !$symb)
    {
      substr($src, $n, length($fullblock), "$body;WHILENOT($cond)DO$body;")	# ��������
    }
    else
    {
      $id++;
      push @subs, "$body WHILENOT($cond)DO$body";
      substr($src, $n, length($fullblock), "sub$id");
    }
  }
  
  $src;
}

# ��������� ����� FOR � ����� WHILE !!
sub for2while
{
  my $src = shift;
  
  my ($for,$param,$init,$finish,$sub_id);

# for-downto-do sub
  while ($src =~ m/(FOR(\w*?):=(\w*?)DOWNTO(\w*?)DOsub(\d*?);)/g)
  {
    ($for,$param,$init,$finish,$sub_id) = ($1,$2,$3,$4,$5);
    
    $subs[$sub_id-1] .= "$param:=$param-1;";
    $src =~ s/$for/BEGIN$param:=$init;WHILE($param>$finish)DOsub$sub_id;END;/g;
  }  
# for-to-do sub
  while ($src =~ m/(FOR(\w*?):=(\w*?)TO(\w*?)DOsub(\d*?);)/g)
  {
    ($for,$param,$init,$finish,$sub_id) = ($1,$2,$3,$4,$5);
    
    $subs[$sub_id-1] .= "$param:=$param+1;";
    $src =~ s/$for/BEGIN$param:=$init;WHILE($param<$finish)DOsub$sub_id;END;/g;
  }  
  
# for-downto-do simple statement
  $src =~ s/FOR(\w*?):=(\w*?)DOWNTO(\w*?)DO(.*?);/BEGIN$1:=$2;WHILE($1>$3)DOBEGIN$4;$1:=$1-1;END;END;/g;
# for-to-do simple statement
  $src =~ s/FOR(\w*?):=(\w*?)TO(\w*?)DO(.*?);/BEGIN$1:=$2;WHILE($1<$3)DOBEGIN$4;$1:=$1+1;END;END;/g;
  $src;
}

# ������������������ ��������������, ������� ���� ����� �� ����� ��������� !!
sub change_code
{
  my $src = shift;
  
  $src = repeat2while($src);
  $src = for2while($src);
  $src = block2sub($src) while ($src =~m/BEGIN/);

  $src;
}

# ��� ����� ������ �������� ���	!!
sub create_new_code
{
  my $src = shift;

  $src =~ s/(UNTIL.*?;)/$1_REP/g;	#���������� ����� ���������� ������� ����� REPEAT
  
  $src = block2sub($src) while ($src =~m/BEGIN/);
  $src = check_cond_brackets($src, 'WHILE', 'DO');
  $src = check_cond_brackets($src, 'IF', 'THEN');
  $src = change_code($src);

  my $i;
  while ($i<$id)
  {
    $subs[$i] = change_code($subs[$i]);
    $i++;
  }
  $src;
}

# ��������� ��������� (���� � ���, �� ����� ����� ����� ����������)
sub compare_expr
{
  my ($expr1,$expr2) = @_;
  ($expr1=~/^sub/ or $expr2=~/^sub/) and return 0;
  
  my ($copy1, $copy2) = ($expr1, $expr2);
  $copy1 =~ s/(\Wfrec)(\d*?)/$1/g;	# ����������� �� � ���������� ������ ����������� �������
  $copy2 =~ s/(\Wfrec)(\d*?)/$1/g;
  
  # ���� �� �����������, ������ ����������
  ($copy1 eq $expr1 or $copy2 eq $expr2) and return ($expr1 eq $expr2)*2;	
  
  # ���� �����������
  $copy1 ne $copy2 and return 0;	# ���� ��� ���� ��������� ��������� ������, �� ������ ��������� ���� ������
  
  # ���� ��������� ���������, ������ ���������� �� ������� ��� �������
  my $m;
  while ($expr1=~/\Wfrec\d*?/ and $expr2=~/\Wfrec\d*?/)
  {
    $expr1=~s/(\Wfrec)(\d*?)/$1/;
    my $n1 = $2;
    $expr2=~s/(\Wfrec)(\d*?)/$1/;
    my $n2 = $2;
    
    $m += compare_subs('frec'.$n1, 'frec'.$n2)*2;
  }
  
}

# ��������� ���� �������������� �����������
sub compare
{
  my ($str1,$str2) = @_;

  $str1=~/^WHILE/ and $str2=~/^WHILE/ and return compare_WHILE($str1,$str2);
  $str1=~/^IF/ and $str2=~/^IF/ and return compare_IF($str1,$str2);
  $str1=~/^GOTO/ and $str2=~/^GOTO/ and return 2;
  $str1=~/^prec/ and $str2=~/^prec/ and return compare_subs($str1,$str2);
  compare_expr($str1,$str2);
}

# ���������� ����������� ���� WHILE
sub compare_WHILE
{
  my ($str1,$str2) = @_;

  $str1 =~ /^WHILE\((.*?)\)DO(.*?)$/;
  my ($cond1,$body1) = ($1,$2);


  $str2 =~ /^WHILE\((.*?)\)DO(.*?)$/;
  my ($cond2,$body2) = ($1,$2);

  my $cmp_cond = compare_expr($cond1,$cond2);
  my $cmp_body;
  $cmp_body = compare_subs($body1,$body2);
  #$body1 =~ /^sub(\d*)$/ and 
  #$body2 =~ /^sub(\d*)$/ and $cmp_body = compare_subs($body1,$body2)
  #  or $cmp_body = compare_expr($body1,$body2);
  
  $cmp_cond==2 and $cmp_body==$max and return 2;	# ���� ��������� � �������, � ���� �����, ������ ��� ��������� ���������
  !$cmp_cond and !$cmp_body and return 0;	# ���� ������ �� ���������, �� ������ ��� ������ ������
  1;  						# ����� ���������� � ��������, � ��������
}                                

#���������� ����������� ���� IF-THEN-ELSE
sub compare_IF
{
  my ($str1,$str2) = @_;

  $str1 =~ /^IF\((.*?)\)THEN(.*?)(ELSE(.*?))?$/;
  my ($cond1,$then1,$else1) = ($1,$2,$4);

  $str2 =~ /^IF\((.*?)\)THEN(.*?)(ELSE(.*?))?$/;
  my ($cond2,$then2,$else2) = ($1,$2,$4);

  my ($cmp_then, $cmp_else);
  
  if (compare_expr($cond1,$cond2))
  { 
    #$then1 =~ /^sub(\d*)$/ and
    #$then2 =~ /^sub(\d*)$/ and
    $cmp_then = compare_subs($then1, $then2) or
    #$cmp_then = compare_expr($then1,$then2);
    
    $cmp_then==$max and $cmp_then = 2;
    
    if ($else1 or $else2)
    {
    #  $else1 =~ /^sub(\d*)$/ and 
    #  $else2 =~ /^sub(\d*)$/ and 
    #  $cmp_else = compare_subs($else1,$else2) or
      $cmp_else = compare_expr($else1,$else2);
    }
  }

  !$cmp_then and !$cmp_else and return 0;
  $cmp_then==2 and $cmp_else==$max and return 2;
  1;
}

# ��������� ������������������ ����������
# ����: ���� ������������������ ����� ������� (��������� ��������� ;)
# �����: 
#	0 - ���������� ��� ������
#	1 - �������� ���������
#	2 - ��������� ���������
sub compare_subs
{
  my $sub1 = shift;
  my $sub2 = shift;

  $sub1 =~ /^sub(\d*)$/ and $sub1 = $subs[$1-1]; 
  $sub2 =~ /^sub(\d*)$/ and $sub2 = $subs[$1-1];
  
  $sub1 =~ /^prec(\d*)$/ and $sub1 = $prec[$1-1]; 
  $sub2 =~ /^prec(\d*)$/ and $sub2 = $prec[$1-1];

  $sub1 =~ /^frec(\d*)$/ and $sub1 = $frec[$1-1]; 
  $sub2 =~ /^frec(\d*)$/ and $sub2 = $frec[$1-1];
  
  $sub1 !~ /;/ and $sub2 !~ /;/ and return compare_expr($sub1, $sub2);

  my @stlist1 = split /;/, $sub1;
  my @stlist2 = split /;/, $sub2;

  my $s;
  my $comp;
  my $m;

  foreach $s (@stlist1)
  {
    $m += 2;
    foreach (0..$#stlist2)
    {
      if (my $c = compare($s,$stlist2[$_]))
      {
        splice (@stlist2,$_,1);
	$comp += $c;
	last;
      }
    }
  }
  $max = $m;
  $comp;
}

1;