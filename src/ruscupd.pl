#!/usr/bin/perl
#
#  Subject:	RuScenery updater for X-plane
#  Author:	(C)2011 Vladimir V. Panfilov v.v.panfilov@gmail.com
#  Planform:	Development on Ubuntu Linux 10.04
#  		should work on others too
#  Revision:	$Id$
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>. 

use Getopt::Long;
use LWP::UserAgent;
use POSIX;

local $|=1; #autoflush stdout 

my $myrev;
($myrev='$Rev$')=~s/.*:\s(\d+).*/$1/;

my $progname = "ruscupd";
my $hi = "ruscupd.pl - RuScenery updater. Revision $myrev";
print "$hi\n",'-'x length($hi),"\n";

# Globals
my $conf;
my @conf;
my $xpdir;
my $ruscdir;

my @argv = @ARGV;
my $res = GetOptions(
    "update|u" => \$update,
    "conf|c=s" => \$conf,
    "reset|r" => \$reset_config,
    "help|h"   => \$help,
    "verbose|v" => \$verbose
);

if ($help) {
  print "Usage: $0 [OPTIONS] 

Options:
   -c, --conf=FILE      Use FILE as your current session config file.
   -r, --reset          Reset $progname configuration file (creates a new one)
   -v, --verbose        Be verbose (more output text messages)
   -h, --help           Help - just this screen.

This program is available under the GNU General Public License. 
See yours at http://www.gnu.org/licenses/
";
  exit;
}

# our local config file
unless( $conf ){
 $defconf = "Using existing ";
  -f "/usr/local/etc/ruscupd.conf" and $conf = "/usr/local/etc/ruscupd.conf";
  -f "/etc/ruscupd.conf" and $conf = "/etc/ruscupd.conf";
  -f "$ENV{HOME}/ruscupd.conf" and $conf = "$ENV{HOME}/ruscupd.conf";
  -f "./ruscupd.conf" and $conf = "./ruscupd.conf";
  unless ( $conf ){
    ($conf = $0)  =~ s/(.*)\/.*/$1\/ruscupd.conf/ if $conf =~ /^(\.\/)?$/; # locate our config
    $defconf = "Config file missing. Creating ";
  } 
}else {
  $defconf = -f $conf? "Using" : "Will create";
  $defconf .= " specified ";
}
print "${defconf} $conf as config file\n";

unless( $reset_config ) {
  if ( load_config($conf, \@conf) ){
      print "Config file successfully loaded\n";
      parse_config(\@conf);
  } else {
    # 1-st start. May be...
    print "Fail to load config $conf\n";
    die if -f $conf;
    print "Creating new one.\n";
    $reset_config = 1; # create new config
  }
}

# Locate X plane directory
locate_xplane() unless $xpdir;

# locate dir for ruscenery and create it if does not exist
$ruscdir = $xpdir . "/Custom Scenery/ruscenery/";
unless (-d $ruscdir) { 
   print "Creating directory $ruscdir\n"; 
   mkdirhier("$ruscdir"); 
}

print "X-Plane directory: $xpdir\n";
print "RuScenery directory: $ruscdir\n\n";

my $ua = LWP::UserAgent->new;
$ua->agent("RuScUpd/$ruscrev Linux");
$ua->env_proxy;

# Load and parse commands from 'current version file'
# download http://www.x-plane.su/ruscenery/ruscenery.ver
my $updurl = "http://www.x-plane.su/ruscenery/";
my $verfile = "ruscenery.ver";

$f = download_file( $updurl, $verfile );

@lines = split /\r\n/, $f;
print "Verfile is ",scalar @lines," lines\n" if $verbose;
@commands = grep /^;/,@lines;

foreach $cmd (@commands){
   print $cmd,"\n" if $verbose;
   $updurl = $1 if $cmd =~ /^;u (.*)/i ;
   $dwnurl = $1 if $cmd =~ /^;d (.*)/i ;
   $vfver  = $1 if $cmd =~ /^;v (.*)/i ;
   $topmsg = $1 if $cmd =~ /^;t (.*)/i ;
   $botmsg = $1 if $cmd =~ /^;b (.*)/i ;
   $stsmsg = $1 if $cmd =~ /^;s (.*)/i ;
}
$updurl = "http://www.x-plane.su/ruscenery/" if $updurl =~ /^\s*$/;
$dwnurl = "http://www.x-plane.su/ruscenery/update/" if $dwnurl =~ /^\s*$/;

if ($reset_config){
   create_config(\@conf);
} else {
   update_config(\@conf)
}
# Store settings in config file
save_config($conf,\@conf);

print "Updating...\n";
print "$topmsg\n" if $topmsg;
$n=0;
foreach (@lines)
{
   next if /^[;#]/;
   next if /^$/;
   next unless /^(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s*$/;
   $rsize = $2;
   $rdate = $3;
   $rtime = $4;
   ($rfile = $1) =~ s/\\/\//g;
   $rdate =~ /(\d+)\.(\d+)\.(\d+)/; ($d,$m,$y)=($1,$2-1,$3-1900);
   $rtime =~ /(\d+)\:(\d+)\:(\d+)/; ($H,$M,$S)=($1,$2,$3);
   $rtime = POSIX::mktime($S, $M, $H, $d, $m, $y);
   if ( -f "$ruscdir$rfile" ) {
      @stat = stat _;
      ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
      $atime,$mtime,$ctime,$blksize,$blocks) = @stat;
      if ($size != $rsize) {
	 download_file ($dwnurl,$rfile);
         $n++; 
      }
   } else {
	 download_file ($dwnurl,$rfile);
         $n++; 
   };
   utime $rtime, $rtime, "$ruscdir$rfile";
#   last if $n>10; # just 10 files for now
}
print "$botmsg\n" if $botmsg;


sub locate_xplane
{
    my @dirs = search_xpdir('/opt','/usr/local/');
    my ($n,$a)=(0,0);
    
    # Let user deside
    print "X-plane directories:\n*";
    print "\t",$n++," $_\n" foreach @dirs;
    print "\t",$n," Other\n\n* - default\n\n";
    
    do {
     if ($n>0) {
       print "Choose your X-plane directory: ";
       $a = <>;
     }
     chomp $a;
     if ($a==0 or $a<scalar @dirs){
       $xpdir = $dirs[$a];
     }
     if ($xpdir eq '') {
       print "Specify directory where X-plane is installed: ";
       $xpdir = <>;
       chomp $xpdir;
     }
    } unless ($xpdir);
}

sub load_config
{
   my $conf = shift;
   my $cptr = shift;
   my $cf;
   open $cf, "<$conf" or return undef;
   @$cptr = <$cf>;
   close $cf;
   return $cptr;
}

sub save_config
{
   my $conf = shift;
   my $cptr = shift;
   my $cf;
   open $cf, ">$conf" or die "Cannot write config file $conf.\n $! \n $^E\n";
   foreach (@$cptr) {
     print $cf "$_\n";
   }
   close $cf;
   return 1;
}

sub create_config
{
   my $cptr = shift;
   @$cptr = ("# RuScenery updater configuration file",
   "# " . $localtime ,
   "#",
   "XplaneDir = $xpdir",
   "UpdateURL = $updurl");
}

sub parse_config
{
   print "Parsing config...";
   my $cptr = shift;
   foreach (@$cptr) {
       chomp;
       /^#/ && next;
       /^\s*$/ && next;
       /^XplaneDir\s*=\s*(\S+)\s*/ && do {  $xpdir = $1;  next;  };
       /^UpdateURL\s*=\s*(\S+)\s*/ && do {  $updurl = $1; next; };
       print "file format invalid\n" ;
       print "To reset config file run $0 -r ".join(" ",@argv)."\n" ;
#       print "WARNING!!! All current data in $conf whill be deleted\n" ;
       die '';
     }
   print "done\n";
}

sub update_config
{
   my $cptr = shift;
   foreach (@$cptr) {
       /^#/ && next;
       /^\s*$/ && next;
       /^XplaneDir\s*=\s*(\S+)\s*/ && do {  s/=.*$/= $xpdir/; $xpdir_f =1; next;  };
       /^UpdateURL\s*=\s*(\S+)\s*/ && do {  s/=.*$/= $updurl/; $updurl_f=1; next; };
       print "file format invalid\n" ;
       print "To reset config file run $0 -r ".join(" ",@argv)."\n" ;
#       print "WARNING!!! All current data in $conf whill be deleted\n" ;
       die '';
     }
   push @$cptr, "XplaneDir = $xpdir" unless $xpdir_f;
   push @$cptr, "UpdateURL = $updurl" unless $updurl_f;
   print "done\n";
}

sub mkdirhier
{
    $dir = shift;
    @dir = split /\//, $dir;
    $dd = '';
    foreach $d ( @dir ) {
        $dd .= "$d/";
	unless (-d $dd){
		print "Create '$dd'\n" if $verbose;
		mkdir "$dd";
	} 
    };
}

sub search_xpdir
{
   my (@dir, %d);
   unshift @_,'./';
   unshift @_,"$ENV{HOME}" if $ENV{HOME};
   print "Searching for X-plane in ",join(':',@_),"\n";
   while( my $rootdir = shift)
   {
     opendir $dh, $rootdir if $rootdir !~ /^$/;
     @dir = readdir $dh;
     closedir $dh;
     foreach (@dir) { 
        if (/x[- ]?plane?/i) {
	   $_=-d "$rootdir/$_"?"$rootdir/$_":$rootdir;
	   s/\/\//\//g;
	   $d{$_}=undef;
	}
     };
   }
   foreach $k (keys %d){
	delete $d{$k} unless -d "$k/Custom Scenery/";
   } 
   return sort keys %d;
}

sub download_file
{
    my ($url,$file)=@_;
    print "Downloading ${url}${file}...";
    $resp = $ua->get($url.$file);
    die $resp->status_line, "\n" unless $resp->is_success;
    print "done\n";

    # save file
    ($localdir = "$ruscdir/$file") =~ s/(.*\/)(.*)/$1/;
    mkdirhier($localdir);
    open FO,">","$ruscdir/$file";
    print FO $resp->content;
    close FO;
    return $resp->content;
}

__DATA__
$Rev$

