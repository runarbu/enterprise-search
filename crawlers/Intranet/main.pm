#!/usr/bin/perl
use strict;
package Perlcrawl;
use SD::Crawl;

#use SOAP::Lite(  +trace => 'all', readable => 1, outputxml => 1, );
#use SOAP::Lite(readable => 1, outputxml => 1, );
use XML::XPath;
use SD::sdCrawl;
use LWP::RobotUA;
use URI;
 
 

#use Data::Dumper;
my $pointer; 
#my $soap_client;
my $robot;
my $bot_name = "sdbot/0.1";
my $bot_email = "bs\@searchdaimon.com";
sub init_robot { 
   my $timeout = 4;
 
   $robot = LWP::RobotUA->new($bot_name, $bot_email);
   $robot->delay(0); # "/60" to do seconds->minutes
   $robot->timeout($timeout);
   $robot->requests_redirectable([]); # comment this line to allow redirects
   $robot->protocols_allowed(['http','https']);  # disabling all others
}

sub crawlpatAcces  {
    my ($self, $pointer, $opt ) = @_;
    my $user = $opt->{'user'};
    my $passw  = $opt->{'password'};
    my $url = $opt->{"resource"};
     if (!defined($robot)) { init_robot() ; }

   my $req = HTTP::Request->new(HEAD => $url);
   print "Authenticating :  ", $user, "  password  ",  $passw, " at ", $url , "\n";
 
    if ($user) { 
        $req->authorization_basic($user, $passw); 
    }

    my $response = $robot->request($req);
  
    if ($response->is_success) { return 1; }

    print "Not authenticated :  ", $user, "  password  ", $passw, " at ", $url , "\n";
    return 0;
}

sub crawlupdate {	
   my ($self, $pointer, $opt ) = @_;	

    my $user = $opt->{"user"};
    my $passw = $opt->{"password"};
    my $Urls = $opt->{"resource"};
    my $starting_url;
  
    my @urlList = split /;/, $Urls;
    my @exclusionsUrlPart = qw ( );  # See Sharpoint crawler on how to use this
    my @exclusionQueryPart = qw(); # See Sharpoint crawler on how to use this
    my @allowedCountries = qw();

    SD::sdCrawl::process_starting_urls(@urlList);
    SD::sdCrawl::setDelay(1);
    #SD::sdCrawl::doFarUrls();
    SD::sdCrawl::setAllowedCountries(@allowedCountries);
    #SD::sdCrawl::setExclusionUrlParts(@exclusionsUrlPart);
    #SD::sdCrawl::setIISpecial(); Consider using this if crawling windows machines
 
    foreach $starting_url(@urlList) {
       my $url = URI->new(@urlList[0]);
       my $acl = "Everyone";

      SD::sdCrawl::Init($pointer, $bot_name, , "email\@email.com", $acl, $user, $passw);
      SD::sdCrawl::Start($starting_url);
   }
}


