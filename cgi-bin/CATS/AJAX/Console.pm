package CATS::AJAX::Console;

use strict;
use warnings;
use Time::Local;

use CATS::IP;
use CATS::AJAX::Abstract; 

use Encode; #deprecated

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


sub make_response {
    my $self = shift;
    my $dbh = $self->{dbh};
    my ($is_root, $is_jury, $is_team, $cid, $uid, $contest) = @{$self->{var}}{qw~is_root is_jury is_team cid uid contest~};
    my $dummy_account_block = q~
        CAST(NULL AS INTEGER) AS team_id,
        CAST(NULL AS VARCHAR(200)) AS team_name,
        CAST(NULL AS VARCHAR(30)) AS country,
        CAST(NULL AS VARCHAR(100)) AS last_ip,
        CAST(NULL AS INTEGER) AS caid,
        CAST(NULL AS INTEGER) AS contest_id
    ~;
    my %console_select = (
        run => q~
            1 AS rtype,
            R.submit_time AS rank,
            CATS_DATE(R.submit_time) AS submit_time,
            CATS_DATE(R.result_time) AS last_console_update,
            R.id AS id,
            R.state AS request_state,
            R.failed_test AS failed_test,
            P.id AS problem_id,
            P.title AS problem_title,
            CAST(NULL AS INTEGER) AS clarified,
            D.t_blob AS question,
            D.t_blob AS answer,
            D.t_blob AS jury_message,
            A.id AS team_id,
            A.team_name AS team_name,
            A.country AS country,
            A.last_ip AS last_ip,
            CA.id,
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
            CAST(NULL AS INTEGER) AS request_state,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS problem_id,
            CAST(NULL AS VARCHAR(200)) AS problem_title,
            Q.clarified AS clarified,
            Q.question AS question,
            Q.answer AS answer,
            D.t_blob AS jury_message,
            A.id AS team_id,
            A.team_name AS team_name,
            A.country AS country,
            A.last_ip AS last_ip,
            CA.id,
            CA.contest_id~,
        message => q~
            3 AS rtype,
            M.send_time AS rank,
            CATS_DATE(M.send_time) AS submit_time,
            CATS_DATE(M.send_time) AS last_console_update,
            M.id AS id,
            CAST(NULL AS INTEGER) AS request_state,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS problem_id,
            CAST(NULL AS VARCHAR(200)) AS problem_title,
            CAST(NULL AS INTEGER) AS clarified,
            D.t_blob AS question,
            D.t_blob AS answer,
            M.text AS jury_message,
            A.id AS team_id,
            A.team_name AS team_name,
            A.country AS country,
            A.last_ip AS last_ip,
            CA.id,
            CA.contest_id
        ~,
        broadcast => qq~
            4 AS rtype,
            M.send_time AS rank,
            CATS_DATE(M.send_time) AS submit_time,
            CATS_DATE(M.send_time) AS last_console_update,
            M.id AS id,
            CAST(NULL AS INTEGER) AS request_state,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS problem_id,
            CAST(NULL AS VARCHAR(200)) AS problem_title,
            CAST(NULL AS INTEGER) AS clarified,
            D.t_blob AS question,
            D.t_blob AS answer,
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
            C.is_official AS request_state,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS problem_id,
            C.title AS problem_title,
            CAST(NULL AS INTEGER) AS clarified,
            D.t_blob AS question,
            D.t_blob AS answer,
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
            C.is_official AS request_state,
            CAST(NULL AS INTEGER) AS failed_test,
            CAST(NULL AS INTEGER) AS problem_id,
            C.title AS problem_title,
            CAST(NULL AS INTEGER) AS clarified,
            D.t_blob AS question,
            D.t_blob AS answer,
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
    $_ = sprintf($_, " >= TIMESTAMP '$self->{var}->{last_update_timestamp}'") for values %need_update;

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
        $c->execute(@cid, @cid, @cid);
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
        $c->execute($cid, $uid, $cid, $uid, $cid, $uid);
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
        $c->execute($cid);
    }
    
    my (@submission, @contests, @messages);
    my @rtype_ref = (\@submission, \@messages, \@messages, \@messages, \@contests, \@contests);
    
    my ($problems, $teams) = ({}, {});
    
    while (my @row = $c->fetchrow_array) {
        my ($rtype, $rank, $submit_time, $last_console_update, $id, $request_state, $failed_test, 
            $problem_id, $problem_title, $clarified, $question, $answer, $jury_message,
            $team_id, $team_name, $country_abb, $last_ip, $caid, $contest_id
        ) = @row;
        
        #$request_state = -1 unless defined $request_state; #просто не нужен, т.к. убили $request_state в запросе результатов попыток
        (my $last_ip_short, $last_ip)  = CATS::IP::short_long(CATS::IP::filter_ip($last_ip));
        --$rtype;
        my %current_row = (
            rtype =>                $rtype,
            is_official =>          $request_state,
            clarified =>            Encode::decode('UTF-8', $clarified, Encode::FB_QUIET), #It should use UTF-8 encoding as default
            'time' =>               $submit_time,
            last_console_update =>  $last_console_update,
            problem_id =>           $problem_id,
            
            contest_title =>        $rtype >= 4 ? Encode::decode('UTF-8', $problem_title, Encode::FB_QUIET) : undef,
                #It should use UTF-8 encoding as default
                #Небольшая магия: для задачи тут мы передаём id, поэтому $problem_title нам совсем не нужен, но
                #в него передаётся имя турнира для данных о начале и конце турниров
            
            submit_status =>
                # security: во время соревноваиня не показываем участникам
                # конкретные результаты других команд, а только accepted/rejected
                !$rtype ?
                    ($contest->{time_since_defreeze} <= 0 && !$is_jury &&
                    $request_state > $cats::request_processed  && $request_state != $cats::st_accepted &&
                    (!$is_team || !$team_id || $team_id != $uid)) ? $cats::st_rejected : $request_state
                :
                    undef,
            failed_test =>    $failed_test,
            question_text =>        Encode::decode('UTF-8', $question, Encode::FB_QUIET), #It should use UTF-8 encoding as default
            answer_text =>          Encode::decode('UTF-8', $answer, Encode::FB_QUIET), #It should use UTF-8 encoding as default
            message_text =>         Encode::decode('UTF-8', $jury_message, Encode::FB_QUIET), #It should use UTF-8 encoding as default
            team_id =>              $team_id,
            last_ip =>              $self->{var}->{is_jury} ? $last_ip : undef,
            last_ip_short =>        $self->{var}->{is_jury} ? $last_ip_short : undef,
            id      =>              $id,
            contest_id =>           $self->{var}->{is_root} ? $contest_id : undef,
        );
        
        $problems->{$problem_id} = Encode::decode('UTF-8', $problem_title , Encode::FB_QUIET) if $problem_id; #It should use UTF-8 encoding as default
        $teams->{$team_id} = Encode::decode('UTF-8', $team_name , Encode::FB_QUIET) if $team_id; #It should use UTF-8 encoding as default
        
        for (keys %current_row) {
            delete $current_row{$_} if !defined $current_row{$_} || $current_row{$_} eq '';
        }
        
        push @{$rtype_ref[$rtype]}, \%current_row;
    }
    
    $self->set_specific_param('submissions', \@submission);
    $self->set_specific_param('contests', \@contests);
    $self->set_specific_param('messages', \@messages);
    $self->set_specific_param('problems', $problems);
    
    $self->set_specific_param('teams', $teams);
}


1;
