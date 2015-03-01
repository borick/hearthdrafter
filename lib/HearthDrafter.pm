package HearthDrafter;

use strict;
use warnings;

use HearthModel;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Authentication;
use Data::Dumper;

my $model = HearthModel->new();
has model => sub {
    return $model;
};

my $validate_user_sub = sub {
    my ($self, $username, $password, $extradata) = @_;
    return $self->model->user->check_password($username, $password);
};

my $load_user_sub = sub {
    my ($self, $username) = @_;
    my $user_data = $self->model->user->load($username);
    return $user_data;
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
    #connect the model and pass ourself for convenience!
    my $model = $self->model();
    $model->connect($self);
    
    
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
    my $auth_bridge = $r->under('/draft')->to('home#auth_check');
    $auth_bridge->get('/select_class/')->to('draft#select_class');
    $auth_bridge->get('/arena_status/')->to('draft#arena_status');
    $auth_bridge->get('/arena_status/:arena_action')->to('draft#arena_action');
    $auth_bridge->get('/arena_action/:arena_action')->to('draft#arena_action');
    $auth_bridge->get('/continue_arena_run')->to('draft#continue_arena_run');
    $auth_bridge->get('/select_card/:arena_id')->to('draft#select_card');
    $auth_bridge->get('/card_choice/:card1/:card2/:card3/:arena_id/')->to('draft#card_choice');
    $auth_bridge->get('/confirm_card_choice/:card_name/:arena_id/')->to('draft#confirm_card_choice');
    $auth_bridge->get('/results/:arena_id/')->to('draft#results');
    $auth_bridge->post('/results/:arena_id/')->to('draft#results_post');
}

1;
