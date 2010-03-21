package CATS::AJAX::Abstract;

use strict;
use warnings;
use JSON::XS;


sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self->{response} = {};
    @{$self}{qw~dbh cgi var~} = @_;
    $class =~ /(.*::)*(.*)/;
    $self->{res_type} = lc $2;
    no strict 'refs';
        #также сохраняем переменные, имена которых указаны в our @required_params в наследуемом классе
        $self->{var}->{$_} = $self->{cgi}->param($_) for @{ref($self) . "::required_params"};
        #формируем ответ на запрос с помощью функции make_response в наследуемом классе
        my $make_response = \&{ref($self) . "::make_response"};
        #eval {$make_response->($self); 1;};
        $make_response->($self);
    use strict;   
    
    $self->check_permissions;
    
    return $self;
}


sub check_permissions {
    my $self = shift;
    $self->{response}->{result} = 'bad_session' if defined $self->{var}->{hack_try};
}


sub get_response {
    my $self = shift;
    my $json = JSON::XS->new;
    $json->utf8(1);
    $self->{response}->{result} = 'ok' unless $self->{response}->{result};
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
