package CATS::AJAX::Abstract;

use strict;
use warnings;
use JSON::XS;


sub required_params {};

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
    #также сохраняем переменные, имена которых указаны в our sub @required_params в наследуемом классе
    $self->{var}->{$_} = $self->{cgi}->param($_) for ($self->required_params);
        
    eval {
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
    return $json->encode($self->{response});
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
