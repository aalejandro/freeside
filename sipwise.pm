package FS::cdr::sipwise;

use strict;
use base qw( FS::cdr );
use vars qw( %info );
use Date::Parse;
use FS::cdr qw( _cdr_date_parser_maker _cdr_min_parser_maker );

%info = (
  'name'          => 'Sipwise',
  'weight'        => 550,
  'header'        => 1,     #0 default, set to 1 to ignore the first line, or
                            # to higher numbers to ignore that number of lines

  #listref of what to do with each field from the CDR, in order
  'import_fields' => [    
    trim('uniqueid'),                    # 1 id
    skip(1),                    # 2 update_time
    skip(1),                    # 3 source_user_id
    skip(1),                    # 4 source_provider_id
    skip(1),                    # 5 source_ext_subscriber_id
    skip(1),                    # 6 source_subscriber_id
    skip(1),        	        # 7 source_ext_account_id
    trim('accountcode'),        # 8 source_account_id
    skip(1),                    # 9 source_user
    skip(1),                    # 10 source_domain
    trim('src'),                # 11 source_cli
    skip(1),                    # 12 source_clir
    trim('src_ip_addr'),        # 13 source_ip
    skip(1),                    # 14 destination_user_id
    skip(1),                    # 15 destination_provider_id
    skip(1),                    # 16 dest_ext_subscriber_id
    skip(1),                    # 17 dest_subscriber_id
    skip(1),                    # 18 dest_ext_account_id
    skip(1),                    # 19 destination_account_id
    skip(1),                    # 20 destination_user
    skip(1),                    # 21 destination_domain
    trim('dst'),                # 22 destination_user_in
    skip(1),                    # 23 destination_domain_in
    skip(1),                    # 24 dialed_digits
    skip(1),                    # 25 peer_auth_user
    skip(1),                    # 26 peer_auth_realm
    skip(1),                    # 27 call_type

    # http://www.sipwise.com/doc/mr3.2.1/spce/ar01s09.html#_file_format
    sub { my($cdr, $data) = @_;
	  $data =~ s/'//g;
          $cdr->disposition('ANSWERED')  if (lc($data) eq 'ok');
          $cdr->disposition('NO ANSWER') if (lc($data) eq 'no answer');
          $cdr->disposition('BUSY')      if (lc($data) eq 'busy');
            		     }, # 28 call_status

    skip(1),                    # 29 call_code
    sipwise_date_parser_maker('startdate'),  # 30 init_time
    sipwise_date_parser_maker('answerdate'),  # 31 start_time

    # setup time is not billed but counted in duration
    sub { my($cdr, $data) = @_; # 32 duration
	  $data =~ s/'//g;
	  my $setup = $cdr->answerdate - $cdr->startdate;
	  $cdr->billsec(int(sprintf("%.0f", $data)));
	  $data = $data + $setup;
	  $cdr->duration(int(sprintf("%.0f", $data))); },

    skip(1),                    # 33 call_id
    sub { my($cdr, $data) = @_;
	  $data =~ s/'//g;
	  die "Rating Status: $data. Not OK" if (lc($data) ne 'ok');
	}, 			# 34 rating_status
    skip(1),                    # 35 rated_at
    skip(1),                    # 36 source_carrier_cost
    trim('upstream_price'),     # 37 source_customer_cost
    skip(1),                    # 38 source_carrier_zone
    skip(1),                    # 39 source_customer_zone
    skip(1),                    # 40 source_carrier_destination
    skip(1),                    # 41 source_customer_destination
    skip(1),                    # 42 source_carrier_free_time
    skip(1),                    # 43 source_customer_free_time
    skip(1),                    # 44 destination_carrier_cost
    skip(1),                    # 45 destination_customer_cost
    skip(1),                    # 46 destination_carrier_zone
    skip(1),                    # 47 destination_customer_zone
    skip(1),                    # 48 destination_carrier_destination
    skip(1),                    # 49 destination_customer_destination
    skip(1),                    # 50 destination_carrier_free_time
    skip(1),                    # 51 destination_customer_free_time
    skip(1),                    # 52 source_reseller_cost
    skip(1),                    # 53 source_reseller_zone
    skip(1),                    # 54 source_reseller_destination
    skip(1),                    # 55 source_reseller_free_time
    skip(1),                    # 56 destination_reseller_cost
    skip(1),                    # 57 destination_reseller_zone
    skip(1),                    # 58 destination_reseller_destination
    skip(1),                    # 59 destination_reseller_free_time
    
  ],

);

sub sipwise_date_parse {
  my $date = shift;
  $date =~ s/'//g;
  # timestamps don't have decimals in freeside
  return sprintf("%.0f", str2time($date)); 
}


sub sipwise_date_parser_maker {
  my @fields = @_;
  return sub {
    my ($cdr, $datestring) = @_;
    my $unixdate = eval { sipwise_date_parse($datestring) };
    die "error parsing date for @fields from $datestring: $@\n" if $@;
    $cdr->$_($unixdate) foreach @fields;
  };
}

sub trim {
  my $fieldname = shift;
  return sub {
    my($cdr, $data) = @_;
    $data =~ s/^\+1//;
    $data =~ s/'//g;
    $cdr->$fieldname($data);
    ''
  }
}

sub skip {
  map { undef } (1..$_[0]);
}

1;

__END__

list of freeside CDR fields, useful ones marked with *

           acctid - primary key
    *[1]   calldate - Call timestamp (SQL timestamp)
           clid - Caller*ID with text
7   *      src - Caller*ID number / Source number
9   *      dst - Destination extension
           dcontext - Destination context
           channel - Channel used
           dstchannel - Destination channel if appropriate
           lastapp - Last application if appropriate
           lastdata - Last application data
10  *      startdate - Start of call (UNIX-style integer timestamp)
13         answerdate - Answer time of call (UNIX-style integer timestamp)
14  *      enddate - End time of call (UNIX-style integer timestamp)
    *      duration - Total time in system, in seconds
    *      billsec - Total time call is up, in seconds
12  *[2]   disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY
           amaflags - What flags to use: BILL, IGNORE etc, specified on a per
           channel basis like accountcode.
4   *[3]   accountcode - CDR account number to use: account
           uniqueid - Unique channel identifier
           userfield - CDR user-defined field
           cdr_type - CDR type - see FS::cdr_type (Usage = 1, S&E = 7, OC&C = 8)
    *[4]   charged_party - Service number to be billed
           upstream_currency - Wholesale currency from upstream
    *[5]   upstream_price - Wholesale price from upstream
           upstream_rateplanid - Upstream rate plan ID
           rated_price - Rated (or re-rated) price
           distance - km (need units field?)
           islocal - Local - 1, Non Local = 0
    *[6]   calltypenum - Type of call - see FS::cdr_calltype
           description - Description (cdr_type 7&8 only) (used for
           cust_bill_pkg.itemdesc)
           quantity - Number of items (cdr_type 7&8 only)
           carrierid - Upstream Carrier ID (see FS::cdr_carrier)
           upstream_rateid - Upstream Rate ID
           svcnum - Link to customer service (see FS::cust_svc)
           freesidestatus - NULL, done (or something)

[1] Auto-populated from startdate if not present
[2] Package options available to ignore calls without a specific disposition
[3] When using 'cdr-charged_party-accountcode' config
[4] Auto-populated from src (normal calls) or dst (toll free calls) if not present
[5] When using 'upstream_simple' rating method.
[6] Set to usage class classnum when using pre-rated CDRs and usage class-based
    taxation (local/intrastate/interstate/international)
