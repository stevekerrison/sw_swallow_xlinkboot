.section .text
.cc_top bootprog_code.elim, bootprog_code
.globl bootprog_code
.globl bootprog_code_end
.globl bootprog_code.maxthreads
.linkset bootprog_code.maxthreads, 4
.align 4
bootprog_code:
  ldc r0,6
  setc res[r0],0x8
  setc res[r0],0xf
  ldc r0,0x0
  ldc r2,0x1000
  shl r2,r2,8
  ldc r1,0x405
  shl r1,r1,8
  setc res[r1],8
loop:
  ldc r3,0
  add r0,r0,1
  out res[r1],r0
wait:
  add r3,r3,1
  eq r4,r2,r3
  bt r4,loop
  bu wait
  /* Jump back to the bootloader. */
	ldc r0,0
	not r0,r0
	ldc r1,0x3fff
	sub r0,r0,r1
	bau r0
.align 4
bootprog_code_end:
.cc_bottom bootprog_code.elim

.section .text
.cc_top bootprog2_code.elim, bootprog2_code
.globl bootprog2_code
.globl bootprog2_code_end
.globl bootprog2_code.maxthreads
.linkset bootprog2_code.maxthreads, 4
.align 4
bootprog2_code:
  ldc r0,6
  setc res[r0],0x8
  setc res[r0],0xf
  ldc r0,0x5
  ldc r1,0x405
  shl r1,r1,8
  setc res[r1],8
  out res[r1],r0
  bu -0x1
  /* Jump back to the bootloader. */
	ldc r0,0
	not r0,r0
	ldc r1,0x3fff
	sub r0,r0,r1
	bau r0
	nop
	nop
	nop
	nop
bootprog2_code_end:
.cc_bottom bootprog2_code.elim
