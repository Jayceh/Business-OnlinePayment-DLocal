#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Test::More tests => 5;
use Module::Runtime qw( use_module );
use Time::HiRes;

my $username = $ENV{PERL_BUSINESS_DLOCAL_USERNAME} || 'mocked';
my $password = $ENV{PERL_BUSINESS_DLOCAL_PASSWORD} || 'mocked';
my $secret   = $ENV{PERL_BUSINESS_DLOCAL_SECRET}   || 'mocked';

if ($username eq 'mocked') {
    diag '';
    diag '';
    diag '';
    diag 'All tests are run using MOCKED return values.';
    diag 'If you wish to run REAL tests then add these ENV variables.';
    diag '';
    diag 'export PERL_BUSINESS_DLOCAL_USERNAME=your_test_user';
    diag 'export PERL_BUSINESS_DLOCAL_PASSWORD=your_test_password';
    diag 'export PERL_BUSINESS_DLOCAL_PASSWORD=your_test_secret';
    diag '';
    diag '';
}

plan skip_all => 'No credentials set in the environment.'
  . ' Set PERL_BUSINESS_DLOCAL_USERNAME and '
  . ' PERL_BUSINESS_DLOCAL_SECRET and '
  . 'PERL_BUSINESS_DLOCAL_PASSWORD to run this test.'
  unless ( $username && $password );

my $client = new_ok( use_module('Business::OnlinePayment'), ['DLocal'] );
$client->test_transaction(1);    # test, dont really charge

my $data = {
 login          => $username,
 password       => $password,
 password2      => $secret,
 ##### action         => 'fetchByMerchantTransactionId',
 description    => 'Business::OnlinePayment visa test',

 division_number     => '1',
 type                => 'CC',
 amount              => '9000',
 customer_number     => '123',
 subscription_number => 'TEST-'.Time::HiRes::time(),
 invoice_number      => 'TEST-'.Time::HiRes::time(),
 authorization       => '123456',
 timestamp           => '2012-09-11T22:34:32.265Z',
 first_name          => 'Tofu',
 last_name           => 'Beast',
 address             => '123 Anystreet',
 city                => 'Anywhere',
 state               => 'UT',
 zip                 => '84058',
 country             => 'BR',
 currency            => 'USD',
 email               => 'tofu@beast.org',
 card_number         => '4111111111111111',
 cvv2                => '123',
 cpf => '123456789',
 expiration          => '12/25',
 vindicia_nvp        => {
     custom_test => 'BOP:DLocal unit test',
 }
};
my $trans;
foreach my $n ( 1 .. 3, 3 ) { # we do "3" twice to test what an error message looks like
    my %new_data = %$data;
    $new_data{'subscription_number'} .= "-$n";
    $new_data{'invoice_number'} .= "-$n";
    $new_data{'amount'} .= $n;
    push @$trans, \%new_data;
}

SKIP: { # Sale no token
    local $data->{'action'} = 'Normal Authorization';
    delete local $data->{'card_token'};
    $client->content(%$data);
    push @{$client->{'mocked'}}, {
        action => 'billTransactions',
        login => 'mocked',
        resp => 'ok_duplicate',
    } if $data->{'login'} eq 'mocked';
    my $ret = $client->submit();
    subtest 'Normal Authorization, with full card' => sub {
        plan tests => 3;
        ok(!$client->is_success, 'Transaction is_success failed as expected');
        ok($client->order_number, 'Transaction order_number found');
        subtest 'A transaction error exists, as expected' => sub {
            plan tests => 2;
            isa_ok($ret,'HASH');
            return unless ref $ret eq 'HASH';
            cmp_ok($ret->{'result'}, 'eq', '8', 'Found the expected error result');
        };
    } or diag explain $client->server_request,$client->server_response;
}

SKIP: { # Save
    local $data->{'action'} = 'Tokenize';
    $client->content(%$data);
    push @{$client->{'mocked'}}, {
        action => 'billTransactions',
        login => 'mocked',
        resp => 'ok_duplicate',
    } if $data->{'login'} eq 'mocked';
    my $ret = $client->submit();
    subtest 'Tokenize' => sub {
        plan tests => 2;
        ok($client->is_success, 'Transaction is_success');
        ok($client->card_token, 'Transaction card_token found');
    } or diag explain $client->server_request,$client->server_response;
    $data->{'card_token'} = $client->card_token; # all tests below will use this
}

SKIP: { # Sale with token
    skip 'No card_token was found', 1 unless $data->{'card_token'};
    local $data->{'action'} = 'Normal Authorization';
    $client->content(%$data);
    push @{$client->{'mocked'}}, {
        action => 'billTransactions',
        login => 'mocked',
        resp => 'ok_duplicate',
    } if $data->{'login'} eq 'mocked';
    my $ret = $client->submit();
    subtest 'Normal Authorization with card_token' => sub {
        plan tests => 3;
        ok($client->is_success, 'Transaction is_success');
        ok($client->order_number, 'Transaction order_number found');
        subtest 'A transaction result exists, as expected' => sub {
            plan tests => 2;
            isa_ok($ret,'HASH');
            return unless ref $ret eq 'HASH';
            cmp_ok($ret->{'result'}, 'eq', '9', 'Found the expected result');
        };
    } or diag explain $client->server_request,$client->server_response;
    $data->{'order_number'} = $client->order_number;
}

SKIP: { # Refund
    skip 'No order_number was found', 1 unless $data->{'order_number'};
    local $data->{'action'} = 'Credit';
    $client->content(%$data);
    push @{$client->{'mocked'}}, {
        action => 'billTransactions',
        login => 'mocked',
        resp => 'ok_duplicate',
    } if $data->{'login'} eq 'mocked';
    my $ret = $client->submit();
    subtest 'Refund' => sub {
        plan tests => 3;
        ok($client->is_success, 'Transaction is_success');
        ok($client->order_number, 'Transaction order_number found');
        subtest 'A transaction result exists, as expected' => sub {
            plan tests => 2;
            isa_ok($ret,'HASH');
            return unless ref $ret eq 'HASH';
            cmp_ok($ret->{'result'}, 'eq', '1', 'Found the expected result');
        };
    } or diag explain $client->server_request,$client->server_response;
}
