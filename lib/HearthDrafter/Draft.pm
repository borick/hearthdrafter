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
        return $self->redirect_to('/home');
    }
    warn "bad action $action";
}

sub select_card {
    my $self = shift;

    my $run_details;
    if (!eval { $run_details = $self->model->arena->continue_run($self->stash('arena_id')); }) {
        $self->stash(message=>'No arena with that ID exists.');
        return $self->redirect_to('/home');
    } else {
        if (exists($run_details->{end_date})) {
            return $self->redirect_to('/draft/results/'.$self->stash('arena_id'));
        }
        my $cards = $self->model->card->get_cards_by_class($run_details->{class_name});
        $self->stash(cards => $self->model->card->get_cards_by_class($run_details->{class_name}),
                     card_number => $self->model->arena->get_next_index($run_details),
                     run_details => $run_details);
        return $self->render('draft/select_card');
    }
}

sub cancel_card {
    my $self = shift;
    
    
}

sub card_choice {
    my $self = shift;
    my $result = $self->model->card_choice->get_advice($self->stash('card1'),
                                                       $self->stash('card2'),
                                                       $self->stash('card3'),
                                                       $self->stash('arena_id'));
    $self->render(json => $result);
}

sub confirm_card_choice {
    my $self = shift;
    my $result = $self->model->arena->confirm_card_choice($self->stash('card_name'),
                                                          $self->stash('arena_id'));
    $self->render(json => $result);
}

sub results {
    my $self = shift;
    $self->render('draft/results');
}
sub results_post {
    my $self = shift;
    my $result = $self->model->arena->provide_results($self->stash('arena_id'), $self->req->body_params);
    if (!$result) {
        $self->stash(message=>'Arena results updated successfully.');
        sleep 1;#TODO: figure out how to wait for data to be propagated.
        return $self->redirect_to('/');
    } else {
        $self->stash(error=>"There was a problem updating the arena result: $result\n");
    }
}

sub view_completed_runs {
    my $self = shift;
    my $result = $self->model->arena->list_runs_completed($self->user->{'user'}->{'name'},
                                                          $self->stash('from'),
                                                          $self->stash('size'));
    print STDERR Dumper($result);
    $self->stash(completed_runs => $result);
    $self->render('draft/view_completed_runs');
}

1;