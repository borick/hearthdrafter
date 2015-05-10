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
        my $results = $self->model->arena->begin_arena($class, $self->user->{'user'}->{'user_name'});
        if (defined($results) && exists($results->{_id})) {
            return $self->redirect_to('/draft/select_region/'.$results->{_id});
        } else {
            $self->stash('message' => 'Could not create new arena.');
            return $self->redirect_to('/home');
        }
    } elsif ($action =~ /abandon_arena_([a-zA-Z0-9_-]+)/ ){
        my $arena_id = $1;
        $self->model->arena->abandon_run($arena_id, $self->user->{'user'}->{'user_name'});
        select undef,undef,undef 0.3; #TODO:hideious timing bodge
        return $self->redirect_to('/home');
    } elsif ($action =~ /undo_last_card_([a-zA-Z0-9_-]+)/ ){
        my $arena_id = $1;
        my $result = $self->model->arena->undo_last_card($arena_id, $self->user->{'user'}->{'user_name'});
        return $self->render(json => $result);
    } elsif ($action =~ /set_region_([a-z]+)_([a-zA-Z0-9_-]+)/ ){
        my $region = $1;
        my $arena_id = $2;
        my $result = $self->model->arena->set_region($arena_id, $self->user->{'user'}->{'user_name'}, $region);
        return $self->redirect_to('/draft/select_card/'.$arena_id);
    }
    warn "bad action $action";
}

sub select_region {
    shift->render('draft/select_region');
}

sub select_card {
    my $self = shift;

    my $run_details;
    if (!eval { $run_details = $self->model->arena->continue_run($self->stash('arena_id')); }) {
        $self->stash(message=>'No arena with that ID exists.');
        return $self->redirect_to('/home');
    } else {
        if (exists($run_details->{end_date})) {
            return $self->redirect_to('/draft/view_completed_run/'.$self->stash('arena_id'));
        }
        my $cards = $self->model->card->get_cards_by_class($run_details->{class_name});
        $self->stash(cards => $self->model->card->get_cards_by_class($run_details->{class_name}),
                     card_number => $self->model->arena->get_next_index($run_details),
                     run_details => $run_details);
        return $self->render('draft/select_card');
    }
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
        select undef,undef,undef 0.3; #TODO:hideious timing bodge
        return $self->redirect_to('/');
    } else {
        $self->stash(error=>"There was a problem updating the arena result: $result\n");
    }
}

sub view_completed_runs {
    my $self = shift;
    my $result = $self->model->arena->list_runs_completed($self->user->{'user'}->{'user_name'},
                                                          $self->stash('from'),
                                                          $self->stash('size'));
    print STDERR Dumper($result);
    $self->stash(completed_runs => $result);
    $self->render('draft/view_completed_runs');
}

sub view_completed_run {
    my $self = shift;
    my $run_details;
    if (!eval { $run_details = $self->model->arena->continue_run($self->stash('arena_id')); }) {
        $self->stash(message=>'No arena with that ID exists.');
        return $self->redirect_to('/home');
    } else {
        if (!exists($run_details->{end_date})) {
            return $self->redirect_to('/draft/select_card/'.$self->stash('arena_id'));
        }
        my $cards = $self->model->card->get_cards_by_class($run_details->{class_name});
        $self->stash(run=>$run_details, cards=>$cards);
        $self->render('draft/view_run');
    }
}

1;
