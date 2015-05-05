#!/usr/bin/env perl

use strict;
use warnings;

use Encode;
use Getopt::Long;
use Search::Elasticsearch;
use Data::Dumper;
use Mail::Sendmail;

my $es = Search::Elasticsearch->new();
my $action='none';

GetOptions ("action=s" => \$action);

   my $scores_result = $es->search(
        index => 'hearthdrafter',
        type => 'user',
        size => 99999,
        body => {
              query => {
                match_all => {},
              }
        },
    );

if ($action =~ /^list_users/) {
    for my $score (@{$scores_result->{hits}->{hits}}) {          
        print $score->{_source}->{email}, "\n" if !exists($score->{_source}->{validation_code}) and $action !~ /unvalid/;
        print $score->{_source}->{email}, "\n" if $action =~ /unvalid/;
    }
}

if ($action =~ /^send_validation_email/) {
    for my $score (@{$scores_result->{hits}->{hits}}) {

        my $source = $score->{_source};
        if (exists($source->{validation_code})) {
             my $email = $source->{email};
             $email = encode('utf8', $email);
             my $user_name = $source->{user_name};
             my $valid_code = $source->{validation_code};
             my $fname = $source->{first_name};
             my $lname = $source->{last_name};

  my $valid_path = "/validate_user/$user_name/$valid_code";
    my $message = "Welcome to HearthDrafter.com $fname $lname!\n\nTo validate your account \"$user_name\", please navigate to https://www.hearthdrafter.com/$valid_path in your browser. Thank you for your patience.";
    my %mail = ( To => $email,
        From    => 'admin@hearthdrafter.com',
        Subject => "Welcome to HearthDrafter, $fname!",
        Message => $message,
        );
    print STDERR "Sending e-mail to: $email!\n";
    sendmail(%mail);

        }

    }
}
