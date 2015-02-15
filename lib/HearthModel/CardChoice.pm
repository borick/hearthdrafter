package HearthModel::CardChoice;

use strict;
use warnings;

use Moo;
extends 'HearthModel::DbBase';

has c => (
    is => 'rw',
);

use Data::Dumper;

sub get_advice {
    my ($self, $arena_id, $card_1, $card_2, $card_3) = @_;
    
    #first the tier scores
    my $c = $self->c();
    my $run = $c->model->arena->continue_run($arena_id);
    my $class = $run->{_source}->{class_name};
    
    return $run;
    
}

1;