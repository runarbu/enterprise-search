BEGIN {
	push @INC, $ENV{BOITHOHOME}."/Modules/";
};

use Getopt::Std;
use Boitho::Lot;

getopts('ls:', \%opts);


if ($opts{l}) {
	print "Will log all output to file\n";

	#dublicate stdout to log what is happening
# Runarb: 07.02.2012: This log is not biing rotated. Commenting it out for now.
#	open(STDOUT, ">>$ENV{'BOITHOHOME'}/logs/indexing") || die "Can't dup stdout";
#	open(STDERR, ">>&STDOUT") || die "Can't dup stdout";

}


my $lockfile = $ENV{'BOITHOHOME'} . '/var/cleanLots.lock';

my %hiestinlot = ();

#lager en l�s, slik at bare en kj�rer samtidig.
#todo: kansje lage en l�s pr collection?
open(LOCKF,">$lockfile") or die("can't lock lock file $lockfile: $!");
flock(LOCKF,2);

print "indexing:\n";

foreach my $lot (0 .. 4096) {

	my $Path = Boitho::Lot::GetFilPathForLot($lot,"");
	chop $Path;

	if (-e $Path) {

		opendir(DIR, $Path) or die("can't opendir $some_dir: $!");

		while (my $subname = readdir(DIR) ) {

			#skipper . og ..
			if ($subname =~ /\.$/) {
				next;
			}
	
			my $dirtyfile = $Path . $subname . '/dirty';

			if (-e $dirtyfile) {

				#hvis vi bare skal ha et subnavn h�pper vi over alle andre.
				if (defined($opts{'s'}) && ($subname ne $opts{'s'}) ) {
					print "Skipping subname $subname\n";
					next;
				}

				print "name $dirtyfile\n";
				print "lot $lot, subname $subname\n";

				$command = $ENV{'BOITHOHOME'} . "/bin/IndexerLotbb -i $lot \"$subname\"";
				print "runing $command\n";
				system($command);

				$command = $ENV{'BOITHOHOME'} . "/bin/mergeUserToSubname $lot \"$subname\"";
				print "runing $command\n";
                                system($command);




				unlink($dirtyfile) or warn($!);


				$hiestinlot{$subname} = $lot;
			}
		}

		closedir(DIR);

	}
}

print "\nmergeIIndex:\n";

foreach my $key (keys %hiestinlot) {
	print "key $key, value \"$hiestinlot{$key}\"\n";

	$command = $ENV{'BOITHOHOME'} . "/bin/mergeIIndex 1 $hiestinlot{$key} Main aa \"$key\"";
	print "runing $command\n";
	system($command);

	$command = $ENV{'BOITHOHOME'} . "/bin/mergeIIndex 1 $hiestinlot{$key} acl_allow aa \"$key\"";
	print "runing $command\n";
	system($command);

	$command = $ENV{'BOITHOHOME'} . "/bin/mergeIIndex 1 $hiestinlot{$key} acl_denied aa \"$key\"";
	print "runing $command\n";
	system($command);

	$command = $ENV{'BOITHOHOME'} . "/bin/mergeIIndex 1 $hiestinlot{$key} attributes aa \"$key\"";
	print "runing $command\n";
	system($command);

        $command = $ENV{'BOITHOHOME'} . "/bin/sortCrc32attrMap \"$key\"";
        print "runing $command\n";
        system($command);

	#kj�rer garbage collection.
#	$command = $ENV{'BOITHOHOME'} . "/bin/gcRepobb \"$key\"";
#	print "runing $command\n";
#	system($command);


}

# Clean search cache
print "Clining search cache.\n";
recdir($ENV{'BOITHOHOME'} . "/var/cache");

sub recdir {
    my ($path) = @_;


    print "recdir($path)\n";

    if (-e $path) {

      my $DIR;
      opendir($DIR, $path) or warn("can't opendir $path: $!") && return;

        while (my $file = readdir($DIR) ) {

                #skiping . and ..
                if ($file =~ /\.$/) {
                      next;
                }
                my $candidate = $path . "\/" . $file;

	        if (-d $candidate) {
	                recdir($candidate);
	        }
		else {
                	unlink($candidate) or warn("Cant delete cache file \"$candidate\": $!");
		}
      }

      closedir($DIR);


      rmdir($path) or warn("Cant delete dir \"$path\": $!");
    }


    return 1;
}

