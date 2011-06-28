#!/usr/bin/perl -w
#
# gen_addrs.pl - Generate the addrs.c file for use in the tpe-lkm module
#
# This script was thrown together really fast to make the addrs.c file
# be generated at make time, rather than have it as a template and it mangled
# at make time. It determines which structs and functions it needs to be
# aware of, as well and get the addresses of the nessisary kernel symbols
#
# Okay so, why? Because then I don't have to maintain the addrs.c file manually.
# Everything in it is deterministic (obviously) and if I ever add more functions
# to hijack, I don't need to edit this file. The hard work is done for me.
#

use strict;
use warnings;

my @files = (
	'security.c',
);

my @funcs;

print qq~/*

DO NOT EDIT THIS FILE!! It has been auto-generated by make

Edit gen_addrs.pl instead.

*/

#include "tpe.h"

extern void hijack_syscall(struct code_store *, unsigned long *, unsigned long *);

~;

foreach my $file (@files) {

	open FILE, $file;
	my @file = <FILE>;
	close FILE;

	# print structs

	foreach my $line (@file) {

		if ($line =~ /^struct code_store /) {
			print "extern " . $line;

			my $func = $line;
			chomp $func;
			$func =~ s/.* cs_//;
			$func =~ s/;.*//;

			push @funcs, $func;
		}

	}

	print "\n";

	# print functions

	my $ok = 0;

	foreach my $line (@file) {

		$line =~ s/\) *\{/);/;

		if ($line =~ /^int tpe_/) {
			$ok = 1;
			print "extern ";
		}

		print $line if $ok == 1;

		if ($line =~ /;/) {
			$ok = 0;
		}

	}

	print "\n";

}

foreach my $func (@funcs) {
	print "struct kernsym *sym_$func;\n";
}

print qq~
extern struct kernsym *find_symbol_address(const char *);
extern struct mutex gpf_lock;

int hijack_syscalls(void) {

	mutex_init(\&gpf_lock);
~;

foreach my $func (@funcs) {

	if ($func =~ /compat/) {
		print "#ifndef CONFIG_X86_32\n";
	}

print qq~
	sym_$func = find_symbol_address("$func");

	if (IS_ERR(sym_$func)) {
		printk("Caught error while trying to find symbol address for $func\\n");
		return sym_$func;
	}

	hijack_syscall(&cs_$func, (unsigned long)tpe_$func, sym_$func->addr);
~;

	if ($func =~ /compat/) {
		print "#endif\n";
	}

}

print "\n\treturn 0;\n}\n";

print "void undo_hijack_syscalls(void) {\n";

foreach my $func (@funcs) {

	if ($func =~ /compat/) {
		print "#ifndef CONFIG_X86_32\n";
	}

	print "\tstop_my_code(&cs_$func);\n";

	print "\tkfree(sym_$func);\n";

	if ($func =~ /compat/) {
		print "#endif\n";
	}

}

print "\n}\n";
