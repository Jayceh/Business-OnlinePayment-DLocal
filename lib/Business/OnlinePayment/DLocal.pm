package Business::OnlinePayment::DLocal;
use strict;
use warnings;

use Business::OnlinePayment;
use Business::OnlinePayment::HTTPS;
use Digest::SHA qw(hmac_sha256);
use Log::Scrubber qw(disable $SCRUBBER scrubber :Carp scrubber_add_scrubber);

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
                'Normal Authorization',
                'Post Authorization',
                'Authorization Only',
                'Credit',
                'Auth Reversal',
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
        $self->path('/api_curl');
    } else {
        $self->server('astropaycard.com');
        $self->port('443');
        $self->path('/api_curl');
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

sub submit {
    my $self = shift;
    my ( $page, $status_code, %headers ) = $self->https_post( { } , $post_data);
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

1;
