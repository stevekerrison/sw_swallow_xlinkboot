.section .cp.rodata, "ac", @progbits
.align 4
bootrom_reentry_point:
//This is where we re-enter the boot-rom to do another link boot
//It REQUIRES that r0 contain the chanend we'll boot from,
//so be sure to do that!
  .word 0xffffc0a2
//Oh, and we need the bootrom's DP as well
bootrom_dp:
  .word 0xffffc344

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
  ldc r1,10
  shl r2,r2,r1
  ldc r1,0x405
  ldc r5,0x108
  ldc r6,0x10a
  shl r5,r5,8
  shl r1,r1,8
  shl r6,r6,8
  setc res[r1],8
  setc res[r5],8
  setc res[r6],8
loop:
  ldc r3,0
  add r0,r0,1
  out res[r1],r0
  out res[r5],r0
  out res[r6],r0
  bu rtn
wait:
  add r3,r3,1
  eq r4,r2,r3
  bt r4,loop
  bu wait
  /* Jump back to the bootloader. */
rtn:
	getr r0,0x2
	ldc r1,0xffff
	shl r1,r1,16
	ldc r2,0xc344
	or r1,r2,r1
	set dp,r1
	ldc r1,0xffff
	shl r1,r1,16
	ldc r2,0xc0a2
	or r1,r2,r1
  bau r1
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
  ldc r0,0x0
  ldc r2,0x1000
  ldc r1,10
  shl r2,r2,r1
  ldc r1,0x405
  ldc r5,0x108
  ldc r6,0x10a
  shl r5,r5,8
  shl r1,r1,8
  shl r6,r6,8
  setc res[r1],8
  setc res[r5],8
  setc res[r6],8
loop2:
  ldc r3,0
  add r0,r0,1
  out res[r1],r0
  out res[r5],r0
  out res[r6],r0
wait2:
  add r3,r3,1
  eq r4,r2,r3
  bt r4,loop2
  bu wait2
.align 4
bootprog2_code_end:
.cc_bottom bootprog2_code.elim


/*.section .text
.cc_top pll_done.elim, pll_done
.globl pll_done
.globl pll_done_end
.globl pll_done.maxthreads
.linkset pll_done.maxthreads, 4
.align 4
pll_done:
  ldc r0,6
  setc res[r0],0x8
  setc res[r0],0xf
  ldc r0,0x0
  ldc r2,0x1000
  ldc r1,10
  shl r2,r2,r1
  ldc r1,0x405
  ldc r5,0x108
  shl r5,r5,8
  shl r1,r1,8
  setc res[r1],8
  setc res[r5],8
loop:
  ldc r3,0
  add r0,r0,1
  out res[r1],r0
  out res[r5],r0
wait:
  add r3,r3,1
  eq r4,r2,r3
  bt r4,loop
  bu wait
  //Jump back to the bootloader.
	ldc r0,0
	not r0,r0
	ldc r1,0x3fff
	sub r0,r0,r1
	bau r0
.align 4
bootprog_code_end:
.cc_bottom bootprog_code.elim*/
