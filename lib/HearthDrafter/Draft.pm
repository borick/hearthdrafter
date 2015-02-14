package HearthDrafter::Draft;

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
            $self->redirect_to('/draft/continue_arena_run/'.$results->{_id});
        }
        
    } else {
        warn "bad action $action";
    }
}

sub continue_arena_run {
    my $self = shift;
    my $arena_id = $self->stash('arena_id');
    my $run_details = $self->model->arena->continue_run($arena_id);
    print STDERR Dumper($run_details);
    $self->stash(cards => $self->model->card->get_cards_by_class($run_details->{_source}->{class_name}));
    $self->render('draft/continue_arena_run');
}

sub card_choice {
    my $self = shift;
    $self->render(json => {});
}

1;