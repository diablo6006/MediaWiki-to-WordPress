#!/usr/bin/perl

# Modified by George Smart, M1GEO
# Originally from: http://www.analogrithems.com/rant/portfolio/mediawiki2wordpress/
# Fri 20 Jan 2017

use strict;
use warnings;

use XML::Smart;
use XML::RSS;
use Date::Parse;
use POSIX qw/strftime/;

use vars qw/ %opt /;

my $version = "$0 v0.2";
my $post_type = 'page';
my $ping_status = 'closed';
my $parent = 0;
my $comment_status = 'closed';
my $redirect = 0;
my $page_status = 'draft'; # mark as draft and I publish when checked.
my $url = 'http://new.george-smart.co.uk';
my $imgurl = $url . '/wordpress/wp-content/uploads';
my $medurl = $url . '/wordpress/wp-content/uploads/bin';


#
# Command line options processing
#
sub init(){
	use Getopt::Std;
	my $opt_string = 'hvVrf:o:u:';
	getopts( "$opt_string", \%opt ) or usage();
	if($opt{V}){
		print $version."\n";
		exit;
	}
	if($opt{u}){
		$url = $opt{u};
	}
	if($opt{r}){
		$redirect = 1;
	}
	usage() if $opt{h};
	usage() if !$opt{f};
	main();
}

sub usage(){
	print STDERR <<"EOF";
$0 -f <mediaWikiFile.xml> [-o <outputfile>] [-v] [-h] [-V]

-f 	The XML file that was exported from media wiki
-o	Output file to store the wordpress XML in.  If not defined, goes straight to STDOUT
-r  Write Apache 'RewriteRule' lines to STDERR for redirecting old pages to new URLs
-h 	This help message
-u	Base URL
-v	Verbose
-V	Version
EOF
exit;
}

sub pageSlug(){
	my $name = lc(shift());
	$name =~ s/[^\w]/_/g;
	$name =~ s/ /_/g;
	return $name;
}

sub ctime(){
	my $tm = str2time(shift());
	return strftime('%Y-%m-%d %T',localtime($tm));
}
sub main(){

	print $opt{f}."\n";
	my $XML = XML::Smart->new($opt{f},'XML::Smart::Parser');
	my $rss = XML::RSS->new(version=>'2.0');
	$rss->add_module(prefix=>'content', uri=>'http://purl.org/rss/1.0/modules/content/');
	$rss->add_module(prefix=>'wfw', uri=>'http://wellformedweb.org/CommentAPI/');
	$rss->add_module(prefix=>'dc', uri=>'http://purl.org/dc/elements/1.1/');
	$rss->add_module(prefix=>'wp', uri=>'http://wordpress.org/export/1.0/');
	

	$rss->channel(
		title		=> 'MediaWiki to Wordpres Migrator',
		link		=> 'http://analogrithems.com/rant/mediawiki2wordpress',
		language 	=> 'en',
		decription 	=> 'Migration Script to migrate mediawiki pages to wordpress pages',
		wp		=>
		{
			base_site_url 	=> $url,
			base_blog_url	=> $url,
			wxr_version	=> 1.1,
			author		=>
			{
				author_id	=> 2,
				author_login	=> 'admin',
				author_email	=> '',
				author_display_name => '',
				author_first_name   => '',
				author_last_name    => ''
			}
		}
	);

	my @pages = @{$XML->{mediawiki}{page}};
	my $content_temp = "";
	my $mw_link = "";
	my @img;
	foreach my $page_i (@pages) {
		$content_temp = $page_i->{revision}{text}{CONTENT};
		$mw_link = $page_i->{title};
		$mw_link =~ s/ /_/g;
		$mw_link =~ s/[^\w]/_/g;
		
		# Parse for [[Category - just flag it up
		$content_temp =~ s/\[{2}Category(.*?)\]{2}/<b>FIXME_Category $1<\/b>/g;
		$content_temp =~ s/\[{2}:Category(.*?)\]{2}/<b>FIXME_Category $1<\/b>/g;
		
		# Parse for [[User - just flag it up
		$content_temp =~ s/\[{2}User(.*?)\]{2}/<b>FIXME_User $1<\/b>/g;
		
		# Parse for [[MediaWiki - just flag it up_
		$content_temp =~ s/\[{2}MediaWiki(.*?)\]{2}/<b>FIXME_MediaWiki $1<\/b>/g;
		
		# Parse for [[Media - make simple hyperlinks
		$content_temp =~ s/\[{2}Media:(.*?)\|(.*?)\]{2}/<a href=\"$medurl\/$1\">$2<\/a>/g;
		$content_temp =~ s/\[{2}Media:(.*?)\]{2}/<a href=\"$medurl\/$1\">$1<\/a>/g;
		
		# Parse for [[File - look like images (i.e., contain PNG/JPG. 
		$content_temp =~ s/\[{2}File:(.*?)([Pp][Nn][Gg])(.*?)\]{2}/[[Image:$1$2$3]]/g;
		$content_temp =~ s/\[{2}File:(.*?)([Jj][Pp][Gg])(.*?)\]{2}/[[Image:$1$2$3]]/g;
		
		# Parse for [[File - make simple hyperlinks
		$content_temp =~ s/\[{2}File:(.*?)\|(.*?)\]{2}/<a href=\"$medurl\/$1\">$2<\/a>/g;
		$content_temp =~ s/\[{2}File:(.*?)\]{2}/<a href=\"$medurl\/$1\">$1<\/a>/g;
		
		# Parse for ''' and '' for bold and italic
		$content_temp =~ s/\'{3}(.*?)\'{3}/<b>$1<\/b>/g;
		$content_temp =~ s/\'{2}(.*?)\'{2}/<i>$1<\/i>/g;
		
		# Parse for headings
		$content_temp =~ s/\n\={6}\ ?(.*?)\ ?\={6}\n/\n<h6>$1<\/h6>\n/gm;
		$content_temp =~ s/\n\={5}\ ?(.*?)\ ?\={5}\n/\n<h5>$1<\/h5>\n/gm;
		$content_temp =~ s/\n\={4}\ ?(.*?)\ ?\={4}\n/\n<h4>$1<\/h4>\n/gm;
		$content_temp =~ s/\n\={3}\ ?(.*?)\ ?\={3}\n/\n<h3>$1<\/h3>\n/gm;
		$content_temp =~ s/\n\={2}\ ?(.*?)\ ?\={2}\n/\n<h2>$1<\/h2>\n/gm;
		$content_temp =~ s/\n\={1}\ ?(.*?)\ ?\={1}\n/\n<h1>$1<\/h1>\n/gm;
		
		# Poor attempt at tables - This makes AWFUL HTML but is a start.
		# Wordpress seems to tidy it up, though.
		$content_temp =~ s/\n\{\|(.*?)$/<table $1 >\n<tr>/gm;
		$content_temp =~ s/\n\|\}/<\/tr>\n<\/table>/gm;
		$content_temp =~ s/\ ?[\|\!][\|\!]\ ?/<\/td><td>/g;
		$content_temp =~ s/\n[\|\!]-/<\/td><\/tr><tr>/g;
		$content_temp =~ s/\n[\|\!]\ ?/<td>/g;
		
		# Some other bits here
		$content_temp =~ s/\n\-{4}\n/<hr>/gm;
		$content_temp =~ s/__NOTOC__//g;
		$content_temp =~ s/__TOC__//g;
		$content_temp =~ s/\n\ *?\* *?(.*?)\n/<ul><li>$1<\/ul>\n/gm; # try and make something of bullet points?
		$content_temp =~ s/\n\ *?\: *?(.*?)\n/<div style="text-indent: 1em;">$1<\/div>\n/gm; # try and make something of : indents?
		$content_temp =~ s/#REDIRECT (.*?)\]{2}/This page was moved here: $1\]\]. <a href="\/contact-me">Please report this message to the webmaster<\/a>\./g;
		
		# Math things
		$content_temp =~ s/<math>(.*?)<\/math>/$1/g;
		$content_temp =~ s/\\Omega/&Omega;/g;
		$content_temp =~ s/\^\\circ/&deg;/g;
		$content_temp =~ s/\\lambda/&lambda;/g;
		$content_temp =~ s/\\.*?frac\{1\}\{2\}/&frac12;/g; # 1/2
		$content_temp =~ s/\\.*?frac\{1\}\{4\}/&frac14;/g; # 1/4
		$content_temp =~ s/\\.*?frac\{4\}\{3\}/1&#x2153;/g; # 4/3

		# Parse (or try to) the [[Image:.....]] tags.
		while($content_temp =~ /\[{2}[Ii]mage:(.+?)\]{2}/g ) {
			@img = split('\|', $1); #pull in the match, and split on |
			my $fn = $img[0]; #filename always first
			my $wd = 0;
			my $at = "";
			my $imstr = "";
			my @dt = split('-', &ctime($page_i->{revision}{timestamp})); # date
			
			# loop through all vars looking for one with "px"
			for (my $i=1; $i<scalar(@img); $i++) {
				# pixel size of image
				if ($img[$i] =~ m/px$/) {
					$wd = 0 + $img[$i]; # this isn't the best way to do this, but meh!
				}
				# alt text of image
				if ( ($img[$i] !~ /px$/) && ($img[$i] !~ /^right$/i) && ($img[$i] !~ /^left$/i) && ($img[$i] !~ /^center$/i) && ($img[$i] !~ /^centre$/i) &&  ($img[$i] !~ /^thumb$/i) ) {
					$at = $img[$i];
					$at =~ s/\"//g;
				}
			}
			# form string with tags we have.
			$imstr = "<a href=\"" . $imgurl . "/" . $dt[0] . "/" . $dt[1] . "/". $fn . "\"><img src=\"" . $imgurl . "/" . $dt[0] . "/" . $dt[1] . "/". $fn . "\"";
			if ($wd > 0) {$imstr = $imstr . " width=\"" . $wd . "\"";}
			if ($at ne "") {$imstr = $imstr . " alt=\"" . $at . "\"";}
			$imstr = $imstr . " class=\"aligncenter\"></a>";
			# replace matching filenames with first matching index.
			$content_temp =~ s/\[{2}[Ii]mage:$fn.*\]{2}/$imstr/g;
		}

		#$content_temp =~ s/\[{1}([\S&&[^\]]+?)\s(.*?)\]{1}/<a href=\"$1\">$2<\/a>/g;

		# Parse internal links (without description, using page title as description)
		while($content_temp =~ /\[{2}(.*?)\]{2}/g) {
			my $f = $1;
			if ($f !~ m/\|/) { # if the string doesn't contain a pipe
				my $u = &pageSlug($f); #filename always first
				my $t = $f;
				my $tstr = "<a href=\"" . $url. '/' . $u . "\">" . $t ."</a>" ;
				$content_temp =~ s/\[{2}$f\]{2}/$tstr/g;
			}
		}

		# Parse internal links (with description)
		while($content_temp =~ /\[{2}(.*?)\|(.*?)\]{2}/g) {
			my $u = &pageSlug($1); #filename always first
			my $t = $2;
			my $tstr = "<a href=\"" . $url. '/' . $u . "\">" . $t ."</a>" ;
			$content_temp =~ s/\[{2}$1\|$2\]{2}/$tstr/g;
		}

		$content_temp =~ s/\[{2}(.*?)\]{2}/<b>FIXME: $1 <\/b>/g;
		$content_temp =~ s/\[{1}([\S&&[^\]]+?)\s(.*?)\]{1}/<a href=\"$1\">$2<\/a>/g;
		
		if ($redirect > 0) {
			print STDERR "\t RewriteRule ^/wiki/" . $mw_link ."\t/" . &pageSlug($page_i->{title}) . "\t[R=302]\n";
		}
		
		$rss->add_item(
			title		=> $page_i->{title},
			#link		=> $url.$post_type.'/'.&pageSlug($page_i->{title}),
			link		=> $url.'/'.&pageSlug($page_i->{title}),
			description	=> '',
			dc		=>
			{
				creator		=> $page_i->{revision}{contributor}{username}
			},
			content		=>
			{
				encoded	=> $content_temp
			},
			wp		=>
			{
				post_date	=> &ctime($page_i->{revision}{timestamp}),
				post_name	=> &pageSlug($page_i->{title}),
				status		=> $page_status,
				post_type	=> $post_type,
				ping_status	=> $ping_status,
				comment_status 	=> $comment_status,
				menu_order	=> '',
				post_password	=> '',
				post_id		=> $page_i->{revision}{id},
				post_parent	=> $parent
				
			}
		);
	}
	if($opt{o}){
		$rss->save($opt{o});
	}else{
		print $rss->as_string."\n";
	}

}
init();
