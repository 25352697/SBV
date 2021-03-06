package SBV::DATA;
#------------------------------------------------+
#    [APM] This moudle is generated by amp.pl    |
#    [APM] Creat time: 2013-05-15 17:30:55       |
#------------------------------------------------+
=pod

=head1 Name

SBV::DATA

=head1 Synopsis

This module is not meant to be used directly

=head1 Feedback

Author: Peng Ai
Email:  aipeng0520@163.com

=head1 Version

Version history

=head2 v1.0

Date: 2013-05-15 17:30:55

=cut

use strict;
use warnings;

require Exporter;
use FindBin;
use Tie::File;
use File::Copy;

use lib "$FindBin::RealBin";
use lib "$FindBin::RealBin/lib";
use lib "$FindBin::RealBin/../lib";

use SBV::DEBUG;
use SBV::Constants;

sub new 
{
	my $class = shift;

	my %param = @_;
	my $this;
	
	my $file = $param{'-file'} || ERROR("no_file");
	my $format = $param{'-format'} || "table";

	my %readfunc = (
		table  => \&read_table,
		class  => \&read_class,
		list   => \&read_list,
		list2  => \&read_list2,
		bubble => \&read_bubble,
		aln    => \&read_aln,
		chrlen => \&read_chr_len,
		domain => \&read_domain,
		symbol => \&read_symbol,
		taxonomy => \&read_taxonomy,
	);

	ERROR('no_data_format') if (! $readfunc{$format});
	
	$this = &{$readfunc{$format}}($file,$param{'-conf'});

	bless $this , $class;
	return $this;
}

# read table
sub read_table
{
	my $file = shift;
	my $conf = shift;
	my $res;
	
	my $header = $conf->{'header'};
	my $rownames = $conf->{'rownames'};
		
	open TAB,$file or die "can't open $file $!";
	
	my (@colnames,$colnum,@rownames);

	$_ = <TAB>;
	chomp $_;
	@colnames = split /[\t\,]/;
	shift @colnames if ($rownames);
	$colnum = scalar @colnames;
	ERROR('no_data_err') if ($colnum == 0);

	if (! $header)
	{
		@colnames = map { "C" . $_ } 1 .. $#colnames + 1;
		
		close TAB;
		open TAB,$file or die "can't open $file $!";
	}
	
	while(<TAB>)
	{
		chomp;
		next if (/^#/ || $_ eq "");	
		my @temp = split /[\t\,]/;
		
		my $rowid = $rownames ? $temp[0] : "R" . $.;
		push @rownames , $rowid;
		
		shift @temp if ($rownames);

		ERROR('table_column_diff') if ($colnum ne ($#temp + 1));
		map { push @{$res->{main}->{$colnames[$_]}} , $temp[$_] } 0 .. $colnum - 1;
	}

	close TAB;
	
	$res->{names} = \@colnames;
	$res->{rownames} = \@rownames;

	return $res;
}

# check list file format 
sub check_list_format
{
	my $file = shift;

	open FH,$file or die "$!";
	while(<FH>)
	{
		my @temp = split /$SEP/;
		return "list2" if ($#temp > 1);
	}
	close FH;

	return "list";
}

# read the list file 
# like:
# A 1
# A 2
# B 3
# C 4
# C 8
# C 5
sub read_list
{
	my $file = shift;
	my $conf = shift;
	my $res;
	
	my $header = $conf->{'header'};
	
	my (@names);

	open FH,$file or die "$file $!";
	<FH> if ($header);
	while(<FH>)
	{
		chomp;
		next if (/^#/);
		my @temp = split /[\t\,]/;
		my $name = shift @temp;
		my $val = shift @temp;
		push @names , $name if (! $res->{$name});
		push @{$res->{$name}} , $val;
	}
	close FH;

	$res->{names} = \@names;

	return $res;
}

# read list type 2 file 
# like:
# A	1,2,3
# B	4,5,6
# C	9,19,11
sub read_list2
{
	my $file = shift;
	my $conf = shift;
	my $res;
	
	my $header = $conf->{'header'};
	
	my (@names);

	open FH,$file or die "$file $!";
	<FH> if ($header);
	while(<FH>)
	{
		chomp;
		next if (/^#/);
		my ($name,$vals)  = split /\t/ , $_ , 2;
		my @val = split /[\t\,]/ , $vals;
		push @names , $name;
		$res->{$name} = \@val;
	}
	close FH;
	
	$res->{names} = \@names;

	return $res;
}

# fetch col names of table data
sub names
{
	my $self = shift;
	return @{$self->{names}};
}

# fetch row names of table data
sub rownames
{
	my $self = shift;
	return @{$self->{rownames}};
}

# fetch main data of table data
sub main
{
	my $self = shift;
	return $self->{main};
}

#===  FUNCTION  ================================================================
#         NAME: read_class
#      PURPOSE: read classification file
#   PARAMETERS: file, conf hash
#      RETURNS: data hash
#  DESCRIPTION: read classification file which must be separated by <tab> or ','
#               1. if the header is true, please set it in configuration file.
#               2. the first 'level' column is the name of the classification.
#               3. followed column is the values
#               4. the last column of color for the last level classification
#                  is optional.
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub read_class {
	my $file = shift;
	my $conf = shift;
	my $res;

	my $header = $conf->{'header'} ? uc $conf->{'header'} : 'FALSE';
	my $level = 1;
	
	open IN,$file or die "can't open $file $!";
	<IN> if ($header eq "T" || $header eq "TRUE");
	
	while (<IN>)
	{
		chomp;
		my @temp = split /[\t\,]/ , $_;
		my $col = pop @temp if ($conf->{col} && $conf->{col} eq "file");
		
		$res->{$temp[0]}->{val} = pop @temp;
		$res->{$temp[0]}->{col} = $col;
		$res->{$temp[0]}->{order} = $.;
	}

	return $res;
} ## --- end sub read_class

sub fetch_class_names
{
	my $self = shift;

	my %hash;
	foreach my $name (keys %$self)
	{
		my $order = $self->{$name}->{order};
		$hash{$order} = $name;
	}

	my @names;
	foreach (sort {$a<=>$b} keys %hash)
	{
		push @names , $hash{$_};
	}

	return @names;
}

#===  FUNCTION  ================================================================
#         NAME: read_aln
#      PURPOSE: read aln file
#   PARAMETERS: aln file generated by aras.pl with -I
#      RETURNS: a hash save the aln result
#  DESCRIPTION: 
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub read_aln
{
	my $file = shift;
	my $res;

	open ALN,$file or die "$file $!";
	while(<ALN>)
	{
		chomp;
		my @temp = split /[\t\,]/;
		$res->{$temp[1]}->{len} = $temp[2];
		push @{$res->{$temp[1]}->{aln}} , [$temp[3],$temp[4],$temp[5],$temp[6],$temp[7],$temp[8]];
	}
	close ALN;

	return $res;
}


#===  FUNCTION  ================================================================
#         NAME: read_chr_len
#      PURPOSE: 
#   PARAMETERS: chr length list file
#      RETURNS: 
#  DESCRIPTION: ????
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub read_chr_len
{
	my $file = shift;
	my $conf = shift;
	my $spacing = $conf->{chr_spacing};
	$spacing =~ s/u$//g;
	my $res = {};

	open FH,$file or die "can't open file $file $!";
	my $sta = $spacing;
	while(<FH>)
	{
		chomp;
		my ($chr,$len) = split;
		$res->{$chr}->{'length'} = $len;
		$res->{$chr}->{'start'} = $sta;
		$sta += $len + $spacing;
		$res->{$chr}->{'end'} = $sta - 1 - $spacing;
	}
	close FH;

	$res->{sum} = $sta - 1;

	return $res;
}


#===  FUNCTION  ================================================================
#         NAME: read_domain
#      PURPOSE: read domain DESCRIPTION file
#   PARAMETERS: 
#      RETURNS: 
#  DESCRIPTION: file format: 8 columns
#               Name   Length  Start   Stop    Symbol  Color   Fill    Label
#       THROWS: no exceptions
#     COMMENTS: none
#     SEE ALSO: n/a
#===============================================================================
sub read_domain
{
	my $file = shift;
	my $res = {};

	open FH,$file or die "$!";
	while(<FH>)
	{
		next if (/^#/);
		chomp;
		my @arr = split /[\t\,]/;
		push @{$res->{$arr[0]}} , [$arr[1],$arr[2],$arr[3],$arr[4],$arr[5],$arr[6],$arr[7]];
	}
	close FH;
	
	my @names = keys %$res;
	$res->{names} = \@names;
	return $res;
}


#-------------------------------------------------------------------------------
# FUNCTION: read symbol define table file for tree modify 
# format: 5 columns
# Name	Symbo	Color	Fill	Label
#-------------------------------------------------------------------------------
sub read_symbol
{
	my $file = shift;
	my $res = {};

	open FH,$file or die "$!";
	while(<FH>)
	{
		next if (/^#/);
		chomp;
		my @arr = split /[\t\,]/;
		push @{$res->{$arr[0]}} , [$arr[1],$arr[2],$arr[3],$arr[4]];
	}
	close FH;
	
	my @names = keys %$res;
	$res->{names} = \@names;
	return $res;
}

# trans key
sub trans_key
{
	my ($self,$trans) = @_;
	my $newhash;

	foreach my$key (%$self)
	{
		if (! exists $trans->{$key} || $trans->{$key} eq $key)
		{
			$newhash->{$key} = $trans->{$key};	
		}
		else
		{
			$newhash->{$trans->{$key}} = $self->{$key};
		}
	}

	$self = $newhash;
}

# add header for table file 
sub add_header
{
	my $file = shift;
	my $newfile = shift;
	my %opts = @_;
	
	copy($file,$newfile) or die "can't copy file $file to $newfile!";
	tie my@array , 'Tie::File', $newfile or die;
	
	my @temp = split /\t/ , $array[0];
	
	my @header = map {'V' . $_} 1 .. $#temp+1; 

	if ($opts{rownames})
	{
		pop @header;
		unshift @header , "ID";
	}
	
	my $line = join "\t" , @header;
	unshift @array , $line;

	untie @array;

	return $newfile;
}

sub read_taxonomy
{
	my $file = shift;
	my @res;

	open FH, $file or die $!;
	while(<FH>)
	{
		chomp;
		my @arr = split /\t/;
		push @res ,\@arr;
	}
	close FH;
	close FH;

	return \@res;
}
