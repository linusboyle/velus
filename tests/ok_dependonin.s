# File generated by CompCert 3.5
# Command line: ok_dependonin.lus
	.data
	.align	3
	.globl	_self$
_self$:
	.data
	.align	3
	.globl	_y$
_y$:
	.space	1
	.data
	.align	3
	.globl	_a$
_a$:
	.space	1
	.text
	.align	4
	.globl _fun$f$step
_fun$f$step:
	.cfi_startproc
	subl	$12, %esp
	.cfi_adjust_cfa_offset	12
	leal	16(%esp), %eax
	movl	%eax, 0(%esp)
	movl	4(%eax), %ecx
	cmpl	$0, %ecx
	jne	L100
	xorl	%eax, %eax
	jmp	L101
L100:
	movl	$1, %eax
L101:
	addl	$12, %esp
	ret
	.cfi_endproc
	.text
	.align	4
	.globl _fun$f$reset
_fun$f$reset:
	.cfi_startproc
	subl	$12, %esp
	.cfi_adjust_cfa_offset	12
	leal	16(%esp), %eax
	movl	%eax, 0(%esp)
	addl	$12, %esp
	ret
	.cfi_endproc
	.text
	.align	4
	.globl _main_proved
_main_proved:
	.cfi_startproc
	subl	$28, %esp
	.cfi_adjust_cfa_offset	28
	leal	32(%esp), %eax
	movl	%eax, 8(%esp)
	leal	_self$, %ecx
	movl	%ecx, 0(%esp)
	call	_fun$f$reset
L102:
	movzbl	_a$, %eax
	leal	_self$, %edx
	cmpl	$0, %eax
	setne	%cl
	movzbl	%cl, %ecx
	movl	%ecx, 4(%esp)
	movl	%edx, 0(%esp)
	call	_fun$f$step
	cmpl	$0, %eax
	setne	%al
	movzbl	%al, %eax
	movb	%al, _y$
	jmp	L102
	.cfi_endproc
	.text
	.align	4
	.globl _main
_main:
	.cfi_startproc
	subl	$12, %esp
	.cfi_adjust_cfa_offset	12
	leal	16(%esp), %eax
	movl	%eax, 0(%esp)
	call	_main_proved
	movl	%ebx, %eax
	addl	$12, %esp
	ret
	.cfi_endproc
	.section __IMPORT,__pointers,non_lazy_symbol_pointers
