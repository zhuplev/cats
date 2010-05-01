package CATS::AJAX::Console;

use strict;
use warnings;
use Time::Local;

use CATS::IP;
use CATS::AJAX::Abstract; 

use Encode;

our @ISA = qw~CATS::AJAX::Abstract~;


sub required_json_params { #deprecated
    return qw~~;
}


sub optional_json_params {
    return qw~fragments~;
}


sub timestamp_validate {
    my ($self, $value, $msg) = @_;
    $value =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d).(\d{4})$/;
    eval {
        timelocal($6, $5, $4, $3, $2-1, $1);
        1;
    } or die "invalid value: '$value' " . ($msg || '');
}


sub timestamp_increase {
    my ($self, $timestamp) = @_;
    return $self->timestamp_change($timestamp, 1);
}


sub timestamp_decrease {
    my ($self, $timestamp) = @_;
    return $self->timestamp_change($timestamp, -1);
}


sub timestamp_change {
    my ($self, $timestamp, $d) = @_;
    my $timestamp_format = '%0.2d-%0.2d-%0.2d %0.2d:%0.2d:%0.2d.%0.4d';
    $timestamp =~ /^(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d).(\d{4})$/;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $msec) = ($6, $5, $4, $3, $2, $1, undef, undef, undef, $7);
    my $q = $msec + $d;
    if ($msec + $d < 0 || $msec + $d > 10000) {
        ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(timelocal($sec, $min, $hour, $mday, $mon, $year) + $d);
        $year += 1900;
        $msec = (10000 * 10000 + $d) % 10000;
    } else {
        $msec += $d;
    }
    $timestamp = sprintf $timestamp_format, $year, $mon, $mday, $hour, $min, $sec, $msec;
    return $timestamp;

}


sub var_timestamp_validate { #deprecated
    my ($self, $param_name) = @_;
    eval {
        $self->timestamp_validate($self->{var}->{$param_name});
        1;
    } or die "invalid $param_name";
}


sub data_validate {
    my $self = shift;
    for (qw~submissions contests messages~) {
        for (@{$self->{var}->{fragments}->{$_}}) {
            $self->timestamp_validate($_->{last_update_timestamp});
            $_->{type} =~ /^(top|between|before)$/ or die "Unknown request type: '$_->{type}'";
            if ($1 eq 'between') {
                $_->{l} =~ /^(t|e)$/ or die "Unknown request 'less' param: '$_->{l}'"; #lt | le
                $_->{g} =~ /^(t|e)$/ or die "Unknown request 'greater' param: '$_->{g}'"; #gt | ge
                $self->timestamp_validate($_->{since}, "as 'since' param");
                $self->timestamp_validate($_->{to},  "as 'to' param");
                $_->{since} le $_->{to} or die "'since' param is allowed to be greater than 'to' param";
            }
            if ($1 eq 'before') {
                $_->{l} =~ /^(t|e)$/ or die "Unknown request less param: '$_->{l}'"; #lt | le
                $self->timestamp_validate($_->{to},  "as 'to' param");
            }
            $_->{length} and ($_->{length} =~ /^\d{1,3}+$/ or die "Invalid 'length' param: '$_->{length}'");
            $_->{length} ||= 0;
            $_->{length} > 0 and $_->{length} <= $cats::max_fragment_row_count or $_->{length} = $cats::max_fragment_row_count;
        }
    }
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
            R.submit_time AS submit_time,
            R.result_time AS last_console_update,
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
            Q.submit_time AS submit_time,
            COALESCE(Q.clarification_time, Q.submit_time) AS last_console_update,
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
            M.send_time AS submit_time,
            M.send_time AS last_console_update,
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
            M.send_time AS submit_time,
            M.send_time AS last_console_update,
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
            C.start_date AS submit_time,
            C.start_date AS last_console_update,
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
            C.finish_date AS submit_time,
            C.finish_date AS last_console_update,
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
    
    $_ = " FIRST ? " . $_ for values %console_select; #=)
    
    
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
    
    my %fragment_time = (
        run => q~
            R.submit_time
        ~,
        question => q~
            Q.submit_time
        ~,
        message => q~
            M.send_time
        ~,
        broadcast => q~
            M.send_time
        ~,
        contest_start => q~
            C.start_date
        ~,
        contest_finish => q~
            C.finish_date
        ~,
    );
    my %fragment_cond_variant = (
        before => { map { $_ => "($fragment_time{$_} <= ?) AND" } keys %fragment_time },
        between => { map { $_ => "($fragment_time{$_} >= ? AND $fragment_time{$_} <= ?) AND" } keys %fragment_time },
        top => { map { $_ => "" } keys %fragment_time },
        none => { map { $_ => "1 < 0 AND" } keys %fragment_time },
    );
    
    my ($problems, $teams, $res_seq) = ({}, {}, []);
    
    my $i = 0;
    my $frs = $self->{var}->{fragments};
    my @kinds = qw~submissions contests messages~;
    while ($i < @{$frs->{submissions}} || $i < @{$frs->{contests}} || $i < @{$frs->{messages}}) {
        my %k = map {
            $_ => $i < @{$frs->{$_}}
                ? $frs->{$_}->[$i]
                : {
                    type => 'none',
                    last_update_timestamp => '2000-01-01 00:00:00.0000',
                    length => $cats::max_fragment_row_count,
                  }
        } @kinds;
        my %fragment_cond;
        for (@kinds) {
            no warnings 'uninitialized';
            $fragment_cond{$_} = $fragment_cond_variant{$k{$_}->{type}};
            $k{$_}->{to} = $self->timestamp_decrease($k{$_}->{to}) if $k{$_}->{l} eq 't';
            $k{$_}->{since} = $self->timestamp_increase($k{$_}->{since}) if $k{$_}->{g} eq 't';
        }
        
        my ($sc, $cc, $mc) = map $fragment_cond{$_}, @kinds;
        
        my $get_params = sub {
            my ($kv) = @_;
            my %v = (
                'before' => [$kv->{to}],
                'between' => [$kv->{since}, $kv->{to}],
                'top' => [],
                'none' => [],
            );
            return @{$v{$kv->{type}}};
        };
        
        my @sp = $get_params->($k{submissions});
        my @cp = $get_params->($k{contests});
        my @mp = $get_params->($k{messages});
        
        my $contest_start_finish = '';
        my $hidden_cond = $is_root ? '' : ' AND C.is_hidden = 0';
        $contest_start_finish = qq~
            UNION
            SELECT * FROM ( SELECT
                $console_select{contest_start}
                WHERE $cc->{contest_start} $need_update{contest_start} AND (C.start_date < CURRENT_TIMESTAMP)$hidden_cond
                ORDER BY 2 DESC
            )
            UNION
            SELECT * FROM ( SELECT
                $console_select{contest_finish}
                WHERE $cc->{contest_finish} $need_update{contest_finish} AND (C.finish_date < CURRENT_TIMESTAMP)$hidden_cond
                ORDER BY 2 DESC
            )
        ~;
        
        my $broadcast = qq~
            UNION
            SELECT * FROM ( SELECT
                $console_select{broadcast}
                WHERE $mc->{broadcast} $need_update{broadcast} AND M.broadcast = 1
                ORDER BY 2 DESC
            )
        ~;
        my $dtst;
        my ($lutss, $lengths, $lutsc, $lengthc, $lutsm, $lengthm) = map {$k{$_}->{last_update_timestamp}, $k{$_}->{length}+1} @kinds;
        my %length = map {$_ => $k{$_}->{length}} @kinds;
        my @bcp = ($lengthm, @mp, $lutsm, ($lengthc, @cp, $lutsc) x 2);
        if ($is_jury) {
            my $runs_filter = $is_root ? '' : ' AND C.id = ?';
            my $msg_filter = $is_root ? '' : ' AND CA.contest_id = ?';
            my @cid = $is_root ? () : ($cid);
            $dtst = $dbh->prepare(qq~
                SELECT * FROM ( SELECT
                    $console_select{run}
                    WHERE $sc->{run} $need_update{run} $runs_filter
                    ORDER BY 2 DESC
                )
                UNION
                SELECT * FROM ( SELECT
                    $console_select{question}
                    FROM questions Q, contest_accounts CA, dummy_table D, accounts A
                    WHERE $mc->{question} $need_update{question} AND
                    Q.account_id=CA.id AND A.id=CA.account_id$msg_filter
                    ORDER BY 2 DESC
                )
                UNION
                SELECT * FROM ( SELECT
                    $console_select{message}
                    FROM messages M, contest_accounts CA, dummy_table D, accounts A
                    WHERE $mc->{message} $need_update{message} AND
                    M.account_id = CA.id AND A.id = CA.account_id$msg_filter
                    ORDER BY 2 DESC
                )
                $broadcast
                $contest_start_finish
                ORDER BY 2 DESC~);
            $dtst->execute($lengths, @sp, $lutss, @cid, ($lengthm, @mp, $lutsm, @cid) x 2, @bcp);
        } elsif ($is_team) {
            $dtst = $dbh->prepare(qq~
                SELECT * FROM ( SELECT
                    $console_select{run}
                    WHERE $sc->{run} $need_update{run} AND
                        C.id=? AND CA.is_hidden=0 AND
                        (A.id=? OR R.submit_time < C.freeze_date OR CURRENT_TIMESTAMP > C.defreeze_date)
                    ORDER BY 2 DESC
                )
                UNION
                SELECT * FROM ( SELECT
                    $console_select{question}
                    FROM questions Q, contest_accounts CA, dummy_table D, accounts A
                    WHERE $mc->{question} $need_update{question} AND
                        Q.account_id=CA.id AND CA.contest_id=? AND CA.account_id=A.id AND A.id=?
                    ORDER BY 2 DESC
                )
                UNION
                SELECT * FROM ( SELECT
                    $console_select{message}
                    FROM messages M, contest_accounts CA, dummy_table D, accounts A 
                    WHERE $mc->{message} $need_update{message} AND
                        M.account_id=CA.id AND CA.contest_id=? AND CA.account_id=A.id AND A.id=?
                    ORDER BY 2 DESC
                )
                $broadcast
                $contest_start_finish
                ORDER BY 2 DESC~);
            $dtst->execute($lengths, @sp, $lutss, $cid, $uid, ($lengthm, @mp, $lutsm, $cid, $uid) x 2, @bcp);
        } else {
            $dtst = $dbh->prepare(qq~
                SELECT
                    $console_select{run}
                    WHERE $sc->{run} $need_update{run} AND
                        R.contest_id=? AND CA.is_hidden=0 AND 
                        (R.submit_time < C.freeze_date OR CURRENT_TIMESTAMP > C.defreeze_date)
                    ORDER BY 2 DESC
                )
                $broadcast
                $contest_start_finish
                ORDER BY 2 DESC~);
            $dtst->execute($lengths, @sp, $lutss, $cid, @bcp);
        }
         
        my (@submission, @contests, @messages);
        my @rtype_ref = (\@submission, \@messages, \@messages, \@messages, \@contests, \@contests);
        
        my %alias_link = (
            submit_state => 'state_or_official',
            is_official => 'state_or_official',
            problem_id => 'pid_or_clarified',
            clarified => 'pid_or_clarified',
            answer => 'jury_message',
            message => 'jury_message',
            'time' => 'submit_time',
        );
    
        while (my $r = $dtst->fetchrow_hashref) {
            #$_ = Encode::decode_utf8 $_ for values %{$r}; #DBD::InterBase driver doesn't work with utf-8
            @{$r}{qw/last_ip_short last_ip/} = CATS::IP::short_long(CATS::IP::filter_ip($r->{last_ip}));
            
            my %current_row = ();
            my $add_row = sub {
                my $param = shift;
                $current_row{$param} = $r->{$param} || $r->{$alias_link{$param}};
            };
            {
                no warnings 'uninitialized';
                $add_row->($_) for qw/time last_console_update failed_test question team_id id/;
            }    
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
        
        my $ans = {
            'submissions' => [reverse @submission],
            'contests' => [reverse @contests],
            'messages'=> [reverse @messages],
        };
        for (@kinds) {
            #если длина куска = length+1 -- обрезаем время since по времени того, который нам нужен =)
            if (@{$ans->{$_}} > $length{$_}) { #ASK: length?
                shift @{$ans->{$_}} while @{$ans->{$_}} > $length{$_};
                $k{$_}->{since} = $ans->{$_}->[0]->{time},
            }
        }
        {
            no warnings 'uninitialized';
            for (map({
                data => $ans->{$_},
                data_type => $_,
                'type' => $k{$_}->{type},
                'since' => $k{$_}->{since},
                'to' => $k{$_}->{to},
            }, @kinds)) {
                push (@{$res_seq}, $_) if $_->{type} ne 'none';
            }
        }
        $i++;
    }
    
    $self->set_specific_param('fragments', $res_seq);
    $self->set_specific_param('problems', $problems);
    $self->set_specific_param('teams', $teams);
}


1;
