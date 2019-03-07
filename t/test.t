#!/usr/bin/env perl

use strict;
use warnings;

use lib 'lib';
use Test::More;
use Test::WWW::Selenium;
use Data::Dumper;
use Selenium::Remote::WDKeys;

use constant MAX_LOAD_TIME => 1000;

my $sel = Test::WWW::Selenium->new( host => "localhost",
                                    port => 4444,
                                    browser => "*firefox",
                                    browser_url => 'http://www,google.com',
                                    );
$sel->start;
$sel->open("http://localhost:3000");
ok(check_no_js_errors(), "no js errors");
$sel->type_ok("user_name", "test");
$sel->type_ok("password", "test");
$sel->submit_ok("login");
$sel->wait_for_page_to_load_ok(MAX_LOAD_TIME);
ok(check_no_js_errors(), "no js errors");
ok($sel->get_text('login_status') =~ /Logged in/, "user logged in");
ok(check_no_js_errors(), "no js errors");
$sel->click(q{xpath=//a[contains(@href,'select_class')]});
$sel->wait_for_page_to_load_ok(MAX_LOAD_TIME);
ok($sel->get_html_source() =~ /Select Class/, "at select class page");
$sel->click(q{xpath=//a[contains(@href,'new_arena_druid')]});
$sel->wait_for_page_to_load_ok(MAX_LOAD_TIME);
ok($sel->get_html_source() =~ /Select Region/, "at select region page");
$sel->click(q{xpath=//a[contains(@href,'select_card')]});
$sel->wait_for_page_to_load_ok(MAX_LOAD_TIME);
ok($sel->get_html_source() =~ /Druid Run/, "at select card page");
use_ok('HearthModel');
my $hm = HearthModel->new();
$hm->connect();

for (my $counter = 0; $counter < 30; $counter += 1) {
    my $cards3 = get_three_random();
    select undef, undef, undef, 0.1;
    $sel->key_press_native(10);#enter key
    select undef, undef, undef, 0.1;
    $sel->type(q{xpath=//input[@class='search']}, $cards3->[0]);
    $sel->type_keys(q{xpath=//input[@class='search']}, $cards3->[0]);
    select undef, undef, undef, 0.1;
    $sel->key_press_native(10);#enter key
    select undef, undef, undef, 0.1;
    $sel->type(q{xpath=//input[@class='search']}, $cards3->[1]);
    $sel->type_keys(q{xpath=//input[@class='search']}, $cards3->[1]);
    select undef, undef, undef, 0.1;
    $sel->key_press_native(10);#enter key
    select undef, undef, undef, 0.1;
    $sel->type(q{xpath=//input[@class='search']}, $cards3->[2]);
    $sel->type_keys(q{xpath=//input[@class='search']}, $cards3->[2]);
    select undef, undef, undef, 0.1;
    $sel->key_press_native(10);#enter key
    select undef, undef, undef, 0.1;
    sleep 1;
    $sel->click_at(q{xpath=//a[text()='I Picked This Card']}, 5, 5);
    select undef, undef, undef, 0.1;
}
sleep 1;
ok($sel->get_location() =~ /view_completed_run/, "view completed run");
ok(check_no_js_errors(), "no js errors");
$sel->stop();
done_testing();

sub check_no_js_errors {
    my $res = undef;
    eval {
        $res = $sel->get_attribute('dom=document.body@jserror');
    };
    if ($@) {
        return 1;
    } else {
        print STDERR "error: $res\n";
        return 0;
    }
}

sub get_three_random {
    my $cards_out = [];
    my $cards = $hm->card->get_cards_by_class('druid');
    my $cards_size = @{$cards};
    my $rand_card = int(rand($cards_size));
    my $rarity = $cards->[$rand_card]->{rarity};
    push($cards_out, $cards->[$rand_card]->{name});
    
    my $new_rand_card = undef;
    while(1) {
        $new_rand_card = int(rand($cards_size));
        last if $new_rand_card != $rand_card && $cards->[$new_rand_card]->{rarity} eq $rarity;
    }
    push($cards_out, $cards->[$new_rand_card]->{name});
    my $new_rand_card_2 = undef;
    while(1) {
        $new_rand_card_2 = int(rand($cards_size));
        last if $new_rand_card_2 != $rand_card &&  $new_rand_card_2 !=  $new_rand_card && $cards->[$new_rand_card_2]->{rarity} eq $rarity;
    }
    push($cards_out, $cards->[$new_rand_card_2]->{name});
    return $cards_out;
}