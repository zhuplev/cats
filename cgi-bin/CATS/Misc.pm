package CATS::Misc;

BEGIN
{
    use Exporter;

    @ISA = qw(Exporter);
    @EXPORT = qw(
        cats_dir
        coalesce
        get_anonymous_uid
        split_fname
        initialize
        init_template
        init_listview_template
        generate_output
        http_header
        init_messages
        msg
        url_function
        url_f
        user_authorize
        templates_path
        escape_html
        order_by
        define_columns
        get_flag
        generate_password
        res_str
        attach_listview
        attach_menu
        fatal_error
        state_to_display
        balance_brackets
        balance_tags
        source_hash
        param_on
        save_settings
    );

    @EXPORT_OK = qw(
        $contest $t $sid $cid $uid $server_time
        $is_root $is_team $is_jury $is_virtual $virtual_diff_time
        $listview_name $init_time $settings);

    %EXPORT_TAGS = (all => [ @EXPORT, @EXPORT_OK ]);
}

use strict;
use warnings;

use HTML::Template;
#use CGI::Fast( ':standard' );
use CGI (':standard');
use Text::Balanced qw(extract_tagged extract_bracketed);

use CGI::Util qw(rearrange unescape escape);
use MIME::Base64;
use Storable;

#use FCGI;
use SQL::Abstract;
use Digest::MD5;
use Time::HiRes;
use Encode;

use CATS::DB;
use CATS::Constants;
use CATS::IP;
use CATS::Contest;

use vars qw(
    $contest $t $sid $cid $uid $team_name $server_time $dbi_error
    $is_root $is_team $is_jury $can_create_contests $is_virtual $virtual_diff_time
    $listview_name $col_defs $request_start_time $init_time $settings $enc_settings
);

my ($listview_array_name, @messages, $http_mime_type, %extra_headers);

my $cats_dir;
sub cats_dir()
{
    $cats_dir ||= $ENV{CATS_DIR} || '/home/zhuplev/Programming/Kur/cats/cgi-bin/';
}


sub coalesce { defined && return $_ for @_ }


sub get_anonymous_uid
{
    scalar $dbh->selectrow_array(qq~
        SELECT id FROM accounts WHERE login = ?~, undef, $cats::anonymous_login);
}


sub split_fname
{
    my $path = shift;

    my ($vol, $dir, $fname, $name, $ext);

    my $volRE = '(?:^(?:[a-zA-Z]:|(?:\\\\\\\\|//)[^\\\\/]+[\\\\/][^\\\\/]+)?)';
    my $dirRE = '(?:(?:.*[\\\\/](?:\.\.?$)?)?)';
    if ($path =~ m/($volRE)($dirRE)(.*)$/)
    {
        $vol = $1;
        $dir = $2;
        $fname = $3;
    }

    if ($fname =~ m/^(.*)(\.)(.*)/)
    {
        $name = $1;
        $ext = $3;
    }

    return ($vol, $dir, $fname, $name, $ext);
}


sub escape_html
{
    my $toencode = shift;

    $toencode =~ s/&/&amp;/g;
    $toencode =~ s/\'/&#39;/g;
    $toencode =~ s/\"/&quot;/g; #"
    $toencode =~ s/>/&gt;/g;
    $toencode =~ s/</&lt;/g;

    return $toencode;
}


sub escape_xml
{
    my $t = shift;

    $t =~ s/&/&amp;/g;
    $t =~ s/>/&gt;/g;
    $t =~ s/</&lt;/g;

    return $t;
}


sub http_header
{
    my ($type, $encoding, $cookie) = @_;

    CGI::header(-type => $type, -cookie => $cookie, -charset => $encoding, %extra_headers);
}


sub templates_path
{
    my $template = param('iface') || '';

    for (@cats::templates)
    {
        if ($template eq $_->{id})
        {
            return $_->{path};
        }
    }

    cats_dir() . $cats::templates[0]->{path};
}


sub init_messages
{
    return if @messages;
    my $msg_file = templates_path() . '/consts';

    open my $f, '<', $msg_file or
        fatal_error("Couldn't open message file: '$msg_file'.");
    binmode($f, ':raw');
    while (<$f>)
    {
        Encode::from_to($_, 'koi8-r', 'utf-8');

        $messages[$1] = $2 if m/^(\d+)\s+\"(.*)\"\s*$/;
    }
    close $f;
    1;
}


sub init_listview_params
{
    $_ && ref $_ eq 'HASH' or $_ = {} for $settings->{$listview_name};
    my $s = $settings->{$listview_name};
    $s->{search} = decode_utf8($s->{search} || '');

    $s->{page} = url_param('page') if defined url_param('page');

    my $search = param('search');
    if (defined $search)
    {
        $search = Encode::decode_utf8($search);
        if ($s->{search} ne $search)
        {
            $s->{search} = $search;
            $s->{page} = 0;
        }
    }

    if (defined url_param('sort'))
    {
        $s->{sort_by} = int(url_param('sort'));
        $s->{page} = 0;
    }

    if (defined url_param('sort_dir'))
    {
        $s->{sort_dir} = int(url_param('sort_dir'));
        $s->{page} = 0;
    }

    $s->{rows} ||= $cats::display_rows[0];
    my $rows = param('rows');
    if (defined $rows)
    {
        $s->{page} = 0 if $s->{rows} != $rows;
        $s->{rows} = 0 + $rows;
    }
}


sub fatal_error
{
    print STDOUT http_header('text/html', 'utf-8') . '<pre>' . escape_html( $_[0] ) . '</pre>';
    exit(1);
}


#my $template_file;
sub init_template
{
    my ($file_name) = @_;
    #if (defined $t && $template_file eq $file_name) { $t->param(tf=>1); return; }

    my $utf8_encode = sub
    {
        my $text_ref = shift;
        #Encode::from_to($$text_ref, 'koi8-r', 'utf-8');
        $$text_ref = Encode::decode('koi8-r', $$text_ref);
    };
    $http_mime_type =
        $file_name =~ /\.htm$/ ? 'text/html' :
        $file_name =~ /\.xml$/ ? 'application/xml' :
        $file_name =~ /\.ics$/ ? 'text/calendar' :
        die 'Unknown template extension';
    %extra_headers = ();
    %extra_headers = (-content_disposition => 'inline;filename=contests.ics') if $file_name =~ /\.ics$/;
    #$template_file = $file_name;
    $t = HTML::Template->new(
        filename => templates_path() . "/$file_name", cache => 1,
        die_on_bad_params => 0, filter => $utf8_encode, loop_context_vars => 1);
}


sub init_listview_template
{
    ($listview_name, $listview_array_name, my $file_name) = @_;

    init_listview_params;

    init_template($file_name);
}


sub selected_menu_item
{
    my $default = shift || '';
    my $href = shift;

    my ($pf) = ($href =~ /\?f=([a-z_]+)/);
    $pf ||= '';
    #my $q = new CGI((split('\?', $href))[1]);

    my $page = CGI::url_param('f');
    #my $pf = $q->param('f') || '';

    (defined $page && $pf eq $page) ||
    (!defined $page && $pf eq $default);
}


sub mark_selected
{
    my ($default, $menu) = @_;

    for my $i (@$menu)
    {
        if (selected_menu_item($default, $i->{href}))
        {
            $i->{selected} = 1;
            $i->{dropped} = 1;
        }

        my $submenu = $i->{submenu};
        for my $j (@$submenu)
        {
            if (selected_menu_item($default, $j->{href}))
            {
                $j->{selected} = 1;
                $i->{dropped} = 1;
            }
        }
    }
}


sub attach_menu
{
   my ($menu_name, $default, $menu) = @_;
   mark_selected($default, $menu);

   $t->param($menu_name => $menu);
}


sub res_str
{
    my $t = $messages[shift];
    sprintf($t, @_);
}


sub msg
{
    $t->param(message => res_str(@_));
}


sub gen_url_params
{
    my (%p) = @_;
    map { defined $p{$_} ? "$_=$p{$_}" : () } keys %p;
}


sub url_function
{
  my ($f, %p) = @_;
  join ';', "main.pl?f=$f", gen_url_params(%p);
}


sub url_f
{
    url_function(@_, sid => $sid, cid => $cid);
}


sub attach_listview
{
    my ($url, $fetch_row, $sth, $p) = @_;
    my @data = ();
    my $row_count = 0;
    $listview_name or die;
    my $s = $settings->{$listview_name};
    my $page = \$s->{page};
    my $start_row = ($$page || 0) * ($s->{rows} || 0);
    my $pp = $p->{page_params} || {};
    my $page_extra_params = join '', map ";$_=$pp->{$_}", keys %$pp;

    my $mask = undef;
    for (split(',', $s->{search}))
    {
        if ($_ =~ /(.*)\=(.*)/)
        {
            $mask = {} unless defined $mask;
            $mask->{$1} = $2;
        }
    }

    while (my %h = &$fetch_row($sth))
    {
	    last if $row_count > $cats::max_fetch_row_count;
        my $f = 1;
        if ($s->{search})
        {
            $f = 0;
            if (defined $mask)
            {
                $f = 1;
                for (keys %$mask)
                {
                    if (($h{$_} || '') ne ($mask->{$_} || ''))
                    {
                        $f = 0;
                        last;
                    }
                }
	        }
            else
            {
                for (keys %h)
                {
                    $f = 1 if defined $h{$_} && index($h{$_}, $s->{search}) != -1;
                }
            }
        }

        if ($f)
        {
            if ($row_count >= $start_row && $row_count < $start_row + $s->{rows})
            {
                push @data, { %h, odd => $row_count % 2 };
            }
            $row_count++;
        }
	
    }

    my $page_count = int($row_count / $s->{rows}) + ($row_count % $s->{rows} ? 1 : 0) || 1;

    $$page ||= 0;
    my $range_start = $$page - $$page % $cats::visible_pages;
    $range_start = 0 if ($range_start < 0);

    my $range_end = $range_start + $cats::visible_pages - 1;
    $range_end = $page_count - 1 if ($range_end > $page_count - 1);

    my @pages = map {{
        page_number => $_ + 1,
        href_page => "$url;page=$_$page_extra_params",
        current_page => $_ == $$page
    }} ($range_start..$range_end);

    $t->param(page => $$page, pages => \@pages, search => Encode::encode_utf8($s->{search}));

    my @display_rows = ();

    for (@cats::display_rows)
    {
        push @display_rows, {
            is_current => ($s->{rows} == $_),
            count => $_,
            text => $_
        };
    }

    if ($range_start > 0)
    {
        $t->param( href_prev_pages => "$url$page_extra_params;page=" . ($range_start - 1));
    }

    if ($range_end < $page_count - 1)
    {
        $t->param( href_next_pages => "$url$page_extra_params;page=" . ($range_end + 1));
    }

    $t->param(display_rows => [ @display_rows ]);
    $t->param($listview_array_name => [@data]);
}


sub order_by
{
    my $s = $settings->{$listview_name};
    defined $s->{sort_by} && $s->{sort_by} =~ /^\d+$/ && $col_defs->[$s->{sort_by}]
        or return '';
    sprintf 'ORDER BY %s %s',
        $col_defs->[$s->{sort_by}]{order_by}, ($s->{sort_dir} ? 'DESC' : 'ASC');
}


sub generate_output
{
    my ($output_file) = @_;
    defined $t or return;
    $contest->{time_since_start} or warn 'No contest from: ', $ENV{HTTP_REFERER} || '';
    $t->param(
        contest_title => $contest->{title},
        server_time => $server_time,
    	current_team_name => $team_name,
    	is_virtual => $is_virtual,
    	virtual_diff_time => $virtual_diff_time);

    my $elapsed_minutes = int(($contest->{time_since_start} - $virtual_diff_time) * 1440);
    if ($elapsed_minutes < 0)
    {
        $t->param(show_remaining_minutes => 1, remaining_minutes => -$elapsed_minutes);
    }
    elsif ($elapsed_minutes < 2 * 1440)
    {
        $t->param(show_elapsed_minutes => 1, elapsed_minutes => $elapsed_minutes);
    }
    else
    {
        $t->param(show_elapsed_days => 1, elapsed_days => int($elapsed_minutes / 1440));
    }

    if (defined $dbi_error)
    {
        $t->param(dbi_error => $dbi_error);
    }
    unless (param('notime'))
    {
        $t->param(request_process_time => sprintf '%.3fs',
            Time::HiRes::tv_interval($request_start_time, [ Time::HiRes::gettimeofday ]));
        $t->param(init_time => sprintf '%.3fs', $init_time || 0);
    }
    my $cookie = $uid ? undef : CGI::cookie(
        -name => 'settings', -value => encode_base64($enc_settings), -expires => '+1h');
    my $out = '';
    if (my $enc = param('enc'))
    {
        binmode(STDOUT, ':raw');
        $t->param(encoding => $enc);
        print STDOUT http_header($http_mime_type, $enc, $cookie);
        print STDOUT $out = Encode::encode($enc, $t->output, Encode::FB_XMLCREF);
    }
    else
    {
        binmode(STDOUT, ':utf8');
        $t->param(encoding => 'utf-8');
        print STDOUT http_header($http_mime_type, 'utf-8', $cookie);
        print STDOUT $out = $t->output;
    }
    if ($output_file)
    {
        open my $f, '>:utf8', $output_file
            or die "Error opening $output_file: $!";
        print $f $out;
    }
}


sub define_columns
{
    (my $url, my $default_by, my $default_dir, $col_defs) = @_;

    my $s = $settings->{$listview_name};
    $s->{sort_by} = $default_by if !defined $s->{sort_by} || $s->{sort_by} eq '';
    $s->{sort_dir} = $default_dir if !defined $s->{sort_dir} || $s->{sort_dir} eq '';

    for (my $i = 0; $i < @$col_defs; ++$i)
    {
        my $def = $col_defs->[$i];
        my $dir = 0;
        if ($s->{sort_by} eq $i)
        {
            $def->{'sort_' . ($s->{sort_dir} ? 'down' : 'up')} = 1;
            $dir = 1 - $s->{sort_dir};
        }
        $def->{href_sort} = "$url;sort=$i;sort_dir=$dir";
    }

    $t->param(col_defs => $col_defs);
}


sub get_flag
{
    my $country_id = shift || return;
    my ($country) = grep { $_->{id} eq $country_id } @cats::countries;
    $country or return;
    my $flag = defined $country->{flag} ? "$cats::flags_path/$country->{flag}" : undef;
    return ($country->{name}, $flag);
}


sub generate_password
{
    my @ch1 = ('e', 'y', 'u', 'i', 'o', 'a');
    my @ch2 = ('w', 'r', 't', 'p', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'z', 'x', 'c', 'v', 'b', 'n', 'm');

    my $passwd = '';

    for (1..3)
    {
        $passwd .= @ch1[rand(@ch1)];
        $passwd .= @ch2[rand(@ch2)];
    }

    return $passwd;
}


# ����������� ������������, ��������� ���� � ��������
sub init_user
{
    $sid = url_param('sid') || '';
    $is_root = 0;
    $can_create_contests = 0;
    $uid = undef;
    $team_name = undef;
    if ($sid ne '')
    {
        ($uid, $team_name, my $srole, my $last_ip, $enc_settings) = $dbh->selectrow_array(qq~
            SELECT id, team_name, srole, last_ip, settings FROM accounts WHERE sid = ?~, {}, $sid);
        if (!defined($uid) || $last_ip ne CATS::IP::get_ip())
        {
            init_template('main_bad_sid.htm');
            $sid = '';
            $t->param(href_login => url_f('login'));
        }
        else
        {
            $is_root = $srole == $cats::srole_root;
            $can_create_contests = $is_root || $srole == $cats::srole_contests_creator;
        }
    }
    if (!$uid)
    {
        $enc_settings = CGI::cookie('settings') || '';
        $enc_settings = decode_base64($enc_settings) if $enc_settings;
    }
    $enc_settings ||= '';
    # ��� ������������� ����� ������� ���������� ���������
    $settings = eval { Storable::thaw($enc_settings) } || {};
}


# ��������� ���������� � ������� ������� � ��������� ������� �� ���������
sub init_contest
{
    $cid = url_param('cid') || param('clist') || '';
    $cid =~ s/^(\d+).*$/$1/; # ��ң� ������ ������ �� clist
    if ($contest && ref $contest ne 'CATS::Contest') {
        use Data::Dumper;
        warn "Strange contest: $contest from ", $ENV{HTTP_REFERER} || '';
        warn Dumper($contest);
        undef $contest;
    }
    $contest ||= CATS::Contest->new;
    $contest->load($cid);
    $server_time = $contest->{server_time};
    $cid = $contest->{id};

    $virtual_diff_time = 0;
    # ����������� ������������ � �������
    $is_jury = 0;
    $is_team = 0;
    $is_virtual = 0;
    if (defined $uid)
    {
        ($is_team, $is_jury, $is_virtual, $virtual_diff_time) = $dbh->selectrow_array(qq~
            SELECT 1, is_jury, is_virtual, diff_time
            FROM contest_accounts WHERE contest_id = ? AND account_id = ?~, {}, $cid, $uid);
        $virtual_diff_time ||= 0;
        $is_jury ||= $is_root;

        # �� ������ ���� ������� ����� ������ ����� �����
        $is_team &&= $is_jury || $contest->has_started($virtual_diff_time);
    }
    if ($contest->{is_hidden} && !$is_team)
    {
        # ��� ������� ����������� ������� ������ ���������� ������ ���� �������������
        $contest->load(0);
        $server_time = $contest->{server_time};
        $cid = $contest->{id};
    }
}


sub save_settings
{
    if ($listview_name)
    {
        my $s = $settings->{$listview_name} ||= {};
        $s->{search} = Encode::encode_utf8($s->{search}) || undef;
        defined $s->{$_} or delete $s->{$_} for keys %$s;
    }
    my $new_enc_settings = Storable::freeze($settings);
    $new_enc_settings ne $enc_settings or return;
    $enc_settings = $new_enc_settings;
    $uid or return;
    $dbh->commit;
    $dbh->do(q~
        UPDATE accounts SET settings = ? WHERE id = ?~, undef,
        $new_enc_settings, $uid);
    $dbh->commit;
}


sub initialize
{
    $dbi_error = undef;
    init_messages;
    $t = undef;
    init_user;
    init_contest;
    $listview_name = '';
    $listview_array_name = '';
    $col_defs = undef;
}


sub state_to_display
{
    my ($state, $use_rejected) = @_;
    defined $state or die 'no state!';
    my %error = (
        wrong_answer =>          $state == $cats::st_wrong_answer,
        presentation_error =>    $state == $cats::st_presentation_error,
        time_limit_exceeded =>   $state == $cats::st_time_limit_exceeded,                                
        memory_limit_exceeded => $state == $cats::st_memory_limit_exceeded,
        runtime_error =>         $state == $cats::st_runtime_error,
        compilation_error =>     $state == $cats::st_compilation_error,
    );
    (
        not_processed =>         $state == $cats::st_not_processed,
        unhandled_error =>       $state == $cats::st_unhandled_error,
        install_processing =>    $state == $cats::st_install_processing,
        testing =>               $state == $cats::st_testing,
        accepted =>              $state == $cats::st_accepted,
        ($use_rejected ? (rejected => 0 < grep $_, values %error) : %error),
        security_violation =>    $state == $cats::st_security_violation,
        ignore_submit =>         $state == $cats::st_ignore_submit,
    );
}


sub balance_brackets
{
    my $text = shift;
    my @extr = extract_bracketed($text, '()');
    $extr[0];
}


sub balance_tags
{
    my ($text, $tag1, $tag2) = @_;
    my @extr = extract_tagged($text, $tag1, $tag2, undef);
    $extr[0];
}


sub source_hash
{
    Digest::MD5::md5_hex(Encode::encode_utf8($_[0]));
}


sub param_on
{
    return (param($_[0]) || '') eq 'on';
}


1;
