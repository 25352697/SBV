package SBV::STONE::THEME;
#------------------------------------------------+
#    [APM] This moudle is generated by amp.pl    |
#    [APM] Created time: 2013-08-02 09:13:34     |
#------------------------------------------------+
=pod

=head1 Name

SBV::STONE::THEME

=head1 Synopsis

This module is not meant to be used directly

=head1 Feedback

Author: Peng Ai
Email:  aipeng0520@163.com

=head1 Version

Version history

=head2 v1.0

Date: 2013-08-02 09:13:34

=cut

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw /element_text/;

use FindBin;
use lib "$FindBin::RealBin";
use lib "$FindBin::RealBin/lib";
use lib "$FindBin::RealBin/../";
use lib "$FindBin::RealBin/../lib";

use SBV;

# family, size, weight, style, color, angle, hjust, vjust
sub element_text
{
	my $text = shift;
	my $theme = shift;
	my $class = shift || "default";
	$class = "CLASS$class" if ($class !~ /^CLASS/ && $class ne "default");
		
	my $font = SBV::Font->fetch_font($class);
	
	my @theme = split /;/ , $theme;
	my $style = {};
	my $trans = {};
	foreach (@theme)
	{
		my ($name,$val) = split /:/;
		if ($name eq "size" || $name eq "family" || $name eq "weight" || $name eq "style")
		{
			my $tag = "font-$name";
			$font->{$tag} = $val;
			$style->{$tag} = $val;
		}
		elsif ($name eq "color" || $name eq "fill")
		{
			$val = SBV::Colors::fetch_color($val);
			$style->{fill} = $val;
			$font->{fill} = $val;
		}
		else
		{
			$trans->{$name} = $val;	
		}
	}

	if ($class ne "default")
	{
		#$SBV::allStyle->{text}->{$class} = $font; 
		$text->setAttribute("style",$style);
	}
	else
	{
		$text->setAttribute("style",$style);
	}
	
	my $cdata = $text->getCDATA();
	my $width = $font->fetch_text_width($cdata);
	my $height = $font->fetch_text_height();

	my $transform = $text->getAttribute("transform") || "";
	if ($trans->{angle})
	{
		my $x = $text->getAttribute('x');	
		my $y = $text->getAttribute('y');
		my $cx = $x+$width/2;
		my $cy = $y-$height/2;
		$transform = "rotate($trans->{angle},$cx,$cy) $transform";
		
		($width,$height) = SBV::STAT::true_size($width,$height,$trans->{angle});
	}
	
	my $tx = $trans->{hjust} ? $trans->{hjust} * $width : 0;
	my $ty = $trans->{vjust} ? $trans->{vjust} * $height : 0;
	
	$transform = "translate($tx,$ty) $transform" if (0 != $tx || 0 != $ty);

	$text->setAttribute("transform",$transform);

	return $text;
}
