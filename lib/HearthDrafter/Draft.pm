package HearthDrafter::Draft;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

sub arena_action {
    my $self = shift;
    my $action = $self->stash('arena_action');
    print STDERR "Action: $action\n";
    if ($action =~ /new_arena_(\w+)/ ){
        my $class = $1;
        my $results = $self->model->arena->begin_arena($class, $self->user->{'user'}->{'name'});
        if (defined($results) && exists($results->{_id})) {
            return $self->redirect_to('/draft/select_card/'.$results->{_id});
        }
    } elsif ($action =~ /abandon_arena_([a-zA-Z0-9_-]+)/ ){
        my $arena_id = $1;
        $self->model->arena->abandon_run($arena_id, $self->user->{'user'}->{'name'});
        sleep 1;#TODO: figure out how to wait for data to be propagated.
        return $self->redirect_to('/draft/continue_arena_run');
    }
    warn "bad action $action";
}

sub continue_arena_run {
    my $self = shift;
    my $runs = $self->model->arena->list_open_runs($self->user->{'user'}->{'name'}, 0, 10);
    $self->stash(runs => $runs);
    $self->render('draft/continue_arena_run');    
}

sub select_card {
    my $self = shift;
    my $arena_id = $self->stash('arena_id');
    my $run_details = $self->model->arena->continue_run($arena_id);
    $self->stash(cards => $self->model->card->get_cards_by_class($run_details->{class_name}),
                 card_number => $self->model->card_choice->get_next_index($run_details));
    $self->render('draft/select_card');
}

sub card_choice {
    my $self = shift;
    my $result = $self->model->card_choice->get_advice($self->stash('arena_id'),
                                           $self->stash('card1'),
                                           $self->stash('card2'),
                                           $self->stash('card3'));
    print STDERR "RESULT: " . Dumper($result);
    $self->render(json => $result);
}

sub confirm_card_choice {
    my $self = shift;
    my $result = $self->model->card_choice->confirm_card_choice($self->stash('arena_id'),
                                                                $self->stash('card_name'));
    $self->render(json => $result);
}



1;