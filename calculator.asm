# Author: Kimmo Brunfeldt
# License: MIT
#
# Calculator that supports + - * / operations. Brackets () also work.
#
# Test inputs:

# > 3*(1+1-6*4/5*(4+(1)/3)+2/3)*(1/2)-33+(((((((6+6))*2))*2)))
# -12.200005

# > 2147483648
# Overflow!

# > 2147483647+1
# 2.14748365E9

# Individual numbers are stored to int, so maximum individual number is 2^31 - 1.
# Result can be as big as single precision float can store.

# BNF for calculator:
#
# <calculation> ::= <term> ("+"|"-" <term>)*
# <term> ::= <number> ("*"|"/" <number>)*
# <number> ::= ("0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9")+ | "(" <calculation> ")"

# Globals:
# $s0 = Address to memory where operation string is located. Reading "cursor".
# $fp = Starting position of $sp

# Global constants:
# $f28 = +Infinity
# $f30 = -Infinity

		.globl		main
		.data		0x10010000
		
			      # (   )   *   +   -   /       '0' - '9' are also included to legal
list_legal_chars:.word		40, 41, 42, 43, 45, 47, 0

str_prompt:	.asciiz		"> "
str_new_line:	.asciiz		"\n"
str_err_syntax:	.asciiz		"Syntax error.\n"
str_err_overflow:.asciiz	"Overflow!\n"
str_err_illegal_chars:.asciiz	"Illegal characters in input!\n"
str_err_exception:.asciiz	"Runtime exception!\n"

str_quit:	.asciiz		"Quit.\n"
str_input:	.space		101		# Max inputsize

		.text		0x00400000


main:
		# Set global constants
		li	$t0, 0x7f800000
		mtc1	$t0, $f28		# +Infinity
		li	$t0, 0xff800000
		mtc1	$t0, $f30		# -Infinity
		
		move	$fp, $sp		# Save stackpointer's position in the start

prompt_loop:	move	$sp, $fp
		la	$s0, str_input		# Set address to start position
			
		# Print prompt
		la	$a0, str_prompt
		li	$v0, 4
		syscall
		
		# Read input
		la	$a0, str_input		# Where to put input
		li	$a1, 101		# Set character limit
		jal	read_input
		
		# If input starts with 'q', end program
		la	$t0, str_input
		lb	$t1, ($t0)
		beq	$t1, 113, stop
		
		beq	$t1, 0, prompt_loop	# If input is empty, print new prompt
		
		# Check if input includes only legal characters
		la	$a0, str_input
		la	$a1, list_legal_chars
		jal	check_input
		beq	$v0, 1, error_illegal_chars
		
		jal	calculation

		# Check that we reached the end of input
		# Prevent calculations like 5+5)+1
		lb	$t0, ($s0)
		bne	$t0, 0, error_syntax
		
		lw	$t0, ($sp)		# Load result from stack
		mtc1	$t0, $f12		# Move result to coprocessor
		
		# Check if result was +-infinity
		c.eq.s	$f12, $f28
		bc1t	error_overflow
		c.eq.s	$f12, $f30
		bc1t	error_overflow
		
		# Print result, it is already in correct register($f12)
		li	$v0, 2
		syscall
		la	$a0, str_new_line		# Print '\n'
		li	$v0, 4
		syscall				
		
		j	prompt_loop


# Read input from user. Replaces '\n' character with '\0'
# Parameters:
#   $a0 = Address to memory where to write input
#   $a1 = Maximum characters to read
read_input:
		li	$v0, 8			# Read input from user, $a0 and $a1 are already set.
		syscall

replace_nl_loop:
		lb	$t0, ($a0)		# Load character
		addi	$a0, $a0, 1
		beq	$t0, 0, read_input_return  # We reached the end of input.
		bne	$t0, 10, replace_nl_loop   # If character is not '\n' move to next character
		
		li	$t1, 0			# Replace '\n' -> '\0'
		sb	$t1, -1($a0)		# Loop adds 1 times too much.

read_input_return:
		jr 	$ra


# Checks that a string does not contain illegal characters
# Parameters:
#   $a0 = Address of string to check
#   $a1 = Address of list that contains legal characters
# Returns:
#   $v0 = tells if input was correct, 0 = correct, 1 = not correct
check_input:
		addi	$sp, $sp, -4
		sw	$ra, ($sp)		# Save return address to stack
		move	$t0, $a0
		move	$t1, $a1
		li	$v0, 0
			
check_loop:	lb	$a0, ($t0)		# Read character to parameter
		beq	$a0, 0, check_input_return  # Check if we are in the end of string.
		jal 	is_illegal_char
		beq	$v0, 1, check_input_return  # $v0 = 1, return that string is illegal
		addi	$t0, $t0, 1		# Next character
		j	check_loop
		
	
check_input_return:
		lw	$ra, ($sp)		# Load return address from stack
		addi	$sp, $sp, 4
		jr	$ra


# Checks if character is illegal
# Parameters:
#   $a0 = ASCII value of character
# Return values:
#   $v0 = tellsif character is illegal, 0 = legal, 1 = illegal
is_illegal_char:
		move	$t1, $a1		# Address of list of legal characters
		li	$v0, 0			# Default: character is legal
		sle	$t2, $a0, 57		# Check if character is '0' - '9'
		sge	$t3, $a0, 48
		and	$t3, $t2, $t3
		beq	$t3, 1, is_illegal_char_return 	# Character is '0' - '9', return legal
		
		# Check if character is in list of legal characters
char_loop:	lw	$t2, ($t1)		# Load word from list of legal chars
		beq	$t2, 0, bad_char	# We reached the end of list, character was not found from list
		addi	$t1, $t1, 4		# List's elemets are words, so next element is after 4 bytes
		beq	$t2, $a0, is_illegal_char_return  # Jos listalta löytyi sama merkki, se on sallittu. 
		j	char_loop

bad_char:	li	$v0, 1			# Return illegal

is_illegal_char_return:
		jr	$ra



# Handles + and - operations
# calculation ::= term("+"|"-" term)*
calculation:		
		addi	$sp, $sp, -4		# Write return address to calculation to stack
		sw	$ra, ($sp)
		jal	term
		
		# while ( read_char != '\0' and (read_char == '-' or read_char == '+') )
calculation_loop:
		lb	$t2, ($s0)		# Read char
		sne	$t3, $t2, 0		# char != \0 ?
		seq	$t4, $t2, 45		# char == '-' ?
		seq	$t5, $t2, 43		# char == '+' ?
		
		addi	$sp, $sp, -4
		sw	$t5, ($sp)		# Save boolean "Is this addition(+) operation" to stack
				
		or	$t4, $t4, $t5		# char != '\0' and (char == '/' or char == '*')
		and	$t3, $t3, $t4
		beq	$t3, 0, calculation_return
		addi	$s0, $s0, 1		# Next char
		
		jal	term
		
		lw	$t4, ($sp)		# Load second operand
		addi	$sp, $sp, 4
		lw	$t5, ($sp)		# Load "Is this addition(+) operation" boolean
		addi	$sp, $sp, 4
		lw	$t6, ($sp)		# Load first operand

		mtc1	$t6, $f2		# First operand -> $f2
		mtc1	$t4, $f4		# Second operand -> $f4	
		beq	$t5, 1, calculation_add
		
calculation_sub:
		sub.s	$f2, $f2, $f4		# Substitute the operands to $f2
		swc1	$f2, ($sp)		# Move result to stack
		j	calculation_loop
calculation_add:
		add.s	$f2, $f2, $f4		# Add the operands to $f2
		swc1	$f2, ($sp)		# Move result to stack	
		j	calculation_loop

calculation_return:
		addi	$sp, $sp, 4
		lw	$t0, ($sp)		# Load result from stack
		addi	$sp, $sp, 4
		lw	$ra, ($sp)		# Load return address to calculation from stack
		sw	$t0, ($sp)		# Save result to stack(result now replaced the return address)
		jr	$ra


# Handles * and / operations
# term ::= number("*"|"/" number)*
term:		
		addi	$sp, $sp, -4		# Write return address to calculation to stack
		sw	$ra, ($sp)
		jal	number
		
		# while ( read_char != '\0' and (read_char == '/' or read_char == '*') )
term_loop:
		lb	$t2, ($s0)		# Read char
		sne	$t3, $t2, 0		# char != \0 ?
		seq	$t4, $t2, 47		# char == '/' ?
		seq	$t5, $t2, 42		# char == '*' ?
		
		addi	$sp, $sp, -4
		sw	$t5, ($sp)		# Save boolean "Is this multiply(*) operation" to stack
				
		or	$t4, $t4, $t5		# char != '\0' and (char == '/' or char == '*')
		and	$t3, $t3, $t4
		beq	$t3, 0, term_return
		addi	$s0, $s0, 1		# Next char
		
		jal	number
		
		lw	$t4, ($sp)		# Load second operand
		addi	$sp, $sp, 4
		lw	$t5, ($sp)		# Load "Is this multiply(*) operation" boolean
		addi	$sp, $sp, 4
		lw	$t6, ($sp)		# Load first operand

		mtc1	$t6, $f2		# First operand -> $f2
		mtc1	$t4, $f4		# Second operand -> $f4	
		beq	$t5, 1, term_mul
		
term_div:	div.s	$f2, $f2, $f4		# Divide the operands to $f2
		swc1	$f2, ($sp)		# Move result to stack
		j	term_loop
term_mul:	mul.s	$f2, $f2, $f4		# Multiply the operands to $f2
		swc1	$f2, ($sp)		# Move result to stack	
		j	term_loop

term_return:	addi	$sp, $sp, 4
		lw	$t0, ($sp)		# Load result from stack
		addi	$sp, $sp, 4
		lw	$ra, ($sp)		# Load return address to calculation from stack
		sw	$t0, ($sp)		# Save result to stack(result now replaced the return address)
		jr	$ra


# Returns number to term
# number ::= ("0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"|",")+
number:
		addi	$sp, $sp, -4
		sw	$ra, ($sp)		# Save return address to term to stack
		
		lb	$t0, ($s0)		# Read character		
		bne	$t0, 40, no_new_calculation  # If char != '(', skip section
		
		addi	$s0, $s0, 1		# Next character
		jal	calculation		# Recursively start new calculation
		lb	$t0, ($s0)		# Read character
		sne	$t1, $t0, 41		
		seq	$t2, $t0, 0
		or	$t1, $t1, $t2		# If char != ')' or char == '\0'
		bne	$t1, 0, error_syntax

		addi	$s0, $s0, 1		# Next character
		j	number_return

no_new_calculation:		
		jal	atof
		
number_return:	lw	$t0, ($sp)
		addi	$sp, $sp, 4
		lw	$ra, ($sp)
		sw	$t0, ($sp)
		jr	$ra


# Reads number from input string, converts it to float and writes the float to stack
# Maximum number is 2^31 - 1 = 2147483647
# If string is '123', it counts the length of string = 3
# then it loops from the last digit to first:
# $t6 += 3 * 1
# $t6 += 2 * 10
# $t6 += 1 * 100
# Then $t6 = 123
atof:		
		lb	$t1, ($s0)		# Read character
		sle	$t2, $t1, 57		# Check that character is '0' - '9'
		sge	$t3, $t1, 48
		and	$t3, $t2, $t3
		beq	$t3, 0, error_syntax
		
		
		li	$t0, 0			# Save length of number to $t0
atof_loop:	lb	$t1, ($s0)		# Read character
		sle	$t2, $t1, 57
		sge	$t3, $t1, 48
		and	$t3, $t2, $t3		# $t3 = character is '0' - '9'
		
		addi	$t0, $t0, 1		# Increase length
		addi	$s0, $s0, 1		# Next character
		beq	$t3, 1, atof_loop	# Read character was a digit, read next character
		
		addi	$t0, $t0, -1		# Loop adds 1 times too much
		move	$t1, $t0		# Length of the number to $t1
		li	$t5, 1
		li	$t6, 0			# Total value of number
		li	$t7, 10
		addi	$s0, $s0, -2		# Loop adds too muchs, go back to the last digit.
		
		li	$v0, 0
convert_loop:	lb	$t4, ($s0)		# Read digit
		addi	$t4, $t4, -48		# Convert it to number '0' ascii is 48, 48 - 48 == 0
		addi	$t1, $t1, -1		#
		mul	$t4, $t4, $t5		# $t4 = $t4 * $t5, number * 10^x
		add	$t6, $t6, $t4		# Add number to total value
		beq	$v0, 1, error_overflow
		mul	$t5, $t5, $t7		# $t5 = $t5 * 10
		addi	$s0, $s0, -1		# Move to previous digi
		bne	$t1, 0, convert_loop
		
		add	$s0, $s0, $t0		# Move cursor back to last digit
		addi	$s0, $s0, 1		# Next char
						
atof_return:	mtc1	$t6, $f0		# Move total number to coprocessor
		cvt.s.w	$f0, $f0
		addi	$sp, $sp, -4
		swc1	$f0, ($sp)		# Save converted number to stack
		jr	$ra			# Jump back to number


# Error handlers:
error_syntax:	la	$a0, str_err_syntax
		li	$v0, 4	
		syscall
		j 	prompt_loop

error_overflow:	la	$a0, str_err_overflow
		li	$v0, 4
		syscall
		j 	prompt_loop

error_illegal_chars:
		la	$a0, str_err_illegal_chars
		li	$v0, 4
		syscall
		j 	prompt_loop

# When program is quit
stop:		la	$a0, str_quit
		li	$v0, 4
		syscall
		j 	end

end:		li	$v0, 10
		syscall


# Very bad exception handler. It assumes that all exceptions come from convert_loop.
# When exception comes from convert_loop, it handles the exception and prints str_err_overflow
 		.ktext	0x80000180
 		li	$v0, 1
		mfc0 	$k0,$14   		# Coprocessor 0 register $14 has address of trapping instruction
 		addi 	$k0,$k0,4 		# Add 4 to point to next instruction
		mtc0 	$k0,$14   		# Store new address back into $14
		eret
