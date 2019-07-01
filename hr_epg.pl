#!/usr/bin/perl
use strict;
use warnings;
use JSON;
use Time::Local;
my %map = (
    '&' => 'and',
);
my $chars = join '', keys %map;

my $tz; # = "+1000";
my @lt = localtime(12*60*60);
my @gt = gmtime(12*60*60);
$tz = $lt[2] - $gt[2];
$tz = sprintf("%+03d00", $tz); 

my $curl = "/usr/bin/curl";
my $data = `$curl -s -L http://ipv4-api.hdhomerun.com/discover`;
my $discover = decode_json($data);
my $guide;
my $deviceip = @$discover[0]->{LocalIP};

$data = `$curl -s -L http://$deviceip/discover.json`;
my $localdiscover = decode_json($data);

my $DeviceAuth = $localdiscover->{DeviceAuth};
my $linupurl = $localdiscover->{LineupURL};

$data = `$curl -s -L $linupurl`;
my $channeldata = decode_json($data);

print "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>\n<!DOCTYPE tv SYSTEM \"xmltv.dtd\">\n";
print "<tv generator-info-url=\"http://www.xmltv.org/\">\n";

$data = `$curl -s "http://ipv4-api.hdhomerun.com/api/guide.php?DeviceAuth=$DeviceAuth"`;
my $guidedata = decode_json($data);

foreach my $items (@$guidedata) {
  $data = "";
  my $channelnumber;
  my $channelname;
  my $channel = $items->{GuideNumber};
  foreach my $lineup (@$channeldata) {
      if ($lineup->{GuideNumber} eq $items->{GuideNumber}) {
          $channelname = $lineup->{GuideName};
      }
  };
  print "\t<channel id=\"".$channel.".".$items->{GuideName}."\">\n";
  printf "\t\t<display-name>".$channelname."</display-name>\n";
  printf "\t\t<icon src=\"".$items->{ImageURL}."\" />\n" if (defined($items->{ImageURL}));
  print "\t</channel>\n";
 
}

foreach my $items (@$channeldata) {
  $data = "";
  my $channel = $items->{GuideNumber};
  my $channelid = $items->{GuideName};
  my $starttime = time(); 
  while ($data ne "null") {    
    $data = `$curl -s "http://ipv4-api.hdhomerun.com/api/guide.php?DeviceAuth=$DeviceAuth&Channel=$channel&Start=$starttime"`; 
    last if ($data eq "null") ;
    $guide->{$channel} = decode_json($data);  
    printprogrammexml($channel.".".$guide->{$channel}[0]->{GuideName},$guide->{$channel}[0]->{Guide});
    my $size = scalar @{ $guide->{$channel}[0]->{Guide}} - 1;
    $starttime = $guide->{$channel}[0]->{Guide}[$size]->{EndTime};    
  }
}

print "</tv>\n";

sub printprogrammexml {
    my ($channelid,$data) = @_;
    foreach my $items (@$data) {
        my $starttime = $items->{StartTime};
        my $endtime = $items->{EndTime};
        my $title = $items->{Title};
        my $movie = 0;
        my $originalairdate = "";
        my ($ssec,$smin,$shour,$smday,$smon,$syear,$swday,$syday,$sisdst) = localtime($starttime);
        my ($esec,$emin,$ehour,$emday,$emon,$eyear,$ewday,$eyday,$eisdst) = localtime($endtime);
        my $startdate=sprintf("%0.4d%0.2d%0.2d%0.2d%0.2d%0.2d",($syear+1900),$smon+1,$smday,$shour,$smin,$ssec);
        my $senddate=sprintf("%0.4d%0.2d%0.2d%0.2d%0.2d%0.2d",($eyear+1900),$emon+1,$emday,$ehour,$emin,$esec);
        $title =~ s/([$chars])/$map{$1}/g;        
        print "\t<programme start=\"$startdate $tz\" stop=\"$senddate $tz\" channel=\"$channelid\">\n";
        print "\t\t<title>".$title."</title>\n";
        if (defined($items->{EpisodeTitle})) {
           my $subtitle = $items->{EpisodeTitle};
           $subtitle =~ s/([$chars])/$map{$1}/g;
           print "\t\t<sub-title>".$subtitle."</sub-title>\n";
        }
        if (defined($items->{Synopsis})) {
          my $description = $items->{Synopsis};
          $description =~ s/([$chars])/$map{$1}/g;
          print "\t\t<desc>".$description."</desc>\n" ;
        }
        if (defined($items->{Filter})) {
           foreach my $category (@{$items->{Filter}}) {
               if ($category =~ /Movie/) {
                   $movie = 1;
               }
               print "\t\t<category lang=\"en\">$category</category>\n";
           }
        }
        print "\t\t<icon src=\"$items->{ImageURL}\" />\n" if (defined($items->{ImageURL}));                
        if (defined($items->{EpisodeNumber})) {
           my $series = 0;
           my $episode = 0;
           if ($items->{EpisodeNumber} =~ /^S/) {
              print "\t\t<episode-num system=\"SxxExx\">$items->{EpisodeNumber}</episode-num>\n" if (defined($items->{EpisodeNumber}));
              ($series, $episode) = $items->{EpisodeNumber} =~ /S(.+)E(.+)/;
              $series--;
              $episode--;
           }
           elsif ($items->{EpisodeNumber} =~ /^EP.*-.*/) {
              ($series, $episode) = $items->{EpisodeNumber} =~ /EP(.+)-(.+)/;
              $series--;
              $episode--;
           }
           elsif ($items->{EpisodeNumber} =~ /^EP.*/) {
              ($episode) = $items->{EpisodeNumber} =~ /EP(.+)/;
              $episode--;              
           }
           $series = 0 if ($series < 0);
           $episode = 0 if ($episode < 0);
           print "\t\t<episode-num system=\"xmltv_ns\">$series.$episode.</episode-num>\n" if (defined($items->{EpisodeNumber}));
            
        }
#        if ((defined($items->{SeriesID})) and (!defined($items->{OriginalAirdate})) and !($movie)) {
         if ((!defined($items->{EpisodeNumber})) and (!defined($items->{OriginalAirdate})) and !($movie)) {
            my $startdate=sprintf("%0.4d-%0.2d-%0.2d %0.2d:%0.2d:%0.2d",($syear+1900),$smon+1,$smday,$shour,$smin,$ssec);
            my $tmpseries = sprintf("S%0.4dE%0.2d%0.2d%0.2d%0.2d%0.2d",($syear+1900),($smon+1),$smday,$shour,$smin,$ssec);                    
            print "\t\t<episode-num system=\"original-air-date\">$startdate</episode-num>\n";
            print "\t\t<episode-num system=\"SxxExx\">$tmpseries</episode-num>\n";
        }
        if (defined($items->{OriginalAirdate})) {
           my ($oadsec,$oadmin,$oadhour,$oadmday,$oadmon,$oadyear,$oadwday,$oadyday,$oadisdst) = localtime($items->{OriginalAirdate});
           $originalairdate = sprintf("%0.4d-%0.2d-%0.2d %0.2d:%0.2d:%0.2d",($oadyear+1900),$oadmon+1,$oadmday,$oadhour,$oadmin,$oadsec);                    
           print "\t\t<episode-num system=\"original-air-date\">$originalairdate</episode-num>\n";           
        }
        
        if ($originalairdate ne "") {
            print "\t\t<previously-shown start=\"$originalairdate\" />\n";
        }
        else { print "\t\t<previously-shown />\n";}
        print "\t</programme>\n";
    }
}
