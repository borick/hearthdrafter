package HearthDrafter::Admin;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';
use Data::Dumper;

sub index {
    shift->render('admin/index');
}

sub check {
    my $self = shift;
    $self->redirect_to('/') and return 0 unless($self->is_user_authenticated) or ($self->{user}->{user_name} ne 'boris');
    return 1;
}

1;