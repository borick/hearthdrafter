package HearthModel::CardChoice;
use Moo;
extends 'HearthModel::DbBase';
use Data::Dumper;

sub card_choice {
    my ($self, $arena_id, $card_1, $card_2, $card_3) = @_;
    
    #first the tier scores
    my $run = $self->model->arena->continue_run($arena_id);
    print STDERR Dumper($run);
    
    return $run;
    
}

1;