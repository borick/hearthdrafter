package HearthDrafter::Admin;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

sub index {
    my $self = shift;
    $self->stash( stats => $self->model->user->get_user_stats() );
    $self->render('admin/index');
}

sub users {
    my $self = shift;
    $self->stash( users => $self->model->user->get_valid_users() ,
                  invalid_users => $self->model->user->get_invalid_users() );
    $self->render('admin/users');
}

sub delete_user {
    my $self = shift;
    eval { $self->model->user->delete_user($self->stash('id')); };
    select undef,undef,undef,0.75;
    return $self->redirect_to("/admin/users");
}

sub user_maintenance {
    my $self = shift;
    eval { $self->model->user->user_maintenance($self->stash('id')); };
    select undef,undef,undef,0.75;
    return $self->redirect_to("/admin/users");
}

sub check {
    my $self = shift;
    $self->redirect_to('/') and return 0 unless($self->is_user_authenticated) or ($self->{user}->{user_name} ne 'boris');
    return 1;
}

1;