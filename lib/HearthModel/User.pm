package HearthModel::User;

use strict;
use warnings;

use Moo;
extends 'HearthModel::DbBase';
use Crypt::PBKDF2;
use Data::Dumper;
use Data::UUID;
my $du = Data::UUID->new();
use Mail::Sendmail;

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

sub reset_user_pw {
    my ($self, $user_name) = @_;
    my $valid_code = $du->create_str();
    $self->es->index(
        index   => 'hearthdrafter',
        type    => 'user',
        id      => $user_name,
        body    => {
            user_name   => $user_name,
            email => $email,
            first_name => $fname,
            last_name => $lname,
            password => "locked", #should never validate to a valid hash.
            validation_code => $valid_code,
        }
    );

    my %mail = ( To      => $email,
            From    => 'admin@hearthdrafter.com',
            Subject => '[HearthDrafter.com] $user_name Account Locked';
            Message => "Someone initiated an account lock through HearthDrafter's 'Forgotten Password' feature. Please <a href='http://hearthdrafter.com/validate/$user_name/$valid_code'>click here</a> to reset your password!",
            );

    sendmail(%mail) or die $Mail::Sendmail::error;

    print "OK. Log says:\n", $Mail::Sendmail::log;
}

sub forgotten_pw_check {
    my ($self, $user_name, $fname, $lname, $email) = @_;
     
    my $doc;    
    eval {
        $doc = $self->es->get(
            index => 'hearthdrafter',
            type => 'user',
            id => $user_name);
    };
    
    return 0 if !$doc;
    my $hash = $doc->{_source};
    if ($user_name ne $hash->{user_name} || $fname ne $hash->{first_name} || $lname ne $hash->{last_name} || $email ne $hash->{email}) {
        return 0;
    } else {
        return $self->reset_user_pw($user_name);
    }
    
}


1;