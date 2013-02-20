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
//The above is useless programatically in this file, as the CP is uninitialised,
//but it's useful as reference. See the kissoflife function below for usage example near the end.

.section .text
.cc_top kissoflife.elim, kissoflife
.globl kissoflife
.globl kissoflife_end
.globl kissoflife.maxthreads
.linkset kissoflife.maxthreads, 4
.align 4
kissoflife:
  ldc r0,6
  setc res[r0],0x8
  setc res[r0],0xf
  ldc r0,0x1
  ldc r1,0x405
  ldc r5,0x108
  ldc r6,0x10a
  shl r5,r5,8
  shl r1,r1,8
  shl r6,r6,8
  setc res[r1],8
  setc res[r5],8
  setc res[r6],8
  out res[r1],r0
  out res[r5],r0
  out res[r6],r0
  /* Jump back to the bootloader. */
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
kissoflife_end:
.cc_bottom kissoflife.elim

/* Blinkenlights to demonstrate chainloaded programs... */
.section .text
.cc_top testprog.elim, testprog
.globl testprog
.globl testprog_end
.globl testprog.maxthreads
.linkset testprog.maxthreads, 4
.align 4
testprog:
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
testprog_loop:
  ldc r3,0
  add r0,r0,1
  out res[r1],r0
  out res[r5],r0
  out res[r6],r0
testprog_wait:
  add r3,r3,1
  eq r4,r2,r3
  bt r4,testprog_loop
  bu testprog_wait
.align 4
testprog_end:
.cc_bottom testprog.elim

