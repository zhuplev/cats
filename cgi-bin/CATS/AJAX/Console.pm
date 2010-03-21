package CATS::AJAX::Console;

use strict;
use warnings;
use Time::Local;

use CATS::AJAX::Abstract; 

our @ISA = qw~CATS::AJAX::Abstract~;

our @required_params = qw~last_update_timestamp~;


sub data_validate {
    my $self = shift;
    $self->{var}->{last_update_timestamp} =~ /^(\d\d)-(\d\d)-(\d\d\d\d), (\d\d):(\d\d):(\d\d)$/;
    eval {
        timelocal($6, $5, $4, $1, $2, $3);
        1;
    } or $self->{response}->{result} = 'invalid_update_timestamp';
}


sub make_response {
    my $self = shift;
}


1;
