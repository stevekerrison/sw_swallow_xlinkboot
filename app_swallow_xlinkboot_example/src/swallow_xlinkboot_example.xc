/*
 * swallow_xlinkboot_example - Example application that can prepare swallow boards to boot.
 *
 * In reality you will integrate the module with your own peripheral device code
 *
 * Provides a compatibility layer when needed, some stuff for initialisation,
 * and enables hybrid streaming channels that replace the "streaming chanend"
 * concept by allowing regular channels to be temporarily used for streaming.
 * 
 * Copyright (C) 2012 Steve Kerrison <github@stevekerrison.com>
 *
 * This software is freely distributable under a derivative of the
 * University of Illinois/NCSA Open Source License posted in
 * LICENSE.txt and at <http://github.xcore.com/>
 */

#include <platform.h>
#include <print.h>
#include "swallow_xlinkboot.h"

out port rst = XS1_PORT_1D; //I on old, D on new

int main(void)
{
  int result;
  struct xlinkboot_pll_t PLLs[1] = {{-1,0,-1,0x00002700,1,5}};
  result = swallow_xlinkboot(1,1,1,SWXLB_POS_BOTTOM,PLLs,1,rst);
  printstr("Result: ");
  printintln(result);
  return result;
}
