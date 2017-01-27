package Business::OnlinePayment::DLocal;
use strict;
use warnings;

use Business::OnlinePayment;
use Business::OnlinePayment::HTTPS;
use Digest::SHA qw(hmac_sha256_hex);
use HTTP::Tiny;
use URI::Escape;
use XML::Simple;
use JSON;
use vars qw(@ISA $me $VERSION);
use Log::Scrubber qw(disable $SCRUBBER scrubber :Carp scrubber_add_scrubber);
@ISA     = qw(Business::OnlinePayment::HTTPS);
$me      = 'Business::OnlinePayment::DLocal';
$VERSION = '0.001';

# VERSION
# PODNAME: Business::OnlinePayment::DLocal
# ABSTRACT: Business::OnlinePayment::DLocal - DLocal (astropay) backend for Business::OnlinePayment


sub _info {
    return {
        info_compat       => '0.01',
        gateway_name      => 'DLocal',
        gateway_url       => 'http://www.dlocal.com',
        module_version    => $VERSION,
        supported_types   => ['CC'],
        supported_actions => {
            CC => [
                'Tokenize',
                'Normal Authorization',
                'Post Authorization',
                'Authorization Only',
                'Credit',
                'Auth Reversal',
                'PayStatus',
            ],
        },
    };
}

=method test_transaction

Get/set the server used for processing transactions.  Possible values are Live, Certification, and Sandbox
Default: Live

  #Live
  $self->test_transaction(0);

  #Certification
  $self->test_transaction(1);

=cut

sub test_transaction {
    my $self = shift;
    my $testMode = shift;
    if (! defined $testMode) { $testMode = $self->{'test_transaction'} || 0; }
    if($testMode) {
        $self->server('sandbox.astropaycard.com');
        $self->port('443');
        $self->path('/api_curl/cc/sale');
    } else {
        $self->server('astropaycard.com');
        $self->port('443');
        $self->path('/api_curl/cc/sale');
    }
    return $self->{'test_transaction'};
}

# SAVE
# SALE

=method SALE

Mandatory parameters

Field    Format    Description    One-Shot / Recurrent    Example    
x_login    String (length: 32 chars)    Your merchant ID in Astropay    Both    AsGsd35Grf    1
x_trans_key    String (length: 32 chars)    Your merchant password in Astropay    Both    D23weF2f4g    1
x_version    String (Format: X.Y)    API version    Both    4.0    
x_invoice    String (max. lenght 200 chars)    Unique transaction identification at the merchant site.    Both    Invoice1234    
x_amount    Decimal (max. 2 decimal numbers)    Transaction amount (in the currency entered in the field “x_currency”)    Both    100.95    
x_currency    String (length: 3 chars)    Currency code    Both    BRL    
x_description    String (max. length: 200 chars)    A description of the payment    Both    Product 123    
x_device_id    String    Buyer's device Id. See Device id.    Both    54hj4h5jh46hasjd    
x_country    String (max. length: 2 chars)    User’s country. in ISO 3166-1 alpha-2 codes    One-Shot / Recurrent without token    BR    
x_cpf    Number (max. 30 digits)    User’s personal identification number: CPF or CNPJ for Brazil, DNI for Argentina and ID for other countries.    One-Shot    123456789    
x_name    String    User’s full name.    One-Shot    Ivan Lolivier    
x_email    String    User’s email address.    One-Shot    santiago@astropay.com    
cc_number    Number (16 digits)    User's credit card number    One-Shot / Recurrent without token    4111111111111111    
cc_exp_month    Number (2 digits)    Credit card expiration month    One-Shot / Recurrent without token    02    
cc_exp_year    Number (4 digits)    Credit card expiration year    One-Shot / Recurrent without token    2018    
cc_cvv    Number (max length: 4 digits)    Credit card verification value    One-shot    425    
cc_token    String    Token obtained in Save function    Recurrent    1aj2l3g4gj4fh5d5hh6d605    
control    String    Control string    Both    JASG44DNNGIJ34IJ34OKOEWJNCV874Y4UY    2


 Control string

$secretkey – secret key given to the merchant
$invoice– unique transaction ID at merchant (x_invoice)
$amount–payment amount (x_amount)
$currency–payment currency (x_currency)
$email– user’s email address (x_email)
$number–credit card number (cc_number)
$cvv–credit card cvv (cc_cvv)
$month – credit card expiration month (cc_exp_month)
$year – credit card expiration year (cc_exp_year)
$cpf – user’s document (x_cpf)
$country – country code (x_country)
$token – credit card token (cc_token)

Optional parameters

Field    Format    Description    One-Shot / Recurrent    Example    Default
x_bank    String (max. 3 digits)    Payment method code. See payment method codes.    One-Shot / Recurrent without token (only Mexico)    VI    
cc_issuer    Number    Credit card issuer bank. See issuer bank codes.    One-Shot / Recurrent without token    105    
cc_installments    Number    Number of installments    One-Shot    3    1
cc_descriptor    String (max: 13 char)    Dynamic Descriptor    Both    AP Payment    
x_ip    String    Buyer's IP address    Both    200.11.222.3    
x_confirm    String    To be provided if the confirmation URL is different from the confirmation URL registered by the merchant.    Both    http://merchant/confirm    
x_bdate    String    User’s date of birth (Format: YYYYMMDD)    One-Shot    19850812    
x_iduser    Decimal (max. 20 chars)    Unique user id at the merchant side    One-Shot    user 123    
x_address    String    User’s address    One-Shot    1225 Bonavita St.    
x_zip    String    User’s zip/postal code    One-Shot    11300    
x_city    String    User’s city    One-Shot    Sao Paulo    
x_state    String (max. 3 chars)    User’s state. Brazilian 2 letter format    One-Shot    MO    
x_phone    String    User’s phone number    One-Shot    099123456    
x_merchant_id    String    Sub merchant identifier (only for PSPs). List of sub- merchants must be provided by PSP    Both    1    

Response

This function, if successful, returns a json with the following parameters:
Field    Description    
status    OK    
desc    Response description message    
control    Control string    1
result    Transaction result. See possible results.    
x_invoice    Unique transaction ID number at the merchant    
x_document    Unique transaction ID number at AstroPay. This information should be stored for future use.    
x_currency    Currency code    
x_amount    Transaction amount (in the currency entered in the field “x_currency”).    
x_amount_paid    The amount finally charged to the user, in local currency. It includes finance charges (if applies).    
cc_descriptor    The transaction descriptor that will appear in the user’s statement    
x_description    The description of the payment    
cc_token    Token obtained in Save function    
x_iduser    Unique user id at the merchant side    1 

Control signature

$secretkey – secret key given to the merchant
$result – transaction result code
$amount – payment amount (x_amount)
$currency – payment currency (x_currency)
$invoice – unique transaction ID at merchant (x_invoice)
$document – unique transaction ID at AstroPay (x_document)

=cut

# REFUND
# PAYMENT STATUS
# REFUND STATUS
# CURRENCY EXCHANGE
# INSTALLMENTS

sub build_control {
    'TODO not built yet';
}

sub field_map {
    return (
        # DLOCAL #        => # BOP #
        'x_login'         => 'login',           # reports_login
        'x_trans_key'     => 'password',        # reports_key
        'x_secret_key'    => 'password2',
        'x_version'       => 'version',
        'x_country'       => 'country',
        'x_invoice'       => 'invoice_number',
        'x_document'      => 'order_number',
        'x_amount'        => 'amount',
        'x_currency'      => 'currency',
        'x_description'   => 'description',
        'x_device_id'     => 'device_id',
        'x_cpf'           => 'cpf',             # govt id number
        'x_name'          => 'name',            # needs a joiner of this in map fields
        'x_email'         => 'email',
        'cc_number'       => 'card_number',
        'cc_exp_month'    => 'expirationMM',    # needs to be broken in two
        'cc_exp_year'     => 'expirationYY',
        'cc_cvv'          => 'cvv2',
        'cc_token'        => 'card_token',
        'x_bank'          => 'bank',            # looks to be card, but others... different key
        'cc_issuer'       => 'issuer',          # same
        'cc_installments' => 'installments',    # similar breakout one-shot vs a number
        'cc_descriptor'   => 'descriptor',
        'x_ip'            => 'customer_ip',
        'x_confirm'       => 'confirm',         # a confirmation URL if passed, similar to paypal IPN
        'x_bdate'         => 'birthdate',       # WTF is this needed
        'x_iduser'        => 'customer_id',
        'x_address'       => 'address',
        'x_zip'           => 'zip',
        'x_city'          => 'city',
        'x_state'         => 'state',
        'x_phone'         => 'phone',
        'x_merchant_id'   => 'merch_id',       # sub-merchant id, lmk if you ever use this, no normal BOP standard here

        'x_auth_id'      => 'order_number',

        control         => 'control',
        type            => 'type',
    );
}

sub content {
    my $self = shift;
    my %content = $self->SUPER::content(@_);

    # Adjust common %content BOP format to what DLOCAL needs
    if ($content{'expiration'} && $content{'expiration'} =~ /^(\d\d)\/(\d\d)/) {
        $content{'expirationMM'} //= $1;
        $content{'expirationYY'} //= '20'.$2;
    }
    if (! exists $content{'name'}) {
        $content{'name'} = $content{'first_name'}//'';
        $content{'name'} .= ' ' if length($content{'name'});
        $content{'name'} .= $content{'last_name'} if length($content{'last_name'}//'');
    }
    $content{'version'} //= $self->api_version;
    $content{'type'} = 'json';

    return %content;
}

sub submit {
    my $self = shift;
    my %content = $self->content();
    die 'Missing action' unless $content{'action'};

    my $action;
    foreach (@{$self->_info()->{'supported_actions'}->{'CC'}}) {
        if (lc($_) eq lc($content{'action'})) {
            $action = lc('_'.$_);
            $action =~ s/ /\_/g;
        }
    }
    if ($action && $self->can($action)) {
        return $self->$action(\%content);
    } else {
        die 'Unsupported action';
    }
}

sub _normal_authorization { shift->_authorization_only(@_); }

sub _authorization_only {
    my ($self,$content) = @_;

    if ($content->{'card_token'}) {
        # tokens fail if you try and send these as well
        my %remap_fields = $self->field_map();
        foreach ('x_country','x_cpf','x_name','x_email','cc_number','cc_exp_month','cc_exp_year','cc_cvv') {
            delete $content->{$remap_fields{$_}};
        }
    }

    my $config = {
        url => 'https://'.$self->server.'/api_curl/cc/'.(lc($content->{'action'})eq 'normal authorization' ? 'sale' : 'auth'),
        control => ['x_invoice','x_amount','x_currency','x_email','cc_number','cc_exp_month','cc_cvv','cc_exp_year','x_cpf','x_country','cc_token'],
        post_data => ['x_login','x_trans_key','x_version','x_invoice','x_amount','x_currency','x_description','x_device_id','x_country',
                    'x_cpf','x_name','x_email','cc_number','cc_exp_month','cc_exp_year','cc_cvv','cc_token','control','type'],
    };

    my $res = $self->_send_request($config,$content);
    $self->is_success( defined $res->{'result'} && $res->{'result'} =~ /^9|11$/ ? 1 : 0 );
    $self->order_number( $res->{'x_document'} // $res->{'x_auth_id'} ); # sale vs auth
    $res;
}

sub _post_authorization{
    my ($self,$content) = @_;

    my $config = {
        url => 'https://'.$self->server.'/api_curl/cc/capture',
        control => ['x_invoice','x_auth_id','x_amount','x_currency'],
        post_data => ['x_login','x_trans_key','x_version','x_invoice','x_amount','x_currency','x_auth_id','control','type'],
    };

    my $res = $self->_send_request($config,$content);
    $self->is_success( defined $res->{'result'} && $res->{'result'} =~ /^9|11$/ ? 1 : 0 );
    $self->order_number( $res->{'x_document'} // $res->{'x_auth_id'} ); # sale vs auth
    $res;
}

sub _tokenize {
    my ($self,$content) = @_;

    my $config = {
        url => 'https://'.$self->server.'/api_curl/cc/save',
        control => ['x_email','cc_number','cc_exp_month','cc_cvv','cc_exp_year','x_cpf','x_country'],
        post_data => ['x_login','x_trans_key','x_version','x_country','x_cpf','x_name','x_email','cc_number','cc_exp_month','cc_exp_year','cc_cvv','control','type'],
    };

    my $res = $self->_send_request($config,$content);
    $self->is_success( $res->{'cc_token'} ? 1 : 0 );
    $self->card_token( $res->{'cc_token'} );
    $res;
}

sub _credit {
    my ($self,$content) = @_;

    my $config = {
        url => 'https://'.$self->server.'/api_curl/cc/refund',
        control => ['x_document','x_invoice','x_amount','x_currency'],
        post_data => ['x_login','x_trans_key','x_version','x_invoice','x_document','x_amount','x_currency','control','type'],
    };

    my $res = $self->_send_request($config,$content);
    $self->is_success( defined $res->{'result'} && $res->{'result'} eq '1' ? 1 : 0 );
    $self->order_number( $res->{'x_document'} );
    $res;
}

sub _paystatus {
    my ($self,$content) = @_;

    my $config = {
        url => 'https://'.$self->server.'/api_curl/query/paystatus',
        control => [], # not used
        post_data => ['x_login','x_trans_key','x_version','x_invoice','x_document','type'],
    };

    # query api uses different credentials
    local $content->{'login'} = $content->{'reports_login'};
    local $content->{'password'} = $content->{'reports_key'};

    my $res = $self->_send_request($config,$content);
    $self->is_success( defined $res->{'result'} ); # any result is a positive think for a query call
    $self->order_number( $res->{'x_document'} );
    $res;
}

sub _send_request {
    my ($self,$config,$content) = @_;
    my %content = %$content;
    my %remap_fields = $self->field_map();

    my $message = '';
    foreach my $key ( @{$config->{'control'}} ) { $message .= $content{$remap_fields{$key}}//''; }
    local $content{'control'} = uc(hmac_sha256_hex(pack('A*',$message), pack('A*',$content{'password2'})));

    my $post_data;
    foreach my $key ( @{$config->{'post_data'}} ) {
        $post_data .= uri_escape($key).'='.uri_escape($content{$remap_fields{$key}}).'&' if $content{$remap_fields{$key}};
    }
    my $url = $config->{'url'};
    $self->server_request( $url.'?'.$post_data ); # yeah it's in GET, but it's easy to read that way
    my $verify_ssl = 1;
    my $response = HTTP::Tiny->new( verify_SSL=>$verify_ssl )->request('POST', $url, {
        headers => {
            'Content-Length' => length($post_data),
            'Content-Type' => 'application/x-www-form-urlencoded',
            'Accept' => 'application/json',
        },
        content => $post_data,
    } );
    $self->server_response( $response->{'content'} );
    my $res = substr($response->{'content'},0,1) eq '{'
        ? decode_json( $response->{'content'} )
        : $self->_parse_xml_response( $response->{'content'}, $response->{'status'} ); # just in case
    $res;
}

sub _parse_xml_response {
    my ( $self, $page, $status_code ) = @_;
    my $response = {};
    if ( $status_code =~ /^200/ ) {
        if ( ! eval { $response = XMLin($page); } ) {
            die "XML PARSING FAILURE: $@";
        }
    }
    else {
        $status_code =~ s/[\r\n\s]+$//; # remove newline so you can see the error in a linux console
        if ( $status_code =~ /^(?:900|599)/ ) { $status_code .= ' - verify DLocal has whitelisted your IP'; }
        die "CONNECTION FAILURE: $status_code";
    }
    return $response;
}

=method server_request

Returns the complete request that was sent to the server.  The request has been stripped of card_num, cvv2, and password.  So it should be safe to log.

=cut

sub server_request {
    my ( $self, $val, $tf ) = @_;
    if ($val) {
        $self->{server_request} = scrubber $val;
        $self->server_request_dangerous($val,1) unless $tf;
    }
    return $self->{server_request};
}

=method server_request_dangerous

Returns the complete request that was sent to the server.  This could contain data that is NOT SAFE to log.  It should only be used in a test environment, or in a PCI compliant manner.

=cut

sub server_request_dangerous {
    my ( $self, $val, $tf ) = @_;
    if ($val) {
        $self->{server_request_dangerous} = $val;
        $self->server_request($val,1) unless $tf;
    }
    return $self->{server_request_dangerous};
}

=method server_response

Returns the complete response from the server.  The response has been stripped of card_num, cvv2, and password.  So it should be safe to log.

=cut

sub server_response {
    my ( $self, $val, $tf ) = @_;
    if ($val) {
        $self->{server_response} = scrubber $val;
        $self->server_response_dangerous($val,1) unless $tf;
    }
    return $self->{server_response};
}

=method server_response_dangerous

Returns the complete response from the server.  This could contain data that is NOT SAFE to log.  It should only be used in a test environment, or in a PCI compliant manner.

=cut

sub server_response_dangerous {
    my ( $self, $val, $tf ) = @_;
    if ($val) {
        $self->{server_response_dangerous} = $val;
        $self->server_response($val,1) unless $tf;
    }
    return $self->{server_response_dangerous};
}


=method set_defaults

=cut

sub set_defaults {
    my $self = shift;
    my %opts = @_;

    $self->build_subs(
        qw( order_number card_token api_version )
    );

    $self->test_transaction(0);

    if ( $opts{debug} ) {
        $self->debug( $opts{debug} );
        delete $opts{debug};
    }

    ## load in the defaults
    my %_defaults = ();
    foreach my $key ( keys %opts ) {
        $key =~ /^default_(\w*)$/ or next;
        $_defaults{$1} = $opts{$key};
        delete $opts{$key};
    }

    $self->{_scrubber} = \&_default_scrubber;
    if( defined $_defaults{'Scrubber'} ) {
        my $code = $_defaults{'Scrubber'};
        if( ref($code) ne 'CODE' ) {
            warn('default_Scrubber is not a code ref');
        }
        else {
            $self->{_scrubber} = $code;
        }
    }

    $self->api_version('4.0')                   unless $self->api_version;
}
1;
