.data
# a 256 long 2byte array for the snakes body
#
# Each element in the array consists of 2 bytes representing the height and
# width of the snake
#
# This array is a ringbuf with the head bein `snake_head` and the tail being 
# `snake_tail`
snake: .space 512

# Buffer to store the string we print to the string. Length is 256 + 16
# We add 16 chars for 15 new lines and a \0
print_buf: .asciiz "................
................
................
................
................
................
................
................
................
................
................
................
................
................
................
................\n\n\n"


snake_head: .word 3
snake_tail: .word 0

empty_char: .byte '.'
snake_char: .byte '0'

.text
.globl main
main:
	jal print
	jal read_input

	# Increment snake_head by one
	lw $t1 snake_head
	addi $t1 $t1 1
	li $t2, 16
	div $t1, $t2 # Get t1 % 256
	mfhi $t2
	sw $t2 snake_head

	# Increment snake_tail by one
	lw $t1 snake_tail
	addi $t1 $t1 1
	li $t2, 16
	div $t1, $t2 # Get t1 % 256
	mfhi $t2
	sw $t2 snake_tail


	# We still have the result from read_input in $v0
	lw $t0 snake_head
	la $t1 snake

	sll $t0, $t0, 1 
	add $t1, $t0, $t1

	sh $v0, 0($t1)

	j main

	li $v0, 10
	syscall

	# Reads a single wasd character and returns where the head of the snake
	# should now be
	#
	# $v0: x,y,0,0 (first byte is x, second byte is y, last 2 are unused)
read_input:

	# Read a character
	li $v0, 12
	syscall

	# Get the x and y coord
	la $t2, snake
	lw $t0, snake_head # Get the snakes head index
	sll $t0, $t0, 1 # get the byte index of the x coord into $t0
	addi $t1, $t0, 1 # Get the byte index of the y coord into $t1
	add $t0, $t0, $t2 # Get the address of the index
	add $t1, $t1, $t2 # Get the address of the index
	lb $t1, 0($t1) # Load the byte
	lb $t0, 0($t0) # Load the byte

	li $t2, 'w'
	beq $v0, $t2, __w_char

	li $t2, 'a'
	beq $v0, $t2, __a_char

	li $t2, 's'
	beq $v0, $t2, __s_char

	li $t2, 'd'
	beq $v0, $t2, __d_char

	j read_input
__w_char:
	addi $t1, $t1, -1
	j __end_read_input
__a_char:
	addi $t0, $t0, -1
	j __end_read_input
__s_char:
	addi $t1, $t1, 1
	j __end_read_input
__d_char:
	addi $t0, $t0, 1
	j __end_read_input

__end_read_input:
	addi $sp, $sp, -2 # Make room on the stack for our return value
	# Load our coordinates into the space we made
	sb $t0 0($sp)
	sb $t1 1($sp)
	lh $v0 0($sp)
	addi $sp, $sp, 2

	jr $ra

	# Prints the snake and all the apples to the screen
print:
	# make room on the stack for $s0 and $s1
	addi $sp, -12
	sw $s0, 0($sp)
	sw $s1, 4($sp)
	sw $s2, 8($sp)
	sw $ra, 12($sp)

	# s0 counts which column we're on
	li $s0, -1 
	# s1 counts which line we're on
	li $s1, 0

__print_loop:
	addi $s0, $s0, 1

	li $t8, 16
	bne $s0, $t8, __end_if
	addi $s1, $s1, 1
	li $s0, 0
__end_if:
	
	# set $t0 to be the index of [row][column]
	li $t8 17
	# Multiply s1 (row) by 17. We need to use 17 since the end of
	# each col is used for newline
	mult $s1, $t8 
	mflo $t0
	add $t0, $t0, $s0 # Add column to the row

	li $t7, 272
	ble $t7, $t0, __print_end

	la $t2, print_buf # Set t2 to the address at print buf
	add $t0, $t0, $t2 # Get the array offset from t2 + the index we're on

	# Set the t0th element of the array to be ' '
	lb $t3, empty_char
	sb $t3, 0($t0)

	# check if there is a snake at the location we're at
	move $a0, $s0
	move $a1, $s1 
	move $s2, $t0
	jal snake_at_char
	beq $v0, $zero, __print_loop

	lb $t3, snake_char
	sb $t3, 0($s2)
	j __print_loop

__print_end:

	# Print a new line
	li $v0, 11
	li $a0 '\n'
	syscall

	# Print print_buf to the screen
	li $v0, 4
	la $t0, print_buf
	add $a0, $t0, $zero  
	syscall

	lw $s0, 0($sp)
	lw $s1, 4($sp)
	lw $s2, 8($sp)
	lw $ra, 12($sp)
	addi $sp, 12
	jr $ra


	# Prints whether or not the snake exists at a character.
	#
	# $a0: x coordinate of the snake
	# $a1: y coordinate of the snake
	# $v0: 1 if true, 0 if false.
snake_at_char:
	# Iterate through the snake from snake_tail to snake head.
	lb $t0, snake_tail
	lb $t1, snake_head
	addi $t1, $t1, 1 # Add 1 to the head of the snake, since head is inclusive
	li $t3, 16
	div $t1, $t3 # $t1 % 256
	mfhi $t1

	li $v0, 0

__snake_loop:
	beq $t0, $t1, __snake_end # Go to end if we've reached the end of the loop
	sll $t2, $t0, 1  # Multiply t0 by 2, this will be the x coord in the array
	addi $t3, $t2, 1 # $t2 will be the y coord

	addi $t0, 1 # Increment t0 by one
	# t0 % 256
	li $t8 16
	div $t0, $t8
	mfhi $t0

	# Get the actual byte from the snake at t2 and t3
	la $t8, snake
	add $t2, $t2, $t8
	lb $t2, 0($t2)

	add $t3, $t3, $t8
	lb $t3, 0($t3)

	bne $t2, $a0, __snake_loop # Go back to loop if not equal
	bne $t3, $a1, __snake_loop # Go back to loop if not equal
	li $v0, 1 # They are equal here, set return value to 1 and go to snake_end

__snake_end:
	jr $ra

