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
use Captcha::reCAPTCHA;
use Regexp::Profanity::US;

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
    my ($self, $mojo, $user_name, $email, $fname, $lname, $password, $c) = @_;
    my $challenge = $mojo->req->body_params->param('recaptcha_challenge_field');
    my $response = $mojo->req->body_params->param('recaptcha_response_field');
    my $result = $c->check_answer('6LfOPQYTAAAAAAnNr5UHwU39XIPALsSQhqbgthNq', $mojo->tx->remote_address, $challenge, $response);
    print STDERR Dumper($result);
    die "Captcha fail." . $result->{error} if ( !$result->{is_valid} );
    die "No profanity in user name." if $user_name =~ /test/ || $user_name =~ /hearthdraft/ || profane($user_name);
    die "Bad characters in user name.'$user_name'" if ($user_name) !~ /^\w+$/;
    my $existing = undef;
    eval { 
        $existing = $self->es->get(
            index   => 'hearthdrafter',
            type    => 'user',
            id      => $user_name,
        );
    };
    die 'username already exists' if defined($existing);
    $self->es->index(
        index   => 'hearthdrafter',
        type    => 'user',
        id      => $user_name,
        body    => {
            user_name   => $user_name,
            email => $email,
            first_name => $fname,
            last_name => $lname,
            password => $pbkdf2->generate($password),
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
    #print STDERR Dumper(\%user_data);
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
        print STDERR "Validates...\n";
        return $user_name;
    } else {
    print STDERR "Does not validate...\n";
        return 0;
    }
}

sub reset_pw {
    my ($self, $user_name, $pw, $code) = @_;
    my $doc;    
    eval {
        $doc = $self->es->get(
            index => 'hearthdrafter',
            type => 'user',
            id => $user_name);
    };
    return [0, 'user error'] if !$doc;
    return [0, "code error"] if $doc->{_source}->{validation_code} ne $code;
    delete($doc->{_source}->{validation_code});
    $doc->{_source}->{password} = $pbkdf2->generate($pw);
    $self->es->index(
        index   => 'hearthdrafter',
        type    => 'user',
        id      => $user_name,
        body    => $doc->{_source},
    );
    return [1, 'Password updated.'];
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
        my %mail = ( To => $email,
            From    => 'admin@hearthdrafter.com',
            Subject => "[HearthDrafter.com] $user_name Account PW Reset",
            Message => "Someone, hopefully you, initiated a request to reset your HearthDrafter account password. To change your hearthdrafter.com password, please click <a href='http://hearthdrafter.com/reset_pw/$user_name/$valid_code'>this link.</a>",
            );

        sendmail(%mail);
        return $self->reset_pw($user_name, $fname, $lname, $email);
    }
    
}

sub settings {
    my ($self, $email, $fname, $lname, $password) = @_;
    
    my $existing = undef;
    print STDERR Dumper($self->user);    
#     eval { 
#         $existing = $self->es->get(
#             index   => 'hearthdrafter',
#             type    => 'user',
#             id      => $user_name,
#         );
#     };
#     die 'username already exists' if defined($existing);
#     $self->es->index(
#         index   => 'hearthdrafter',
#         type    => 'user',
#         id      => $user_name,
#         body    => {
#             user_name   => $user_name,
#             email => $email,
#             first_name => $fname,
#             last_name => $lname,
#             password => $pbkdf2->generate($password),
#         }
#     );
    return 1;
}

1;