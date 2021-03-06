package Page::System;
use strict;
use warnings;
use Sql::Config;

BEGIN {
	unshift @INC, "Modules";
}

use Carp;
use config qw($CONFIG);
use Data::Dumper;
use Boitho::RaidStatus qw(getraidinfo);
use Boitho::Infoquery;
use Page::Abstract;
our @ISA = qw(Page::Abstract);

my $modules_missing;
BEGIN {
    eval {
        require SD::LotInfo;
    };
    if ($@) { 
        $modules_missing = $@;
        warn $@;
    }
}

use config qw($CONFIG);

my $lotinfo;

sub _init {
	my $s = shift;
	$s->{'sqlConfig'} = Sql::Config->new($s->{dbh});
	$s->{'infoQuery'} = Boitho::Infoquery->new($CONFIG->{'infoquery'});
        eval {
            $lotinfo = SD::LotInfo->new($CONFIG->{'maplist_path'});
        };
        warn $@ if $@;
}

sub show_system_diagnostics {
	my ($self, $vars, $opt_ref) = @_;
	my $template_file = "system_main.html";
	my @lots = $lotinfo->lot_info($opt_ref)
            if defined $lotinfo;

	if (defined $opt_ref) {
		# asume we want to see lot details if we specified options.
		$vars->{'show_lot_details'} = 1;
	}

        $vars->{modules_missing} = $modules_missing;
	$vars->{'lotinfo'}     = \@lots
            if @lots;
	$vars->{'raid'} 	   = $self->_raid_status;
	#$vars->{'integration'} = $self->_integration_status;
	
	return ($vars, $template_file);
}

# Gets a list of all raid drives, and a list of offline drives.
# Merges the info into one array, and sorts it by online/offline.
sub _raid_status($) {
	my $self = shift;
	my (@drives, %raiddrives, %raiddrivesnotused);
	my %status;

	eval {
		my ($raiddrives_ptr,
			$raiddrivesnotused_ptr,
			$raidsetups_ptr) 
				= getraidinfo();
		%raiddrives = %$raiddrives_ptr;
		%raiddrivesnotused = %$raiddrivesnotused_ptr;
	};
	
 	if ($@) { # Didn't get raid info
 		$status{'error'} = $@;
 		return \%status;
 	}
	
	
 	foreach my $name (keys %raiddrives) { 
 		my %drive;
 		$drive{'name'} = $name;
 		
 		if (defined($raiddrivesnotused{$name})) {
 			$drive{'online'} = 0;
 			$status{'error'} = "Drive offline";
 		}
 		else {
 			$drive{'online'} = 1;
 		}	
 		push @drives, \%drive;
 	}
	
	# debug data:
	# @drives = ({'name' => "hda2", 'online' => 1}, 
	#		   {'name' => "hdb2", 'online' => 0});
	
	@drives = sort { $b->{'online'} <=> $a->{'online'} } @drives;
	$status{'drives'} = \@drives;
	
	return (\%status);
	
}

#sub _integration_status($$) {
#	my $self = shift;
#	my $sqlConfig = $self->{'sqlConfig'};
#	my $infoQuery = $self->{'infoQuery'};
#	
#	my $method = $sqlConfig->get_authenticatmethod;
#	my %status = ('method' => $method);
#	
#	# is valid method
#	unless ($sqlConfig->is_valid_authmethod($method)) {
#		$status{'error'}  = "Invalid authentication method ($method) used.";
#		return \%status;
#	}
#	
#	# can connect to dap
#	if (my $settings_ptr = $sqlConfig->get_dap_settings($method)) {
#		my %settings = %$settings_ptr;
#		my @param = (
#			$settings{'domain'},
#			$settings{'user'},
#			$settings{'password'},
#			$settings{'ip'},
#			$settings{'port'});
#		my ($success, $errormsg) = $infoQuery->authTest($method, @param);
#		
#		unless ($success) {
#			$status{'error'} = $errormsg;
#			return \%status;
#		}
#	}
#		
#	return \%status;
#}
#

1;
