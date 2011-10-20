#!/usr/bin/perl
#
#  Subject:	RuScenery updater for X-plane
#  Author:	(C)2011 V.Panfilov v.v.panfilov@gmail.com
#  Planform:	Development on Ubuntu Linux 10.04
#  		should work on others too
#  Revision:	$Rev $
#

use Getopt::Long;
#use IO::Socket;
use LWP::UserAgent;

my $res = GetOptions(
    "update|u" => \$update,
    "conf|c=s" => \$conf,
    "help|h"   => \$help
);

my $conf;
my $xpdir;
my $ruscdir;

# set variables
# our local config file
($conf = $0)  =~ s/(.*)\/.*/$1\/ruscupd.conf/ if $conf =~ /^(\.\/)?$/; # locate our config

# 1-st start.
# Locate X plane directory
# Let user deside
# Store directory to config file
# locate dir for ruscenery and create it if does not exist
#
@dirs = search_xpdir('/opt','/usr/local/');
print scalar @dirs," directories found\n";

$n=0;
$a=0;

print "ruscupd.pl - RuScenery updater\n\n";
print "X-plane directories:\n";
print "\t",$n++," $_\n" foreach @dirs;
print "\t",$n," Other\n\n";

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
   print "Enter directory where X-plane is installed: ";
   $xpdir = <>;
   chomp $xpdir;
 }
}unless ($xpdir);

print "Using X-plane directory '$xpdir'\n";

$ruscdir = $xpdir . "/Custom Scenery/ruscenery/";

unless (-d $ruscdir) { print "Creating directory $ruscdir\n"; mkdirhier("$ruscdir"); }

print "Config file: $conf\n";
print "X-Plane directory: $xpdir\n";
print "RuScenery directory: $ruscdir\n\n";

my $ua = LWP::UserAgent->new;
$ua->agent("RuScUpd/0.0.0 ");
$ua->env_proxy;

# Load and parse commands from 'current version file'
# download http://www.x-plane.su/ruscenery/ruscenery.ver
my $url = "http://www.x-plane.su/ruscenery/";
my $verfile = "ruscenery.ver";

$f = download_file( $url, $verfile);

@lines = split /\r\n/, $f;
print "Verfile is ",scalar @lines," lines\n";
@commands = grep /^;/,@lines;

foreach $cmd (@commands){
   print $cmd,"\n";
   $cmd =~ /^;u/ &&  print "UUUU\n"; 
}

#download_file ("http://www.x-plane.su/ruscenery/update/","polygons/lightspot1.png");

# parse commands
#
# ;u command
# ;d command
# ;v command
# ;t command
# ;s command
# ;b command
#


# File list analisis
# read file from list
# check for file in local directory
# download if it does not exist
# file exists: check for size, if does not mutch - download it
# set date time for file from downloaded list
#

#
# ruscenery.ver
#
# string delimiter: 0x0d0x0a
# # - comment
# ;x - command x
# Url  - 
# ;u http://www.x-plane.su/ruscenery/
# default http://www.x-plane.su/ruscenery/
#
# Download url
# ;d http://www.x-plane.su/ruscenery/update/
# default http://www.x-plane.su/ruscenery/update/
#
# Version
# ;v 1.0.1
#
# Status string
# ;s (;S)
# Message string in cp1251 encoding
#
# Top message
# ;t (;T)
# Top message string in cp1251
#
# Bottom message
# ;b (;B)
# Bottom message string in cp1251
#
#
# Sample control file:
# #
# # Файл описания версии библиотеки RuScenery
# # Версия библиотеки 1.0.8
# # сборка от 03.07.2009 19:55:03
# #
# ;u http://www.x-plane.su/ruscenery/
# ;d http://www.x-plane.su/ruscenery/update/
# ;v 1.0.1
# ;s Бета версия - работает в тестовом режиме
# #
# copyrights.txt 9936 03.07.2009 01:00:08
# dirinfo.txt 4383 03.07.2009 01:00:08
# install.txt 187 03.07.2009 01:00:08
# library.txt 37558 03.07.2009 01:00:08
# aircrafts\a-50.obj 485812 03.07.2009 01:00:08
# aircrafts\a-50.png 1422830 03.07.2009 01:00:08
# aircrafts\a-50_lit.png 286949 03.07.2009 01:00:08
# aircrafts\an-10.obj 241334 03.07.2009 01:00:08
# aircrafts\an-10.png 1028434 03.07.2009 01:00:08
# aircrafts\an-10_lit.png 451958 03.07.2009 01:00:08
#
# ...
#
# tech\uaz.obj 77988 03.07.2009 01:00:08
# tech\ural-mil.obj 119712 03.07.2009 01:00:08
# tech\zil-mil.obj 83812 03.07.2009 01:00:08
# 

sub mkdirhier
{
    $dir = shift;
print "mkdirhier: $dir\n";
    @dir = split /\//, $dir;
print scalar @dir,"\n";
    $dd = '';
    foreach $d ( @dir ) {
        $dd .= "$d/";
	unless (-d $dd){
		print "Create '$dd'\n";
		mkdir "$dd";
	} 
    };
}

sub search_xpdir
{
   my (@dir, %d);
   unshift @_,"./";
   unshift @_,"$ENV{HOME}" if $ENV{HOME};
   print "Searching in ",join(':',@_),"\n";
   while( my $rootdir = shift)
   {
     $rootdir .= '/' unless $rootdir=~/\/$/;
     opendir $dh, $rootdir;
     @dir = readdir $dh;
     closedir $dh;
     map { $d{"${rootdir}$_"}=undef if $_ =~ /x[- ]?plane/i} @dir;
   }
#   foreach $k (keys %d){
#	delete $d{$k} unless -d "$k/Custom Scenery/";
#   }
   return sort keys %d;
}

sub download_file
{
    my ($url,$file)=@_;
    print "Downloading ${url}${file}...";
    $resp = $ua->get($url.$file);
    die $resp->status_line, "\n"
      unless $resp->is_success;

    print "done\n";
    # save file
    ($localdir = "$ruscdir/$file") =~ s/(.*\/)(.*)/$1/;
    mkdirhier($localdir);
    open FO,">","$ruscdir/$file";
    print FO $resp->content;
    close FO;
    return $resp->content;
}
