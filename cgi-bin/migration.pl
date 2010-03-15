#!/usr/bin/perl -w
use DBD::InterBase;
use HTML::Template;
use strict;

my $dbh;

sub new_id
{
    die unless $dbh;
    $dbh->selectrow_array(q~SELECT GEN_ID(key_seq, 1) FROM RDB$DATABASE~);
}


sub sql_connect 
{
    $dbh = DBI->connect("DBI:InterBase:host=localhost;db=cats;ib_dialect=3", "sysdba", "masterkey", { AutoCommit => 0, LongReadLen => 1024*1024 } );

    $dbh->{ HandleError } = sub {

        print "DBI error: ".$_[0] ."\n";
        exit(0);   
    };

}


sub sql_disconnect 
{    
    $dbh->disconnect if ( defined $dbh );
}


sql_connect;

$dbh->do(qq~SET GENERATOR key_seq TO 500000~);

my $cid = new_id;

print "cid: $cid\n";

#$dbh->do(qq~ALTER TABLE contests ADD ctype INTEGER~);
#$dbh->commit;

$dbh->do(qq~UPDATE contests SET ctype=0~);

$dbh->do(qq~INSERT INTO contests (id, title, start_date, 
        freeze_date, finish_date, defreeze_date, closed, ctype) 
        VALUES(?,?, CATS_TO_DATE(?), CATS_TO_DATE(?), 
        CATS_TO_DATE(?), CATS_TO_DATE(?), 1, 1)~, {}, 
            $cid, 'training session', '01-01-2000 00:00', 
            '01-01-2000 00:00', '01-01-2000 00:00', '01-01-2000 00:00');

#my $c = $dbh->prepare(qq~SELECT id FROM problems~);
#$c->execute;

#while (my ($pid) = $c->fetchrow_array)
#{
#    $dbh->do(qq~INSERT INTO contest_problems (id, contest_id, problem_id, code) VALUES (?,?,?,NULL)~, {}, 
#        new_id, $cid, $pid);
#}

my $c = $dbh->prepare(qq~SELECT id FROM accounts WHERE id>0~);
$c->execute;

while (my ($aid) = $c->fetchrow_array)
{
    $dbh->do(qq~INSERT INTO contest_accounts (id, contest_id, 
        account_id, is_admin, is_jury, is_pop, is_hidden, is_ooc, is_remote) 
        VALUES (?,?,?,?,?,?,?,?,?)~, {}, 
        new_id, $cid, $aid, 0, 0, 0, 0, 1, 1);
}




#$dbh->do(qq~INSERT INTO contest_accounts (id, contest_id, 
#        account_id, is_admin, is_jury, is_pop, is_hidden, is_ooc, is_remote) 
#        VALUES (?,?,?,?,?,?,?,?,?)~, {}, 
#        new_id, $cid, 0, 1, 1, 1, 1, 1, 1);

#$dbh->do(qq~UPDATE reqs SET contest_id=? WHERE contest_id IS NULL~, {}, $cid);

$dbh->commit;

print "\ncompleted";
sql_disconnect;

