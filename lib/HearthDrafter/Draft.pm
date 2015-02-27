package HearthDrafter::Draft;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

sub arena_action {
    my $self = shift;
    if (!$self->is_user_authenticated()) {
        return $self->redirect_to('/login');
    }
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
        return $self->redirect_to('/home');
    }
    warn "bad action $action";
}

sub select_card {
    my $self = shift;
    if (!$self->is_user_authenticated()) {
        return $self->redirect_to('/login');
    }
    my $run_details;
    if (!eval { $run_details = $self->model->arena->continue_run($self->stash('arena_id')); }) {
        $self->stash(message=>'No arena with that ID exists.');
        return $self->redirect_to('/home');
    } else {
        my $cards = $self->model->card->get_cards_by_class($run_details->{class_name});
        $self->stash(cards => $self->model->card->get_cards_by_class($run_details->{class_name}),
                     card_number => $self->model->arena->get_next_index($run_details),
                     run_details => $run_details);
        return $self->render('draft/select_card');
    }
}

sub card_choice {
    my $self = shift;
    if (!$self->is_user_authenticated()) {
        return $self->redirect_to('/login');
    }
    my $result = $self->model->card_choice->get_advice($self->stash('card1'),
                                                       $self->stash('card2'),
                                                       $self->stash('card3'),
                                                       $self->stash('arena_id'));
    $self->render(json => $result);
}

sub confirm_card_choice {
    my $self = shift;
    if (!$self->is_user_authenticated()) {
        return $self->redirect_to('/login');
    }
    my $result = $self->model->arena->confirm_card_choice($self->stash('card_name'),
                                                          $self->stash('arena_id'));
    $self->render(json => $result);
}

sub results {
    my $self = shift;
    if (!$self->is_user_authenticated()) {
        return $self->redirect_to('/login');
    }
    $self->render('draft/select_card');
}



1;