package HearthDrafter;


use HearthModel;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Authentication;

my $model = HearthModel->new();
$model->connect();
has model => sub {
    return $model;
};

my $validate_user_sub = sub {
    my ($app, $username, $password, $extradata) = @_;
    #return $uid;
};

my $load_user_sub = sub {
    my ($app, $uid) = @_;
    #return $user;
};

sub startup {

    my $self = shift;
    $self->secrets(['to.prevent.the.warning...']);
    $self->helper(model => sub { $model });

    $self->plugin('authentication' => {
        'autoload_user' => 1,
        'session_key' => 'hearthdrafter',
        'load_user' => $load_user_sub,
        'validate_user' => $validate_user_sub,
        'current_user_fn' => 'user',
    });

    my $r = $self->routes;

    $r->get('/')->to('home#index');
    $r->get('/register')->to('home#register');
    $r->post('/register')->to('home#register_post');
}

1;
