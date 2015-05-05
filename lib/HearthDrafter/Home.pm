package HearthDrafter::Home;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';
use Mail::Sendmail;

my $c = Captcha::reCAPTCHA->new;

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
        $self->flash(login_message => 'Login Failed');
        
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
    $self->stash(           runs => $self->model->arena->list_open_runs($self->user->{'user'}->{'user_name'}),
                runs_no_results => $self->model->arena->list_runs_no_results($self->user->{'user'}->{'user_name'}));
}

sub register {
    my $self = shift;
    $self->stash('captcha' => $c->get_html('6LfOPQYTAAAAAAZkmVtyWMAWWN-sKo_FaRRSusHM', undef, 1));
    $self->render('home/register');
}

sub register_post {
    my $self = shift;
    my $user_name = $self->req->body_params->param('user_name');
    my $email = $self->req->body_params->param('email');
    my $email_confirm = $self->req->body_params->param('email_confirm');
    my $fname = $self->req->body_params->param('first_name');
    my $lname = $self->req->body_params->param('last_name');
    my $password = $self->req->body_params->param('password');
    
    my $result = undef;
    eval {
        $result = $self->model->user->register($self, $user_name, $email, $email_confirm, $fname, $lname, $password, $c);
    };
    if (!defined($result)) {
        my $msg = undef;
        if ($@ =~ /(.*) at .* line \d+.$/) {
            $msg = $1;
        } else {
            $msg = 'User creation failed.';
        }
        print STDERR "User Creation Failed...\n";
        $self->stash(error_message => $msg);
        $self->render('home/index');
    } else {
        print STDERR "User Creation Success!\n";
        $self->stash(success_message => 'User created. Please check your e-mail account for the validation link.');
        $self->render('home/index');
    }
    
}

sub resend {
    my ($self) = @_;
    $self->render('home/resend');
}

sub resend_post {
    my ($self) = @_;
    my $user_name = $self->req->body_params->param('user_name');
    my $result = $self->model->user->resend_validation_code($user_name);
    if ($result->[0]) {
        $self->stash(success_message => $result->[1]);
    } else {
        $self->stash(error_message => $result->[1]);
    }
    $self->redirect_to('/');
}

sub forgot_pw {
    my ($self) = @_;
    $self->render('home/forgot_pw');
}

sub forgot_pw_post {
    my $self = shift;
    my $user_name = $self->req->body_params->param('user_name');
    my $email = $self->req->body_params->param('email');
    my $fname = $self->req->body_params->param('first_name');
    my $lname = $self->req->body_params->param('last_name');
    my $result = $self->model->user->forgotten_pw_check($user_name, $fname, $lname, $email);
    if ($result->[0]) {
        $self->stash(success_message => $result->[1]);
    } else {
        $self->stash(error_message => $result->[1]);
    }
    $self->redirect_to('/');
}

sub validate_user {
    my $self = shift;
    my $user_name = $self->stash('user_name');
    my $code = $self->stash('code');
    my $result = $self->model->user->validate_user($user_name, $code);
    if ($result->[0]) {
        $self->stash(success_message => $result->[1]);
    } else {
        $self->stash(error_message => $result->[1]);
    }
    $self->redirect_to('/');
}


sub reset_pw {
    shift->render('home/reset_pw');
}

sub reset_pw_post {
    my $self = shift;
    my $user_name = $self->req->body_params->param('user_name');
    my $code = $self->req->body_params->param('code');
    my $result = $self->model->user->reset_pw($user_name, $self->req->body_params->param('pw'), $code);
    if ($result->[0]) {
        $self->stash(success_message => $result->[1]);
    } else {
        $self->stash(error_message => $result->[1]);
    }
}

sub auth_check {
    my $self = shift;
    $self->redirect_to('/') and return 0 unless($self->is_user_authenticated);
    return 1;
}
1;
