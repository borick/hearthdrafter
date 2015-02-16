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
    my $c = $self->c();
    my $run = $c->model->arena->continue_run($arena_id);
    my $class = $run->{_source}->{class_name};
    
    print STDERR "Searching for: " . Dumper($card_1, $card_2, $card_3);
    #tier score
    my $scores = $self->es->search(
        index => 'hearthdrafter',
        type => 'card_score_by_class',
        body => {
            query => {
                bool => {
                    must => [
                        {
                            terms => {
                                card_name => [$card_1, $card_2, $card_3],
                                minimum_should_match => 1,
                            },
                            term => {
                                class_name => $class,
                            },
                        },
                    ],
                },
            },
        },
    );
    print STDERR "Scores:". Dumper($scores);
    #synergies
    #mana curve
    
    return $run;
    
}

1;