package CATS::AJAX::Abstract;

use strict;
use warnings;
use JSON::XS;

use CATS::Constants;

sub required_json_params {};

sub data_validate {};

sub make_response {};


sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->{response} = {};
    @{$self}{qw~dbh cgi var~} = @_;
    $class =~ /(.*::)*(.*)/;
    $self->{res_type} = lc $2;
    
    eval {
        my $r = $self->{cgi}->param('request');
        if (defined $r) {
            my $json = JSON::XS->new;
            $json->utf8(1);
            $self->{json} = $json->decode($r);
            ref $self->{json} eq 'HASH' or die 'Incorrect json request. It must be an object.';
        } else {
            $self->{json} = {};
        }
        for ($self->required_json_params) {
            my $arg = $self->{json}->{$_};
                die sprintf "%s param is undef but it's required", $_ unless defined $arg;
            $self->{var}->{$_} = $arg;
            #также сохраняем переменные, имена которых указаны в our sub @required_json_params в наследуемом классе из JSON,
            #переданного в параметр 'request' запроса
        }
        
        $self->check_permissions;
        $self->data_validate;
        $self->make_response;
        1;
    } or $self->{response}->{result} = $@;
        
    return $self;
}


sub check_permissions {
    my $self = shift;
    defined $self->{var}->{hack_try} and die 'bad_session';
}


sub get_response {
    my $self = shift;
    my $json = JSON::XS->new;
    $json->utf8(1);
    $self->{response}->{result} ||= 'ok';
    $self->{response}->{server_timestamp} = $self->{var}->{server_timestamp};
    
    my $response = $json->encode($self->{response});
    $response =~ s/"(-?\d{0,9})"/$1/g; #\d{0,9} вместо \d+ --- а вдруг кто-то задаст вопрос из одних цифр?
        #а кто знает ещё способы убрать ковычки вокруг чисел?
    return $response;
}


sub set_common_param {
    my $self = shift;
    my ($param, $value) = @_;
    $self->{response}->{$param} = $value;
}


sub set_specific_param {
    my $self = shift;
    my ($param, $value) = @_;
    $self->{response}->{$self->{res_type}}->{$param} = $value;
}


1;
