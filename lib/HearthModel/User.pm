package HearthModel::User;

use Moo;
use Crypt::PBKDF2;

has cass => (
    is => 'rw',
);

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
    
    my $query = $self->cass->prepare("INSERT INTO users (user_name, email, first_name, last_name, password) VALUES (?,?,?,?,?)")->get;
    return $query->execute([$user_name, $email, $fname, $lname, $pbkdf2->generate($password)])->get;
}

# Read
sub load {
    my ($self, $user_name) = @_;
    my $query = $self->cass->prepare("SELECT * FROM users WHERE user_name = ?")->get;
    my ( undef, $result ) = $query->execute([$user_name])->get;
    my %user_data = ();
    $user_data{user_name} = $result->{rows}->[0]->[0];
    return \%user_data;
}

sub check_password {
    my ($self, $user_name, $password) = @_;
    
    my $query = $self->cass->prepare("SELECT password FROM users WHERE user_name = ?")->get;
    my (undef, $result) = $query->execute([$user_name])->get;
    my @data = @{$result->{rows}};    
    return 0 if !@data;
    if ($pbkdf2->validate($data[0]->[0], $password)) {
        return $user_name;
    } else { 
        return 0;
    }
}

1;