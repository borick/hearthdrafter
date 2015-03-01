package HearthDrafter::Home;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;
    if ($self->is_user_authenticated()) {
        return $self->redirect_to('/home');
    }
    $self->render('home/index');
}

sub login {
    my $self = shift;
    if ($self->is_user_authenticated()) {
        return $self->redirect_to('/home');
    }
}
sub login_post {
    my $self = shift;
    my $user_name = $self->req->body_params->param('user_name');
    my $password = $self->req->body_params->param('password');
    if ($self->authenticate($user_name, $password)) {
        $self->redirect_to('/home');
    } else {        
        $self->flash(message => 'login failed');
        $self->redirect_to('/');
    }
}

sub logmeout {
    my $self = shift;
    $self->logout;
    $self->redirect_to('/');
}

sub home {
    my $self = shift;
    if (!$self->is_user_authenticated()) {
        return $self->redirect_to('/');
    }
    $self->stash(           runs => $self->model->arena->list_open_runs($self->user->{'user'}->{'name'}),
                 runs_no_results => $self->model->arena->list_runs_no_results($self->user->{'user'}->{'name'}));
}

sub register {
    shift->render('home/register');
}

sub register_post {
    my $self = shift;
    my $user_name = $self->req->body_params->param('user_name');
    my $email = $self->req->body_params->param('email');
    my $fname = $self->req->body_params->param('first_name');
    my $lname = $self->req->body_params->param('last_name');
    my $password = $self->req->body_params->param('password');
    if ($self->model->user->register($user_name, $email, $fname, $lname, $password)) {
        $self->flash(message => 'failed');
    } else {
        $self->flash(message => 'success');
    }
    $self->redirect_to('/home');
}

sub auth_check {
    my $self = shift;
    $self->redirect_to('/') and return 0 unless($self->is_user_authenticated);
    return 1;
}
1;
