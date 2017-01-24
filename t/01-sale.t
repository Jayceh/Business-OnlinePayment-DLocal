#!/usr/bin/env perl

use 5.010;
use strict;
use warnings;

use Test::More tests => 7;
use Module::Runtime qw( use_module );
use Time::HiRes;

my $username = $ENV{PERL_BUSINESS_DLOCAL_USERNAME} || 'mocked';
my $password = $ENV{PERL_BUSINESS_DLOCAL_PASSWORD} || 'mocked';

if ($username eq 'mocked') {
    diag '';
    diag '';
    diag '';
    diag 'All tests are run using MOCKED return values.';
    diag 'If you wish to run REAL tests then add these ENV variables.';
    diag '';
    diag 'export PERL_BUSINESS_DLOCAL_USERNAME=your_test_user';
    diag 'export PERL_BUSINESS_DLOCAL_PASSWORD=your_test_password';
    diag '';
    diag '';
}

plan skip_all => 'No credentials set in the environment.'
  . ' Set PERL_BUSINESS_DLOCAL_USERNAME and '
  . 'PERL_BUSINESS_DLOCAL_PASSWORD to run this test.'
  unless ( $username && $password );

my $client = new_ok( use_module('Business::OnlinePayment'), ['DLocal'] );
$client->test_transaction(1);    # test, dont really charge

my $data = {
 login          => $username,
 password       => $password,
 password2      => 'VOrG5yNQk6NGzX9M8rQJUffV5E5yeDDpx',
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
 card_token          => '1',
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

SKIP: { # Sale
    local $data->{'action'} = 'Normal Authorization';
    $client->content(%$data);
    push @{$client->{'mocked'}}, {
        action => 'billTransactions',
        login => 'mocked',
        resp => 'ok_duplicate',
    } if $data->{'login'} eq 'mocked';
    my $ret = $client->submit();
    subtest 'Normal Authorization' => sub {
        plan tests => 3;
        ok($client->is_success, 'Transaction is_success');
        ok($client->order_number, 'Transaction order_number found');
        subtest 'A transaction error exist, as expected' => sub {
            plan tests => 3;
            isa_ok($ret->{'response'},'ARRAY');
            return unless ref $ret->{'response'} eq 'ARRAY';
            cmp_ok(scalar @{$ret->{'response'}}, '==', 1, 'Found the expected number of errors');
            cmp_ok($ret->{'response'}->[0]->{'code'}, '==', '400', 'Found the expected error result');
        };
    } or diag explain $client->server_request,$client->server_response;
}
