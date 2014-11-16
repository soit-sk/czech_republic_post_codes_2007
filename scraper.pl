#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use LWP::UserAgent;
use URI;
use Text::CSV;

# Don't buffer.
$OUTPUT_AUTOFLUSH = 1;

# URI of service.
my $base_uri = URI->new('http://zaloudek.kabel1.cz/priloha.php?id_priloha=310');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get data.
my $get = $ua->get($base_uri->as_string);
my $data;
if ($get->is_success) {
	$data = $get->content;
} else {
	die "Cannot GET '".$base_uri->as_string." page.";
}

# CSV object.
my $csv = Text::CSV->new({
	'binary' => 1,
	'sep_char' => ';',
});

# Parse.
foreach my $line (split m/\r\n/ms, $data) {
	my $status = $csv->parse($line);
	if (! $status) {
		die "Cannot parse data on '".$csv->error_input."'.";
	}
	my ($psc, $place) = $csv->fields;

	# Save.
	my $ret_ar = eval {
		$dt->execute('SELECT COUNT(*) FROM data WHERE PSC = ? '.
			'AND Place = ?', $psc, $place);
	};
	if ($EVAL_ERROR || ! @{$ret_ar} || ! exists $ret_ar->[0]->{'count(*)'}
		|| ! defined $ret_ar->[0]->{'count(*)'}
		|| $ret_ar->[0]->{'count(*)'} == 0) {

		print encode_utf8($psc.': '.$place)."\n";
		$dt->insert({
			'PSC' => $psc,
			'Place' => $place,
		});
	}
}
