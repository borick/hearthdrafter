package HearthModel::User;

use Moo;
use Crypt::PBKDF2;

my $pbkdf2 = Crypt::PBKDF2->new(
    hash_class => 'HMACSHA2',
    hash_args => {
        sha_size => 512,
    },
    iterations => 10000,
    salt_len => 10,
);


sub register {
    my ($user_name, $email, $password) = @_;
    
}

1;