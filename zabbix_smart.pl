#!/usr/bin/perl

use strict;
use JSON;
use Data::Dumper;

my $script_name = $0;

if ($ARGV[0] eq 'install') {
	open(F, '>', '/etc/zabbix/zabbix_agentd.conf.d/userparameter_smartctl.conf') or die $!;
	print F "UserParameter=smartctl.discovery,sudo $script_name discovery\n";
	close F;

	open(F, '>', '/etc/sudoers.d/zabbix') or die $!;
	print F "Defaults:zabbix !requiretty\n";
	print F "zabbix ALL=(ALL) NOPASSWD: $script_name\n";
	close F;

	open(F, '>', '/etc/cron.d/zabbix_smartctl') or die $!;
	print F "SHELL=/bin/bash\n";
	print F "PATH=/sbin:/bin:/usr/sbin:/usr/bin\n";
	print F "MAILTO=root\n";
	print F "*/10 * * * * root $script_name cron | /usr/bin/zabbix_sender -c /etc/zabbix/zabbix_agentd.conf -i -\n";
	close F;
	`/etc/init.d/zabbix-agent restart`;
	print "OK\n";
}
elsif ($ARGV[0] eq 'discovery') {
	my @devs = get_disks();
	my %discovery = (
		'data' => \@devs,
	);
	print encode_json \%discovery;
}
elsif ($ARGV[0] eq 'cron') {
	my @devs = get_disks();
	foreach my $ref (@devs) {
		#`smartctl -A -H -i -d $ref->{'{#DEVTYPE}'} $ref->{'{#DEVNAME}'} | $dir/smart2zabbix.sh /dev/${attr[0]} ${attr[1]} - | /usr/bin/zabbix_sender -c $AGENT_CFG -i -`;
		#print Dumper $ref;
		print join "\n", get_smartctl($ref, '-');
		print "\n";
	}
}
sub get_smartctl {
	my $ref = shift;
	my $hostname = shift;
	my %uniq;
	my @res;
	my @dev_array = split(/\//, $ref->{'{#DEVNAME}'});
	my $dev = pop @dev_array;

	my $data = `smartctl -A -H -i -d $ref->{'{#DEVTYPE}'} $ref->{'{#DEVNAME}'}`;
	my @lines = split /[\r\n]+/, $data;
	my $section = '';
	foreach my $line (@lines){
		if ($line =~ /START OF INFORMATION SECTION/i) {
			$section = 'INFO';
		}
		elsif($line =~ /START OF READ SMART DATA SECTION/i) {
			$section = 'HEALF';
		}
		elsif($line =~ /ID#/i){
			$section = 'ATTR';
		}
		
		if ($section eq 'INFO') {
			if ($line =~ /^([^:]+):(.+)$/) {
				my $key = trim(lc $1);
				my $value = trim($2);
				$key =~ s/ /_/g;
				$value = "\"$value\"" if ($value !~ /^\d+$/);
				next if (exists $uniq{$key});
				$uniq{$key} = 1;
				push @res, "$hostname smartctl.info\[$dev,$key\] $value";
			}
		}
		elsif ($section eq 'HEALF') {
			if ($line =~ /SMART overall-health self-assessment test result: (.+)$/) {
				push @res, "$hostname smartctl.smart\[$dev,test_result\] \"$1\"";
			}
		}
		elsif($section eq 'ATTR') {
			my %a = (1 => 'attribute_name',2 => 'flag',3 => 'value',4 => 'worst',5 => 'thresh',6 => 'type',7 => 'updated',8 => 'when_failed',9 => 'raw_value');
			my @attrs = split /\s+/, trim($line);
			my $id = $attrs[0];
			next if ($id !~ /^\d+$/);
			foreach my $index (keys %a) {
				my $attr = $a{$index};
				my $value = trim($attrs[$index]);
				if ($value !~ /^\d+$/) {
					$value = "\"$value\""
				}
				else {
					$value = int($value)
				}
				push @res, "$hostname smartctl.smart\[$dev,$id,$attr\] $value";
			}
		}
	}
	return @res;
}
sub get_disks {
	my @res;
	my $data = `smartctl --scan`;
	my @lines = split /[\r\n]+/, $data;
	foreach my $line (@lines) {
		if ($line =~ /(\/dev\/[^\s]+) /){
			my %row = ('{#DEVNAME}' => $1, '{#DEVTYPE}' => 'sat');
			push @res, \%row;
		}
	}
	return @res;
}
sub trim {
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}