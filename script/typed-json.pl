#######################################################################################################
# Copyright 2017 Marcel Greter
# https://www.github.com/mgreter
#######################################################################################################
# I have created this mainly for a ThreeJS ISS model I had around
# It is basically a big json with lots of numerical arrays (1.5MB)
# I already optimized other big typed arrays to use binary buffers
#######################################################################################################
# 1) read in the original json and do some normalization
#    data came from js and is not strictly json compatible
#    only minimal normalization, more stuff could be added
#    like converting from single quites to double quotes
# 2) go through the json tree (object/arrays) and find
#    suitable arrays that only contain numeric values
#    also find out which numeric type (size) we can use
#    mark those items with optimizable arrays for later
# 3) create buffer to be used directly in javascript
#    add header so javascript can load all arrays
#    we get byte offsets and length directly:
#    new Float32Array(buffer, offset, length)
# 4) create altered json (inclusive array mappings)
#    enable to map arrays later in the json
# 5) use `TypedJson` function to load results
#######################################################################################################

use strict;
use warnings;

#######################################################################################################
BEGIN { push @INC, "lib"; }
#######################################################################################################

# bring in some functions
use Scalar::Util::Numeric qw(isint);
use Scalar::Util qw(looks_like_number);
use List::Util qw(first);
use File::Slurp;
use JSON; 

#######################################################################################################
# use GetOpt::Long qw(GetOptions);
#######################################################################################################

# read flag for lzma compression option
my $compress = scalar(grep { /^-c$/ } @ARGV);
@ARGV = grep { ! /^-c$/ } @ARGV; # cleanup

# get command line arguments (input and output)
my $input = $ARGV[0] || die "Usage: ",
	$0, " [-c] input{.json} [output{.jdb}]\n";
$input =~ s/\.json$//; # remove json file extension
my $output = $ARGV[1] || $input; # deduct from input?
$output =~ s/\.jdb$//; # remove json file extension

#######################################################################################################
#######################################################################################################

# options to pass to read/write file
my $slurpopt = { binmode => ':raw' };

# use globals for now
our (@paths, %maps);

# optimized arrays
our (@uint8, @int8);
our (@uint16, @int16);
our (@uint32, @int32);
our (@float32, @float64);

# header format
our @header = (
	# force little-endian byte-order
	["float64", \@float64, "d<", 8], # double precision float
	["float32", \@float32, "f<", 4], # single precision float
	["uint32", \@uint32, "L<", 4], # unsigned long
	["int32", \@int32, "l<", 4], # signed long
	["uint16", \@uint16, "S<", 2], # unsigned short
	["int16", \@int16, "s<", 2], # signed short
	["uint8", \@uint8, "C", 1], # unsigned char
	["int8", \@int8, "c", 1], # signed char
);

# walk deeper into object
sub processHash
{
	my ($obj) = @_;
	# assert that we really have an object
	die "Need Hash" unless ref $obj eq "HASH";
	# process all inner values
	foreach my $key (keys %{$obj}) {
		push @paths, $key;
		processScalar($obj->{$key});
		pop @paths;
	}
	# return ourself
	return $obj;
}

# find out if array 
sub processArray
{
	my ($arr) = @_;
	# assert that we really have an array
	die "Need Array" unless ref $arr eq "ARRAY";
	# check if array can be binarified
	# possible if all items are numbers
	my $isInt8 = 1; my $isUint8 = 1;
	my $isInt16 = 1; my $isUint16 = 1;
	my $isInt32 = 1; my $isUint32 = 1;
	my $isFloat32 = 1; my $isFloat64 = 1;

	# for now we don't implement 64bit floats
	# I don't think there is any model that needs this
	# also not sure how JSON and Perl play into this
	# my $val = "123.323231233323";
	# my $f32 = unpack("f<", pack("f<", $val));
	# my $f64 = unpack("d<", pack("d<", $val));
	# warn "val: ", $val, "\n";
	# warn "f32: ", abs($val - $f32), "\n";
	# warn "f64: ", abs($val - $f64), "\n";
	foreach (@{$arr}) {
		# create copy
		my $val = $_;
		# check if we have referece
		# this case can't be optimized
		if (ref($_) || !looks_like_number($val)) {
			# not a valid number array
			$isInt8 = $isUint8 =
			$isInt16 = $isUint16 =
			$isInt32 = $isUint32 =
			$isFloat32 = $isFloat64 =
			0;
			# abort loop
			last;
		}

		# would proabably have been easier to just
		# store min and max and flag of all are ints

		if (isint($val)) {

			# check for positive integers
			$isInt8 = 0 if ($val >= 2**7); # 127
			$isUint8 = 0 if ($val >= 2**8); # 255
			$isInt16 = 0 if ($val >= 2**15);
			$isUint16 = 0 if ($val >= 2**16);
			$isInt32 = 0 if ($val >= 2**31);
			# check the negative types
			$isUint8 = 0 if ($val < 0);
			$isUint16 = 0 if ($val < 0);
			$isUint32 = 0 if ($val < 0);
			# check negative integer size
			$isInt8 = 0 if ($val < - 2**7);
			$isInt16 = 0 if ($val < - 2**15);
			$isInt32 = 0 if ($val < - 2**31);

			# $isUint32 = 0 if ($val > 2**32);
			warn "Integer too big" if ($val >= 2**32);
			warn "Integer too small" if ($val < - 2**31);

		}
		else {
			$isInt8 = $isUint8 = 0;
			$isInt16 = $isUint16 = 0;
			$isInt32 = $isUint32 = 0;
		}

	}
	# EO each val

	#warn "isInt8: ", $isInt8, "\n";
	#warn "isUint8: ", $isUint8, "\n";
	#warn "isInt16: ", $isInt16, "\n";
	#warn "isUint16: ", $isUint16, "\n";
	#warn "isInt32: ", $isInt32, "\n";
	#warn "isUint32: ", $isUint32, "\n";
	#warn "isFloat32: ", $isFloat32, "\n";
	#warn "isFloat64: ", $isFloat64, "\n";

	# check for "typed" array
	if (
		$isInt8 || $isUint8 ||
		$isInt16 || $isUint16 ||
		$isInt32 || $isUint32 ||
		$isFloat32 || $isFloat64
	) {
		# store reference to input variable
		# effectively pointing to the data
		# quite an effective trick, right?
		my $path = join ".", @paths;
		if ($isUint8) { push(@uint8, [\$_[0], $path]); }
		elsif ($isInt8) { push(@int8, [\$_[0], $path]); }
		elsif ($isUint16) { push(@uint16, [\$_[0], $path]); }
		elsif ($isInt16) { push(@int16, [\$_[0], $path]); }
		elsif ($isUint32) { push(@uint32, [\$_[0], $path]); }
		elsif ($isInt32) { push(@int32, [\$_[0], $path]); }
		elsif ($isFloat32) { push(@float32, [\$_[0], $path]); }
		elsif ($isFloat64) { push(@float64, [\$_[0], $path]); }
		else { die "invalid internal state"; }
	}
	# cannot convert
	# go deeper and return
	else {
		# just process all values in the array
		for (my $i = 0; $i < scalar(@{$arr}); $i++) {
			push @paths, $i;
			processScalar($arr->[$i]);
			pop @paths;
		}
	}
	# return ourself
	return $arr;
}

sub processScalar
{
	if (ref $_[0] eq "HASH") { processHash($_[0]); }
	elsif (ref $_[0] eq "ARRAY") { processArray($_[0]); }
}

sub processJsonMaps
{

	# input arguments
	my ($json) = @_;
	# remove mapped object keys
	# they will be re-created
	# must not do for arrays!
	foreach my $key (keys %maps) {
		my $base = $json;
		my @parts = split /\./, $key;
		while (scalar(@parts) > 1) {
			my $part = shift(@parts);
			if (ref $base eq "HASH") {
				$base = $base->{$part};
			}
			elsif (ref $base eq "ARRAY") {
				$base = $base->[$part];
			}
		}
		if (ref $base eq "HASH") {
			delete $base->{$parts[0]};
		}
	}

	# wrap the result
	return {
		"maps" => \%maps,
		"json" => $json
	};
}

#######################################################################################################
#######################################################################################################

# header type
# maximum sizes
my $type = 1;

sub encode_buffers ()
{
	# static format prefix
	my $buffer = "jbdb";
	# static version nr
	$buffer .= "\0\0\0\0";
	# expected file size
	# overwritten at the end
	$buffer .= "\0\0\0\0";

	# first write array counts
	# this is a fixed amount of items
	# we know that there are eight types
	# so the first header size is always known
	# prefix (12) + counts (8*4 = 32) = 44 bytes
	# or in term of JS, always a Uint32Array(10)
	foreach (@header) {
		# get from iterator object
		my ($name, $arr, $packer, $bytes) = @{$_};
		$buffer .= pack("L<", scalar(@{$arr})); # count
	}

	# do in client
	my $offset = 0;

	# first write header
	foreach (@header) {
		# get from iterator object
		my ($name, $arr, $packer, $bytes) = @{$_};
		foreach my $values (@{$arr}) {
			my $length = scalar(@{${$values->[0]}});
			$buffer .= pack("L<", $offset); # offset
			$buffer .= pack("L<", $length); # length
			$offset += $length * $bytes;
		}
	}

	my $count = 0;
	# then write buffer
	foreach (@header) {
		# get from iterator object
		my ($name, $arr, $packer, $bytes) = @{$_};
		next if scalar(@{$arr}) == 0;
		my $arrs = 0, my $vals = 0;
		foreach my $values (@{$arr}) {
			$vals += scalar(@{${$values->[0]}});
			foreach my $value (@{${$values->[0]}}) {
				$buffer .= pack($packer, $value);
			}
			${$values->[0]} = undef;
			$maps{$values->[1]} = $count ++;
		++ $arrs }
		print "Exported $arrs $name arrays ($vals values)\n";
	}

	# at last update the expected file size
	substr($buffer, 8, 4, pack("L<", length($buffer)));

	# return buffer string
	return $buffer;
}

#######################################################################################################
#######################################################################################################

sub compressFile ($$)
{
	# simlpy call out to lzma
	# ToDo: Error and file exist test
	system "lzma", "-mt4", "e", $_[0], $_[1];
}

#######################################################################################################
#######################################################################################################

print "#" x 60, "\n";
print "Loading ${input}.json\n";

# simple data reading
my $jsdata = read_file("${input}.json", $slurpopt);
die "error loading json name db\n" unless $jsdata;
# $jsdata =~ s/\b0x([0-9A-Fa-f]{6,6})\b/hex($1)/eg;
# $jsdata =~ s/\bshiny\b/hex('FFFFFF')/eg;
my $json = JSON->new->decode($jsdata);
# my $jsondata = encode_json($json); # commit cleanups
# write_file( "${input}.json", $slurpopt, $jsondata);

print "#" x 60, "\n";

# process the json first
$json = processScalar($json);
# write optimized buffers
my $buffer = encode_buffers();
# alters the loaded json
$json = processJsonMaps($json);
# render the final json
my $jsondata = encode_json($json);

print "#" x 60, "\n";
print "Writing ${output}.jdb and ${output}.jbdb\n";

write_file( "${output}.jdb", $slurpopt, $jsondata);
write_file( "${output}.jbdb", $slurpopt, $buffer);

print "#" x 60, "\n";

compressFile "${output}.jdb", "${output}.jdb.lzma" if $compress > 1;
compressFile "${output}.jbdb", "${output}.jbdb.lzma" if $compress > 0;

print "#" x 60, "\n" if $compress;

#######################################################################################################
#######################################################################################################
1;
