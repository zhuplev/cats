# MathRender v1.2 by Matviyenko Victor  
package CATS::TeX::HTMLGen;
# ����� ������, ���������������: 
# ������������� ��������������� ������� ��� ��������� ������ � �����

use strict;
#use warnings;
use HTML::AsSubs;
#use Data::Dumper;

use CATS::TeX::Parser;

# ���� ������� �� ������� � AsSubs 
sub span{HTML::AsSubs::_elem('span', @_)}
# � �������� &tr(...) �� AsSubs �������� ������������
sub TR{HTML::AsSubs::_elem('tr', @_)}


#���, � ������� ������ ������ ��������
my %styles_; 

# metrics 

#my $normal_font_size; #�������� ������������
# ����� �������� � ������� � ������������ � ���������� ��� ��������� ��������
sub normfont() {1} 
sub minfont() {normfont * 0.7} #�������� ������������
sub maxfont() {normfont * 4} #�������� ������������
# ������ �������� ��� ������� >= 12pt, �������� ������, ������ ��� Opera �� ���������� ������ �����
sub min_border () {normfont/20} 
#��� ������� �������� ������� ������� ����� ������ ��������� ����� ����������
sub line_height($) {$_[0] * 1.5} 

# �������������� ��������
sub trim($) {sprintf "%.2f", $_[0]}
sub toem($) {trim ($_[0]).'em'}
# �������� � ���������:
sub toproc($) {(100 * trim $_[0]) . "\%"}
# ������ ������ �� ��������������� �����(��� ��������� ���� ������) 
sub undot($) {100 * trim $_[0]} 

sub max(@) 
{
    my $max = shift;
    $_ > $max and $max = $_ for @_;
    $max;
}
sub min(@) 
{
    my $min = shift;
    $_ < $min and $min = $_ for @_;
    $min;
} 

# ������� � �����: 
sub mkstyle
{
    #�� ���� ��������� ����� ���������� ����� ����� � ���� ������
    my(%attr) = @_;
    my($ret, $k, $v) ;
    $ret.= "$k: $v\; " while ($k, $v) = each %attr;
    $ret;
}
# ��������� � ������ ���� ������ �������
sub spoil ($) {"mat_$_[0]";} 
sub use_class
{
    # ���������� ������ ���, ����� ����� ��������������� ������� �����
    # ���������� ���, ������� ���������� ������������ �������� ���� make_table
    return () unless @_ = grep {$_} @_; 
    my @names = map spoil $_, @_; 
    return unless @names;
    exists $styles_{$_} or die "wrong class $_", caller for @names;
    (class => join " ", @names) ;
}
sub need_class 
{
    # ��������� ����� ����� � ����, ��� ������������ ������������� � ���������
    my($name, %attrib) = @_;
    $styles_{spoil $name} ||= {%attrib};
    $name; 
}
sub bordclass
{
    #������� ����� ������� � ������ �������
    my $side = shift;
    die "bad side $side " unless grep $side eq $_, qw/top left right bottom/;
    need_class "brd_$side", "border-$side" => "solid black",
}

sub make_table 
# ���������� ������� 
# in: attr ������ �� ��� ��������� 
# data ������ ������ �� ������
{
    sub extract_params
    # ��������� ���������(������ � ��������) �������, ������ ��� ������
    # �� ������ src � �������� � ��������������� ���� 
    {
        # ������ 2 ��������� ����� ���� ��������� ������
        #(��������� �������� ��������� � ������ �� ���������) 
        my($attr, $data, $src) = @_;
        # ���� ������ �� ���, ��������� �������� 
        if(ref $src->[0] eq "HASH") 
        {
            my $ta = shift @$src;
            @$attr{keys %$ta} = values %$ta;
        } 
        # ��������� ������(������ ������ �� ������� ��� ������ ���� ������) 
        push @$data, shift @$src while ref $src->[0] eq "ARRAY"; 
        push(@$data, +[shift @$src]) unless @$data;
    }
    #default table data: 
    my($attr, @rows) = {cellpadding => '0', cellspacing => '0'}; #, align => 'center'};
    extract_params $attr, \@rows, \@_;
    for my $row(@rows) 
    {
        #default row data:
        my($attr, @cells) = {}; 
        extract_params $attr, \@cells, $row; 
        for my $cell(@cells) 
        {
            #default cell data 
            my($attr, @data) = {}; 
            extract_params $attr, \@data, $cell; 
            # ���������� td 
            $cell = td $attr, map @$_, @data;
        }
        # ���������� tr 
        $row = TR $attr, @cells; 
    } 
    # ����������, ������������ �������, ������� ���������� �������
    table $attr, @rows;
}
sub initialize_styles 
{
    # � ���� ��� �� ���� ���������� ����������� �����, 
    %styles_= ();
    #�������� ��������� ����� �� ���������
    need_class "var", "font-family"=> "Times New Roman, Times, serif ", "font-style" => "italic";
}
# ���������
sub gen_styles 
{
    # ���������� ����� (��������������, ��� ��� ������ �������� c ������� gen_body ) 
    # �� ����������� windows-������� ������ ��� 2 �������� ������ ����� �������������� ��������
    my %family =('font-family' => join ",", 'Lucida Sans Unicode', 'Arial Unicode Ms') ; 
    
    my $core = mkstyle 
    (
      'font-size' => '100%',
      'line-height' => toproc line_height(1), 
    );
    
    my $tab_style = mkstyle 
    (
      'padding' => '0 0 0 1 ',
      'margin-top' => '0',
      'margin-bottom' => '0',
      'border' => '0 0 0 0',
    ) ; 
    my $box_style = mkstyle
    (
      '-moz-box-sizing' => 'border-box',
      'box-sizing' => 'border-box'
    );
    my $span_style = mkstyle 
    (
      %family,
      'font-style' => 'normal',
      'text-align' => 'center',
      'vertical-align' => 'bottom',
    ) ; 
    my $all_classes;
    $all_classes .= "\n .TeX .$_ {" . mkstyle(%{$styles_{$_}}) . "}" for(sort keys %styles_) ; 
    join " ",
    "\n .TeX table{ display: inline; $core $box_style $tab_style }", 
    "\n .TeX td { $core $box_style $span_style}",
    "\n .TeX span { $core $span_style}",
    "\n .TeX tr { $core }",
    "$all_classes\n";
}
sub gen_body 
{
    # ���������� html ��� ������
    # ���������� ������ html � ������� HTML::AsSubs
    my $string = shift;
    # �������� �������������� ������
    my $x = CATS::TeX::Parser::parse $string; 
    # ���������� �����(�������) 
    $x->rec_set_font(normfont) ; 
    initialize_styles;
    $x->genHTML;
}
sub gen_styles_html 
{
  style(gen_styles())->as_HTML('<>', "\t");
}
sub gen_html_part
{
  my $x = CATS::TeX::Parser::parse $_[0]; 
  $x->rec_set_font(normfont) ; 
  span({class => 'TeX'}, $x->genHTML)->as_HTML('<>', "\t");
}
sub gen_html 
{
    # ������� ��������� ������� 
    # �����e���:
    # ������ ���
    # font - ������ ������ (������ ������, �������� "12pt", "140%" ��� "medium")
    # step - ���������� ������� � HTML ���� (���������� �������)
    my $string = shift;
    my %par = @_;
    $par{step} ||= "\t";
    my $font_val = $par{font} || "larger";
    my $body = body {style => "font-size: $font_val" }, gen_body($string);
    my $src = html(head (style gen_styles()), $body) ;
    $src->as_HTML('<>', $par{step}) ; 
}
1;