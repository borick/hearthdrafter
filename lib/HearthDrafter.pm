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
    my ($self, $username, $password, $extradata) = @_;
    return $self->model->user->check_password($username, $password);
};

my $load_user_sub = sub {
    my ($self, $username) = @_;
    return $self->model->user->load($username);
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
    
    #define all routes
    my $r = $self->routes;
    $r->get('/')->to('home#index');
    $r->get('/login')->to('home#login');
    $r->post('/login')->to('home#login_post');
    $r->get('/logout')->to('home#logmeout');
    $r->get('/home')->to('home#home');
    $r->get('/register')->to('home#register');
    $r->post('/register')->to('home#register_post');
    #drafting
    $r->get('/draft/select_class/')->to('draft#select_class');
    $r->get('/draft/arena_status/')->to('draft#arena_status');
    $r->get('/draft/arena_status/:arena_action')->to('draft#arena_action', arena_action => 'none');
    $r->get('/draft/arena_action/:arena_action')->to('draft#arena_action', arena_action => 'none');
    $r->get('/draft/continue_arena_run')->to('draft#continue_arena_run', arena_id => 'none');
    $r->get('/draft/select_card/:arena_id')->to('draft#select_card', arena_id => 'none');
    $r->get('/draft/card_choice/:card1/:card2/:card3')->to('draft#card_choice', card1 => 'none', card2 => 'none', card3 => 'none');
}

1;
