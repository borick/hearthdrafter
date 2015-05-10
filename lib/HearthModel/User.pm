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
use Regexp::Profanity::US;
use RFC::RFC822::Address qw /valid/;
use Mojo::UserAgent;
use JSON;
  
use constant URL => 'https://www.hearthdrafter.com';
use constant VALIDATION_TIMEOUT_SECONDS => 60*60*24*14; #14 days expiry on validation code.
use constant MAX_USERS => 5000;
 
my $pbkdf2 = Crypt::PBKDF2->new(
    hash_class => 'HMACSHA2',
    hash_args => {
        sha_size => 512,
    },
    iterations => 10000,
    salt_len => 10,
);

my $ua = Mojo::UserAgent->new;

# Write
sub register {
    my ($self, $mojo, $user_name, $email, $email_confirm, $fname, $lname, $password) = @_;
    return "Name/ID cannot be blank" if $user_name =~ /^\s*$/ or $fname =~ /^\s*$/ or $fname =~ /^\s*$/;
    return "Profanity in user name" if profane($user_name);
    
    $user_name = lc($user_name);
    $email = lc($email);
    $email_confirm = lc($email_confirm);
    
    my $response = $mojo->req->body_params->param('g-recaptcha-response');
    #print STDERR Dumper($mojo->req->body_params);
    #print STDERR "Response: $response\n";
    my $tx = $ua->post('https://www.google.com/recaptcha/api/siteverify' => form => {response => $response,
                                                                                     secret => '6LfOPQYTAAAAAAnNr5UHwU39XIPALsSQhqbgthNq', 
                                                                                     remoteip => $mojo->tx->remote_address} );
    my $res = 0;
    eval {
        if ($res = $tx->success) {  print STDERR "Captcha success: $res\n"; }
        else {
            my $err = $tx->error;
            print STDERR "Error: " . Dumper($err);
        }
        my $data = decode_json($res->body);
        $res = $data->{success};
    };
    return "Captcha error"
            if ( !$res ) && ($mojo->req->url->to_abs->host !~ /local/);
    return "E-mails dont match" if $email ne $email_confirm;
    return "Bad characters in user name" if ($user_name) !~ /^[a-zA-Z_0-9-]+$/;
    return "E-mail invalid" if !valid($email);
    
    
    
    my $existing = undef;
    eval { 
        $existing = $self->es->get(
            index   => 'hearthdrafter',
            type    => 'user',
            id      => $user_name,
        );
    };
    return 'That user-name is taken. Please choose another.' if defined($existing);

    my $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'user',
        body  => {
            query => {
                match => { email => $email },
            }
        }
    );
    
    return 'That e-mail address is already registered. Please choose another.' if $results->{hits}->{total} > 0;
    $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'user',
        search_type => 'count',
        body  => {
            query => {
                match_all => {},
            }
        }
    );
    return 'Sorry, this site has reached the maximum number of users. Please try again tomorrow.' if ($results->{hits}->{total} > MAX_USERS);
    #make it.
    
    my $body_source = {
            user_name   => $user_name,
            email => $email,
            first_name => $fname,
            last_name => $lname,
            password => $pbkdf2->generate($password)
    };
        
    my $valid_code = $du->create_str();
    if ($mojo->req->url->to_abs->host !~ /local/) {
        #add validation code if not localhost    
        $body_source->{validation_code} = $valid_code;
        $body_source->{validation_code_time} = time;
    }
    $self->es->index(
        index   => 'hearthdrafter',
        type    => 'user',
        id      => $user_name,
        body    => $body_source,
    );
    my $valid_path = "/validate_user/$user_name/$valid_code";
    my $message = "Welcome to HearthDrafter.com $fname $lname!\n\nTo validate your account \"$user_name\", please navigate to " . URL . "$valid_path in your browser. Thank you for your patience.";
    my %mail = ( To => $email,
        From    => 'admin@hearthdrafter.com',
        Subject => "Welcome to HearthDrafter, $fname!",
        Message => $message,
        );
    print STDERR "Sending e-mail to: $email!\n";
    sendmail(%mail);
    return 0;
}

sub resend_validation_code {
    my ($self, $user_name) = @_;
    $user_name = lc($user_name);
    my $existing = undef;
    eval {
        $existing = $self->es->get(
            index   => 'hearthdrafter',
            type    => 'user',
            id      => $user_name,
        );
    };
    if (!defined($existing)) {
        return [0, "That user doesn't exist yet!"];
    }
    my $source = $existing->{_source};
    
    if (exists($source->{validation_code})) {
        my $email = $source->{email};
        my $fname = $source->{first_name};
        my $lname = $source->{last_name};
        my $valid_code = $source->{validation_code};
        my $valid_path = "/validate_user/$user_name/$valid_code";
        my $message = "Welcome to HearthDrafter.com $fname $lname!\n\nTo validate your account \"$user_name\", please navigate to " . URL . "$valid_path in your browser. Thank you for your patience.";
        my %mail = ( To => $email,
            From    => 'admin@hearthdrafter.com',
            Subject => "Welcome to HearthDrafter, $fname!",
            Message => $message,
        );
        print STDERR "Sending e-mail to: $email!\n";
        sendmail(%mail);
        return [1, "Validation code resent to e-mail address on file."];
    } else {
        return [0, "You're already validated, silly!"];
    }
}

# Read
sub load {
    my ($self, $user_name) = @_;
    $user_name = lc($user_name);
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
    $user_name = lc($user_name);
    my $doc;    
    eval {
        $doc = $self->es->get(
            index => 'hearthdrafter',
            type => 'user',
            id => $user_name);
    };
    return 0 if !$doc;
    return 0 if (exists($doc->{_source}->{validation_code}));
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
    $user_name = lc($user_name);
    my $doc;    
    eval {
        $doc = $self->es->get(
            index => 'hearthdrafter',
            type => 'user',
            id => $user_name);
    };
    return [0, 'user error'] if !$doc;
    return [0, "code error"] if $doc->{_source}->{validation_code} ne $code;
    return [0, "code timing error"] if time - $doc->{_source}->{validation_code_time} > VALIDATION_TIMEOUT_SECONDS;
    
    delete($doc->{_source}->{validation_code});
    delete($doc->{_source}->{validation_code_time});
    $doc->{_source}->{password} = $pbkdf2->generate($pw);
    $self->es->index(
        index   => 'hearthdrafter',
        type    => 'user',
        id      => $user_name,
        body    => $doc->{_source},
    );
    return [1, 'Password updated.'];
}

sub validate_user {
    my ($self, $user_name, $code) = @_;
    $user_name = lc($user_name);
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
    delete($doc->{_source}->{validation_code_time});
    $self->es->index(
        index   => 'hearthdrafter',
        type    => 'user',
        id      => $user_name,
        body    => $doc->{_source},
    );
    return [1, 'User validated successfully, you can now log in!'];
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
                validation_code_time => time,
            }
        );
        my %mail = ( To => $email,
            From    => 'admin@hearthdrafter.com',
            Subject => "[HearthDrafter.com] $user_name Account PW Reset",
            Message => "Someone, hopefully you, initiated a request to reset your HearthDrafter account password for account: $user_name. To change your hearthdrafter.com password, please go to: https://www.hearthdrafter.com/reset_pw/$user_name/$valid_code",
            );
        print STDERR "Sending e-mail to: $email!\n";
        sendmail(%mail);
        return $self->reset_pw($user_name, $fname, $lname, $email);
    }
    
}

sub get_user_stats {
    my ($self) = @_;
    my $results = $self->es->search(
        index => 'hearthdrafter',
        type => 'user',
        search_type => 'count',
        body  => {
            filter => {
                bool => {
                    must => { missing => { field => 'validation_code' } },
                },
            },
        }
    );
    my $arenas = $self->es->search(
        index => 'hearthdrafter',
        type => 'arena_run',
        search_type => 'count',
        body  => {
            filter => {
                bool => {
                must_not => [ 
                        { missing => { field => 'results.wins' } },
                        { missing => { field => 'end_date' } },
                    ],
                },
            },
        },
    );
    my $stats = {};
    $stats->{total_validated} = $results->{hits}->{total};
    $stats->{total_arenas} = $arenas->{hits}->{total};
    return $stats;
}

sub get_valid_users {
    my ($self) = @_;
    my $all_users = $self->es->search(
        index => 'hearthdrafter',
        type => 'user',
        size => 999999999,
        body  => {
            filter => {
                bool => {
                    must => { missing => { field => 'validation_code' } },
                },
            },
        }
    );
    return $all_users->{hits}->{hits};
}
sub get_invalid_users {
    my ($self) = @_;
    my $all_users = $self->es->search(
        index => 'hearthdrafter',
        type => 'user',
        size => 999999999,
        body  => {
            filter => {
                bool => {
                    must_not => { missing => { field => 'validation_code' } },
                },
            },
        }
    );
    return $all_users->{hits}->{hits};
}

sub delete_user {
    my ($self, $id) = @_;
    
    $self->es->delete(
        index => 'hearthdrafter',
        type => 'user',
        id => $id,
    );
    return;
}

sub lower_id {
    my ($self, $old_id) = @_;
    die "id already lowercase" if ($old_id eq lc($old_id));
    
    my $existing = undef;
    eval { 
        $existing = $self->es->get(
            index   => 'hearthdrafter',
            type    => 'user',
            id      => $old_id,
        );
    };
    die "no user" if !defined($existing);
    $self->delete_user($old_id);
    $self->es->index(
        index   => 'hearthdrafter',
        type    => 'user',
        id      => lc($old_id),
        body    => $existing->{_source},
    );
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

sub user_maintenance {
    my ($self) = @_;
    print STDERR "IN User Maintenance...\n";
#     my $users = $self->get_invalid_users();
#     for my $user (@$users) {
#         if (time - $user->{_source}->{validation_code_time} > VALIDATION_TIMEOUT_SECONDS) {
#             print STDERR "Deleting old user $user->{_id}\n";
#             #$self->delete_user($user->{_id});
#         }
#     }
    my $users = $self->es->search(
        index => 'hearthdrafter',
        type => 'user',
        body  => {
            query => {
                match_all => {},
            },
        }
    );
    my $user_list = $users->{hits}->{hits};
    for my $user (@$user_list) {
        if ($user->{_id} ne lc($user->{_id})) {
            print STDERR "Lowering ID for: $user->{_id}\n";
            eval { $self->lower_id($user->{_id}) };
        }
    }
}

1;
