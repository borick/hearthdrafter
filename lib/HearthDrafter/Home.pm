package HearthDrafter::Home;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    shift->render('home/index');
}

sub login {
    shift->render('home/login');
}

sub register {
    shift->render('home/register');
}

sub register_post {
    my $self = shift;
    my $id = $self->req->body_params->param('username');
    my $email = $self->req->body_params->param('email');
    my $full_name = $self->req->body_params->param('full_name');

    my $query = $self->ds->prepare("INSERT INTO users (user_name, password, email) VALUES (?,'blah',?)")->get;
    $query->execute([$id, $email])->get;
    $self->render('home/login');
}

1;
