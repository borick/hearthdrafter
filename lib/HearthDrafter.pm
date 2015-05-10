package HearthDrafter;

use strict;
use warnings;

use HearthModel;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Authentication;
use Data::Dumper;
use Mojo::Log;

my $model = HearthModel->new();
has model => sub {
    return $model;
};

my $validate_user_sub = sub {
    my ($self, $username, $password, $extradata) = @_;
    my $result;
    eval { $result = $self->model->user->check_password($username, $password); };
    return $result;
};

my $load_user_sub = sub {
    my ($self, $username) = @_;
    my $user_data;
    eval { $user_data = $self->model->user->load($username); };
    return $user_data;
};

sub startup {
    my $self = shift;    
    $self->config(hypnotoad => {workers => 1, proxy => 1});
    $self->secrets(['to.prevent.the.warning...']);
    $self->helper(model => sub { $model });
    $self->plugin('authentication' => {
        'autoload_user' => 1,
        'session_key' => 'hearthdrafter',
        'load_user' => $load_user_sub,
        'validate_user' => $validate_user_sub,
        'current_user_fn' => 'user',
    });
    
    #connect the model and pass ourself for convenience
    my $model = $self->model();
    $model->connect($self);
    
    #define all routes
    my $r = $self->routes;
    $r->get('/')->to('home#index');
    $r->post('/login')->to('home#login_post');
    $r->get('/logout')->to('home#logmeout');
    $r->get('/home')->to('home#home');
    $r->get('/resend')->to('home#resend');
    $r->post('/resend')->to('home#resend_post');
    $r->get('/register')->to('home#register');
    $r->post('/register')->to('home#register_post');
    $r->get('/reset_pw/:user_name/:code')->to('home#reset_pw');
    $r->post('/reset_pw_post')->to('home#reset_pw_post');
    $r->get('/validate_user/:user_name/:code')->to('home#validate_user');
    $r->get('/forget_pw')->to('home#forget_pw');
    $r->post('/forget_pw')->to('home#forget_pw_post');
    
    #drafting
    my $auth_bridge = $r->under('/draft')->to('home#auth_check');
    $auth_bridge->get('/download')->to('draft#download');
    $auth_bridge->get('/settings')->to('home#settings');
    $auth_bridge->post('/settings')->to('home#settings_post');
    $auth_bridge->get('/select_class/')->to('draft#select_class');
    $auth_bridge->get('/arena_status/')->to('draft#arena_status');
    $auth_bridge->get('/arena_status/:arena_action')->to('draft#arena_action');
    $auth_bridge->get('/arena_action/:arena_action')->to('draft#arena_action');
    $auth_bridge->get('/continue_arena_run')->to('draft#continue_arena_run');
    $auth_bridge->get('/select_region/:arena_id')->to('draft#select_region');
    $auth_bridge->get('/select_card/:arena_id')->to('draft#select_card');
    $auth_bridge->get('/card_choice/:card1/:card2/:card3/:arena_id/')->to('draft#card_choice');
    $auth_bridge->get('/confirm_card_choice/:card_name/:arena_id/')->to('draft#confirm_card_choice');
    $auth_bridge->get('/results/:arena_id/')->to('draft#results');
    $auth_bridge->post('/results/:arena_id/')->to('draft#results_post');
    $auth_bridge->get('/view_completed_runs')->to('draft#view_completed_runs');
    $auth_bridge->get('/view_completed_runs/:from/:size')->to('draft#view_completed_runs');
    $auth_bridge->get('/view_completed_run/:arena_id')->to('draft#view_completed_run');
    $auth_bridge->get('/reader_card_choice/:card1/:card2/:card3')->to('reader#card_choice');
    $auth_bridge->get('/reader_confirm_card_choice/:index')->to('reader#confirm_card_choice');
    $auth_bridge->websocket('/reader_socket')->to('reader#connect'); #cant figure out how to get rid of this extra one.
    $auth_bridge->websocket('/reader_socket/:arena_id')->to('reader#connect');
    
    #admin
    my $admin_bridge = $r->under('/admin')->to('admin#check');
    $admin_bridge->get('/')->to('admin#index');    
    $admin_bridge->get('/users')->to('admin#users');
    $admin_bridge->get('/delete_user/:id')->to('admin#delete_user');
    $admin_bridge->get('/lower_id/:id')->to('admin#lower_id');
    $admin_bridge->get('/delete_old_invalid_users')->to('admin#delete_old_invalid_users');
}
1;
