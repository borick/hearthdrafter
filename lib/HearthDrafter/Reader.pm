package HearthDrafter::Reader;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

$HearthDrafter::Reader::clients = {};
     
sub _get_params {
    my ($c) = @_;
    die 'must be logged in' if !exists($c->user->{user});
    my $username = $c->user->{user}->{user_name};
    return ($c->user->{user}->{user_name}, _make_key($username));
}

sub _make_key {
    my ($val1) = @_;
    return $val1;
}

#websocket
sub connect {
    my $c = shift;
    
    my $arena_id = $c->stash('arena_id');
    my ($username, $key) = _get_params($c);
    
    $HearthDrafter::Reader::clients->{$key} = [$c->tx, $arena_id];
    $c->app->log->debug("Client $username with arena_id $arena_id connected");
    $c->inactivity_timeout(180);
    $c->on(message => sub {
        my ($self, $msg) = @_;
        $c->app->log->debug('Client msg: ' . $msg);
        #do nothing
    });
    $c->on(finish => sub {
        $c->app->log->debug('Client disconnected');
        delete $HearthDrafter::Reader::clients->{$arena_id};
    });
}

sub card_choice {
    my $c = shift;
    my ($username, $key) = _get_params($c);
    my $socket = $HearthDrafter::Reader::clients->{$key}->[0];
    my $arena_id = $HearthDrafter::Reader::clients->{$key}->[1];
    if (!defined($socket)) {
        $c->render(text => 'NO CLIENT');
        return;
    }
    my $result = $c->model->card_choice->get_advice($c->stash('card1'),
                                                    $c->stash('card2'),
                                                    $c->stash('card3'),
                                                    $arena_id);
    $socket->send({json => $result});
    $c->render(json=> $result);
}

sub confirm_card_choice {
    my $c = shift;
    my ($username, $key) = _get_params($c);
    my $socket = $HearthDrafter::Reader::clients->{$key}->[0];
    my $arena_id = $HearthDrafter::Reader::clients->{$key}->[1];
    if (!defined($socket)) {
        $c->render(text => 'NO CLIENT');
        return;
    }
    my $result_data = $c->model->arena->confirm_card_choice_by_num($c->stash('index'),
                                                                   $arena_id);
    if (!defined($result_data)) {
        $c->render(text => 'ERROR');
        return;
    }
    my $card = $result_data->[0];
    my $result = $result_data->[1];
    #print STDERR 'Confirm: ' . Dumper($result);
    my $out = { card => $card, data => $result };
    $socket->send({json => $out });
    $c->render(json => $out);
}
