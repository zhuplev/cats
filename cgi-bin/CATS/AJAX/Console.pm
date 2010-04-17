package CATS::AJAX::Console;

use strict;
use warnings;
use Time::Local;

use CATS::IP;
use CATS::AJAX::Abstract; 

use Encode;

our @ISA = qw~CATS::AJAX::Abstract~;


sub required_json_params {
    return qw~last_update_timestamp~;
}


sub data_validate {
    my $self = shift;
    $self->{var}->{last_update_timestamp} =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d).(\d{4})$/;
    eval {
        timelocal($6, $5, $4, $3, $2, $1);
        1;
    } or die 'invalid_last_update_timestamp';
}

my ($cons_run, $cons_question, $cons_message, $cons_broadcast, $cons_contest_start, $cons_contest_finish) = (0..5);

sub make_response {
    my $self = shift;
    my $dbh = $self->{dbh};
    my ($is_root, $is_jury, $is_team, $cid, $uid, $contest) = @{$self->{var}}{qw~is_root is_jury is_team cid uid contest~};
    my $dummy_account_block = q~
        CAST(NULL AS INTEGER) AS team_id,
        CAST(NULL AS VARCHAR(200)) AS team_name,
        CAST(NULL AS VARCHAR(100)) AS last_ip,
        CAST(NULL AS INTEGER) AS contest_id
    ~;
    
    my %console_select = (
        run => q~
            1 AS rtype,
            R.submit_time AS rank,
            CATS_DATE(R.submit_time) AS submit_time,
            CATS_DATE(R.result_time) AS last_console_update,
            R.id AS id,
            R.state AS state_or_official,
            R.failed_test AS failed_test,
            P.id AS pid_or_clarified,
            P.title AS title,
            D.t_blob AS question,
            D.t_blob AS jury_message,
            A.id AS team_id,
            A.team_name AS team_name,
            A.last_ip AS last_ip,
            R.contest_id
            FROM reqs R
            INNER JOIN problems P ON R.problem_id=P.id
            INNER JOIN accounts A ON R.account_id=A.id
            INNER JOIN contests C ON R.contest_id=C.id
            INNER JOIN contest_accounts CA ON CA.account_id=A.id AND CA.contest_id=R.contest_id,
            dummy_table D
        ~,
        question => q~
            2 AS rtype,
            Q.submit_time AS rank,
            CATS_DATE(Q.submit_time) AS submit_time,
            CATS_DATE(COALESCE(Q.clarification_time, Q.submit_time)) AS last_console_update,
            Q.id AS id,
            CAST(NULL AS INTEGER) AS state_or_official,
            CAST(NULL AS INTEGER) AS failed_test,
            Q.clarified AS pid_or_clarified,
            CAST(NULL AS VARCHAR(200)) AS title,
            Q.question AS question,
            Q.answer AS jury_message,
            A.id AS team_id,
            A.team_name AS team_name,
            A.last_ip AS last_ip,
            CA.contest_id~,
        message => q~
            3 AS rtype,
            M.send_time AS rank,
            CATS_DATE(M.send_time) AS submit_time,
            CATS_DATE(M.send_time) AS last_console_update,
            M.id AS id,
            CAST(NULL AS INTEGER) AS state_or_official,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS pid_or_clarified,
            CAST(NULL AS VARCHAR(200)) AS title,
            D.t_blob AS question,
            M.text AS jury_message,
            A.id AS team_id,
            A.team_name AS team_name,
            A.last_ip AS last_ip,
            CA.contest_id
        ~,
        broadcast => qq~
            4 AS rtype,
            M.send_time AS rank,
            CATS_DATE(M.send_time) AS submit_time,
            CATS_DATE(M.send_time) AS last_console_update,
            M.id AS id,
            CAST(NULL AS INTEGER) AS state_or_official,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS pid_or_clarified,
            CAST(NULL AS VARCHAR(200)) AS title,
            D.t_blob AS question,
            M.text AS jury_message,
            $dummy_account_block
            FROM messages M, dummy_table D
        ~,
        contest_start => qq~
            5 AS rtype,
            C.start_date AS rank,
            CATS_DATE(C.start_date) AS submit_time,
            CATS_DATE(C.start_date) AS last_console_update,
            C.id AS id,
            C.is_official AS state_or_official,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS pid_or_clarified,
            C.title AS title,
            D.t_blob AS question,
            D.t_blob AS jury_message,
            $dummy_account_block
            FROM contests C, dummy_table D
        ~,
        contest_finish => qq~
            6 AS rtype,
            C.finish_date AS rank,
            CATS_DATE(C.finish_date) AS submit_time,
            CATS_DATE(C.finish_date) AS last_console_update,
            C.id AS id,
            C.is_official AS state_or_official,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS pid_or_clarified,
            C.title AS title,
            D.t_blob AS question,
            D.t_blob AS jury_message,
            $dummy_account_block
            FROM contests C, dummy_table D
        ~,
    );
    
    $_ = ' FIRST 30 ' . $_ for values %console_select; #=)
    
    
    my %need_update = (
        run => q~
            (R.result_time %s)
        ~,
        question => q~
            (COALESCE(Q.clarification_time, Q.submit_time) %s)
        ~,
        message => q~
            (M.send_time %s)
        ~,
        broadcast => q~
            (M.send_time %s)
        ~,
        contest_start => q~
            (C.start_date %s)
        ~,
        contest_finish => q~
            (C.finish_date %s)
        ~,
    );
    $_ = sprintf($_, " >= ?") for values %need_update;

    my $contest_start_finish = '';
    my $hidden_cond = $is_root ? '' : ' AND C.is_hidden = 0';
    $contest_start_finish = qq~
        UNION
            SELECT
                $console_select{contest_start}
                WHERE $need_update{contest_start} AND (C.start_date < CURRENT_TIMESTAMP)$hidden_cond
          UNION
            SELECT
                $console_select{contest_finish}
                WHERE $need_update{contest_finish} AND (C.finish_date < CURRENT_TIMESTAMP)$hidden_cond
    ~;
    
    my $broadcast = qq~
      UNION
        SELECT
            $console_select{broadcast}
            WHERE $need_update{broadcast} AND M.broadcast = 1~;
    
    my $c;
    my $luts = $self->{var}->{last_update_timestamp};
    my @luts3 = ($luts) x 3;
    if ($is_jury) {
        my $runs_filter = $is_root ? '' : ' AND C.id = ?';
        my $msg_filter = $is_root ? '' : ' AND CA.contest_id = ?';
        my @cid = $is_root ? () : ($cid);
        $c = $dbh->prepare(qq~
            SELECT
                $console_select{run}
                WHERE $need_update{run} $runs_filter
            UNION
            SELECT
                $console_select{question}
                FROM questions Q, contest_accounts CA, dummy_table D, accounts A
                WHERE $need_update{question} AND
                Q.account_id=CA.id AND A.id=CA.account_id$msg_filter
            UNION
            SELECT
                $console_select{message}
                FROM messages M, contest_accounts CA, dummy_table D, accounts A
                WHERE $need_update{message} AND
                M.account_id = CA.id AND A.id = CA.account_id$msg_filter
            $broadcast
            $contest_start_finish
            ORDER BY 2 DESC~);
        $c->execute(($luts, @cid) x 3, @luts3);
    } elsif ($is_team) {
        $c = $dbh->prepare(qq~
            SELECT
                $console_select{run}
                WHERE $need_update{run} AND
                    C.id=? AND CA.is_hidden=0 AND
                    (A.id=? OR R.submit_time < C.freeze_date OR CURRENT_TIMESTAMP > C.defreeze_date)
            UNION
            SELECT
                $console_select{question}
                FROM questions Q, contest_accounts CA, dummy_table D, accounts A
                WHERE $need_update{question} AND
                    Q.account_id=CA.id AND CA.contest_id=? AND CA.account_id=A.id AND A.id=?
            UNION
            SELECT
                $console_select{message}
                FROM messages M, contest_accounts CA, dummy_table D, accounts A 
                WHERE $need_update{message} AND
                    M.account_id=CA.id AND CA.contest_id=? AND CA.account_id=A.id AND A.id=?
            $broadcast
            $contest_start_finish
            ORDER BY 2 DESC~);
        $c->execute(($luts, $cid, $uid) x 3, @luts3);
    } else {
        $c = $dbh->prepare(qq~
            SELECT
                $console_select{run}
                WHERE $need_update{run} AND
                    R.contest_id=? AND CA.is_hidden=0 AND 
                    (R.submit_time < C.freeze_date OR CURRENT_TIMESTAMP > C.defreeze_date)
            $broadcast
            $contest_start_finish
            ORDER BY 2 DESC~);
        $c->execute($luts, $cid, @luts3);
    }
    
    my (@submission, @contests, @messages);
    my @rtype_ref = (\@submission, \@messages, \@messages, \@messages, \@contests, \@contests);
    
    my ($problems, $teams) = ({}, {});
        
    my %alias_link = (
        submit_state => 'state_or_official',
        is_official => 'state_or_official',
        problem_id => 'pid_or_clarified',
        clarified => 'pid_or_clarified',
        answer => 'jury_message',
        message => 'jury_message',
        'time' => 'submit_time',
    );

    while (my $r = $c->fetchrow_hashref) {
        #$_ = Encode::decode_utf8 $_ for values %{$r}; #DBD::InterBase driver doesn't work with utf-8
        @{$r}{qw/last_ip_short last_ip/} = CATS::IP::short_long(CATS::IP::filter_ip($r->{last_ip}));
        
        my %current_row = ();
        my $add_row = sub {
            my $param = shift;
            $current_row{$param} = $r->{$param} || $r->{$alias_link{$param}};
        };
        
        $add_row->($_) for qw/time last_console_update failed_test question team_id id/;
            
        $current_row{rtype} = --$r->{rtype};
        $current_row{title} = $r->{title} if $r->{rtype} >= $cons_contest_start;
        
        !$r->{rtype} and $add_row->($_) for qw/problem_id/;
        $r->{rtype} == $cons_question and $add_row->($_) for qw/answer clarified/;
        $r->{rtype} >= $cons_message and $add_row->($_) for qw/message/;
        $r->{rtype} >= $cons_contest_start and $add_row->($_) for qw/is_official/;
        
        my $rss = $r->{$alias_link{submit_state}}; #alias
        $current_row{submit_state} = 
            # security: во время соревноваиня не показываем участникам
            # конкретные результаты других команд, а только accepted/rejected
            !$r->{rtype} ?
                ($contest->{time_since_defreeze} <= 0 && !$is_jury &&
                $rss > $cats::request_processed  && $rss != $cats::st_accepted &&
                (!$is_team || !$r->{team_id} || $r->{team_id} != $uid)) && !$self->{var}->{contest}->{ctype} ?
                    $cats::st_rejected
                :
                    $rss
            :
                undef;
        $self->{var}->{is_jury} and $add_row->($_) for qw/last_ip last_ip_short/;
        $self->{var}->{is_root} and $add_row->($_) for qw/contest_id/;
        
        $problems->{$r->{pid_or_clarified}} = $r->{title} if $r->{pid_or_clarified} && $r->{title};
        $teams->{$r->{team_id}} = $r->{team_name} if $r->{team_id};
        
        !defined $current_row{$_} || $current_row{$_} eq '' and delete $current_row{$_} for keys %current_row;
        $_ =~ /^\d{1,9}$/ and $_ = 0 + $_ for values %current_row; #cast to int type
        
        push @{$rtype_ref[$r->{rtype}]}, \%current_row;
    }
    
    $self->set_specific_param('submissions', \@submission);
    $self->set_specific_param('contests', \@contests);
    $self->set_specific_param('messages', \@messages);
    $self->set_specific_param('problems', $problems);
    
    $self->set_specific_param('teams', $teams);
}


1;
