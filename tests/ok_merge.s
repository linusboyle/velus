# File generated by CompCert 3.5
# Command line: ok_merge.lus
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
	.data
	.align	3
	.globl	_b$
_b$:
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
	movl	%ebx, 4(%esp)
	movl	8(%eax), %ecx
	movl	4(%eax), %ebx
	cmpl	$0, %ebx
	je	L100
	cmpl	$0, %ecx
	sete	%cl
	movzbl	%cl, %ecx
L100:
	cmpl	$0, %ecx
	setne	%al
	movzbl	%al, %eax
	movl	4(%esp), %ebx
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
	movl	%eax, 12(%esp)
	movl	%ebx, 16(%esp)
	movl	%esi, 20(%esp)
	leal	_self$, %eax
	movl	%eax, 0(%esp)
	call	_fun$f$reset
L101:
	movzbl	_a$, %ecx
	movzbl	_b$, %ebx
	leal	_self$, %esi
	cmpl	$0, %ecx
	setne	%dl
	movzbl	%dl, %edx
	cmpl	$0, %ebx
	setne	%cl
	movzbl	%cl, %ecx
	movl	%ecx, 8(%esp)
	movl	%edx, 4(%esp)
	movl	%esi, 0(%esp)
	call	_fun$f$step
	cmpl	$0, %eax
	setne	%al
	movzbl	%al, %eax
	movb	%al, _y$
	jmp	L101
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
