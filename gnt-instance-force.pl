#!/usr/bin/perl -T

use strict;
use warnings;

delete $ENV{'PATH'};
my ($action,$host);
my $PS = "/bin/ps";
my $GNT_INSTANCE = "/usr/sbin/gnt-instance";
my $SEND_BREAK = "/etc/conserver/send-break-to-ganeti-vm.sh";
my $RESET = "/etc/conserver/reset-ganeti-vm.sh";

unless(defined($ENV{'SSH_ORIGINAL_COMMAND'})) {
	print "Bad method\n";
	exit -1;
}

my @cmd = split(/ /,$ENV{'SSH_ORIGINAL_COMMAND'});

my $command;
if ( $#cmd == 2 && $cmd[0] eq "gnt-instance" ) {
	shift @cmd;
	$command = "$GNT_INSTANCE";

	unless ( $cmd[0] =~ m/^(console|startup|shutdown|reboot)$/ ) {
		print "Bad gnt-instance action\n";
		exit -1;
	}
	$action = $1;
	shift @cmd
} elsif ( $#cmd == 1 && $cmd[0] eq $SEND_BREAK ) {
	shift @cmd;
	$command = $SEND_BREAK;
} elsif ( $#cmd == 1 && $cmd[0] eq $RESET ) {
	shift @cmd;
	$command = $RESET;
} else {
	print "Bad args or command\n";
	exit -1;
}

unless ( $cmd[0] =~ m/^([a-zA-Z0-9_\.-]+)$/ ) {
	print "command=$command\n";
	print "to be host=".$cmd[0]."\n";
	print "Bad host\n";
	exit -1;
}
$host = $1;

#kill any running session for this console
if ( $command eq $GNT_INSTANCE && $action eq 'console' ) {
	open(PS,"-|",$PS,"-o","pid=","-o","args=","-u","root") || die("$PS: $!");
	while (<PS>) {
		m/^\s*([0-9]{1,6}) (.+)$/ or last;
		my ($pid,$args) = ($1,$2);
		if ($args =~ m/^\/usr\/bin\/python\d* (\/usr|)\/sbin\/gnt-instance console $host$/) {
			kill(9,$pid) || die("kill: $!");
		}
	}
	close(PS) || die("close: $!");
}

# needed for gnt-instance to find ssh:
$ENV{'PATH'} = "/usr/bin";
if ( $command eq $GNT_INSTANCE ) {
	exec($GNT_INSTANCE,$action,$host);
} elsif ( $command eq $SEND_BREAK ) {
	# this tool needs gnt-instance in path.
	$ENV{'PATH'} = "/usr/bin:/usr/sbin";
	exec($SEND_BREAK, $host);
} elsif ( $command eq $RESET) {
	# this tool needs gnt-instance in path.
	$ENV{'PATH'} = "/usr/bin:/usr/sbin";
	exec($RESET, $host);
}
die("exec: $!");
