package HearthModel::User;

use strict;
use warnings;

use Moo;
extends 'HearthModel::DbBase';
use Crypt::PBKDF2;
use Data::Dumper;

my $pbkdf2 = Crypt::PBKDF2->new(
    hash_class => 'HMACSHA2',
    hash_args => {
        sha_size => 512,
    },
    iterations => 10000,
    salt_len => 10,
);

# Write
sub register {
    my ($self, $user_name, $email, $fname, $lname, $password) = @_;
    
    die "bad bad characters in username '$user_name'" if ($user_name) !~ /^\w+$/;
    my $existing = undef;
    eval { 
        $existing = $self->es->get(
            index   => 'hearthdrafter',
            type    => 'user',
            id      => $user_name,
        );
    };
    die 'username already exists' if defined($existing);
    
    my $hash = $pbkdf2->generate($password);
    print STDERR "Registering with hash: $hash\n";
    $self->es->index(
        index   => 'hearthdrafter',
        type    => 'user',
        id      => $user_name,
        body    => {
            user_name   => $user_name,
            email => $email,
            first_name => $fname,
            last_name => $lname,
            password => $hash,
        }
    );
    return 1;
}

# Read
sub load {
    my ($self, $user_name) = @_;

    my $doc;
    eval {
        $doc = $self->es->get(
            index => 'hearthdrafter',
            type => 'user',
            id => $user_name);
    };
        
    my %user_data = ();
    delete $doc->{_source}->{password};
    $user_data{user} = $doc->{_source};
    return \%user_data;
}

sub check_password {
    my ($self, $user_name, $password) = @_;
     
    my $doc;    
    eval {
        $doc = $self->es->get(
            index => 'hearthdrafter',
            type => 'user',
            id => $user_name);
    };
    
    return 0 if !$doc;

    my $hash = $doc->{_source}->{password};
    if ($pbkdf2->validate($hash, $password)) {
        return $user_name;
    } else {
        return 0;
    }
}

1;