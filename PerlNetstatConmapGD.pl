#!/usr/bin/perl
use strict;
use warnings;
use GD;
use List::MoreUtils qw(uniq);
my $netstat_file;
if(!$ARGV[0]){
	print "Usage: netstat_connections_map.pl <netstat_output_file|netstat>\n";
	exit 1;
}else{
	if($ARGV[0] eq "netstat"){
		#create file on the fly
		print "Using netstat binary for this host..\n";
		`sudo netstat -plane|grep ESTAB|grep -v "::" > netstat`;
		$netstat_file="netstat";
	}else{
		print "Using file '$netstat_file' text file as input..\n";
		$netstat_file=$ARGV[0];
	}
}

# Create a new image
my $im = new GD::Image(1500,900);
my($white,$black,$red,$blue,$green);

# Allocate some colors
&InitColors($im);
$im->interlaced('true');

#draw title
my $td=`date`;chomp $td;
$im->string(gdSmallFont, 10, 5, "Netstat file: $netstat_file - $td", $black);
$im->string(gdSmallFont, 10, 20, "--- http", $blue);
$im->string(gdSmallFont, 10, 35, "--- https", $green);
$im->string(gdSmallFont, 10, 50, "--- non-http", $red);

# create connections hash datastructure
my %connections;
my %ports;
my %procs;

#get output from netstat ESTAB connections 
open my $fileh, $netstat_file or die "Could not open file: $!";
while(<$fileh>)  {
    #add to connections hash:: connections{nodekey,}
    my @values=split(" ",$_);
    my @ip_port_src=split(":",$values[3]);
    my @ip_port_dst=split(":",$values[4]);
    push @{$connections{$ip_port_src[0]}},$ip_port_dst[0] if($ip_port_src[0] ne $ip_port_dst[0]);
    push @{$ports{$ip_port_dst[0]}},$ip_port_dst[1] if($ip_port_src[0] ne $ip_port_dst[0]);
    push @{$procs{$ip_port_dst[0]}},$values[8] if($ip_port_src[0] ne $ip_port_dst[0]);
}

#first create uniq list of nodes
my @uniq;
foreach my $elem(keys %connections){
	push @uniq, $elem;
	foreach(sort @{$connections{$elem}}){
		push @uniq, $_;
	}
}
my @uniqIPs= uniq @uniq;

my %nodesPos;
my $x1 = 60;
my $y1 = 60;
my $incrValX=180;
my $incrValY=100;
my $colcnt=0;
foreach my $key(sort @uniqIPs){
	my $shift=10;
	#add positions to nodes pos ref
	if($colcnt % 2){
		$x1=$x1 - 60;
		$y1=$y1 - 10;
		
	}else{
		$x1=$x1 + 60;
		$y1=$y1 + 10;
	}
	push @{$nodesPos{$key}},$x1; # position X
	push @{$nodesPos{$key}},$y1; # position Y
	if($colcnt > 6){
		$colcnt=0;
		$x1+=$incrValX;
		$y1=60;
	}else{
		$y1+=$incrValY;
	}
	$colcnt++;
}

print "\nDraw all nodes at coords\n";
foreach my $key(sort keys %nodesPos){
	print "key: $key :: x: ${$nodesPos{$key}}[0], y: ${$nodesPos{$key}}[0]";
	&drawNode(${$nodesPos{$key}}[0],${$nodesPos{$key}}[1],$key,'node');
	print "\n";
}

#parse all connections and draw lines between nodes
print "\nDraw all connections using %connections\n";
my $color;
foreach my $key(sort keys %connections){
	my $srcX=${$nodesPos{$key}}[0];
	my $srcY=${$nodesPos{$key}}[1];
	print "src '$key' x: $srcX, y: $srcY\n";
        foreach(@{$connections{$key}}){
                my $dstX=${$nodesPos{$_}}[0];
                my $dstY=${$nodesPos{$_}}[1];
		print " -> dst '$_' x: $dstX, y: $dstY - connection is on port: ${$ports{$_}}[0]: ${$procs{$_}}[0] \n";

		#set color depending on port
		if(${$ports{$_}}[0] == 80){
			$color=$blue;
		}elsif(${$ports{$_}}[0] == 443){
			$color=$green;

		}else{
			$color=$red;
		}
		&drawConnection($srcX, $srcY, $dstX, $dstY, $color);
		my $newX=($srcX + $dstX) / 2;
		my $newY=($srcY + $dstY) / 2;
		&drawNode($newX,$newY + 20,${$procs{$_}}[0].":".${$ports{$_}}[0],'label');
        }
}

&writeImage;

sub drawNode{
	my $x1=shift;
	my $y1=shift;
	my $label1=shift;
	my $type=shift;

	# Draw the text (nodes)
	$im->string(gdMediumBoldFont, $x1, $y1, $label1, $black)if($type eq "node");
	$im->string(gdTinyFont, $x1, $y1, $label1, $black)if($type eq "label");
}

sub drawConnection{
	my $x1=shift;
        my $y1=shift;
	my $x2=shift;
        my $y2=shift;
	my $color=shift;
	# A line between the two drawn nodes
	$im->line($x1 + 40,$y1 + 8,$x2 + 40,$y2,$color);
}

sub writeImage{
	# Open a file for writing 
	open(PICTURE, ">picture.png") or die("Cannot open file for writing");
	binmode PICTURE;
	print PICTURE $im->png;
	close PICTURE;
	
	#write sequences
	#open(PICTURE, ">seqs/".time.".png") or die("Cannot open file for writing");
	#binmode PICTURE;
	#print PICTURE $im->png;
	#close PICTURE;
	
}

sub InitColors {
    my($im) = $_[0];
    # Allocate colors
    $white = $im->colorAllocate(255,255,255);
    $black = $im->colorAllocate(0,0,0);
    $red = $im->colorAllocate(255,0,0);
    $blue = $im->colorAllocate(0,0,255);
    $green = $im->colorAllocate(0, 255, 0);
    #$brown = $im->colorAllocate(255, 0x99, 0);
    #$violet = $im->colorAllocate(255, 0, 255);
    #$yellow = $im->colorAllocate(255, 255, 0);
}

sub r_int {
    my($min, $max) = @_;
    return $min if $min == $max;
    ($min, $max) = ($max, $min)  if  $min > $max;
    return $min + int rand(1 + $max - $min);
}
