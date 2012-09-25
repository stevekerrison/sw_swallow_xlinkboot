/*
 * swallow_xlinkboot - Boot Swallow boards over XLink
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

#include "swallow_xlinkboot.h"

/* Launch a server thread, receives configuration and then applies it */
void swallow_xlinkboot_server(chanend c_svr)
{
  unsigned boards_w, boards_h, reset, PLL_len, ret, i;
  struct xlinkboot_pll_t PLL[128];
  while(1)
  {
    c_svr :> boards_w;
    c_svr :> boards_h;
    c_svr :> reset;
    c_svr :> PLL_len;
    for (i = 0; i < PLL_len; i += 1)
    {
      c_svr :> PLL[i];
    }
    if (i > 128)
    {
      c_svr <: -XLB_PLL_LENGTH;
    }
    ret = swallow_xlinkboot(boards_w,boards_h,reset,PLL,PLL_len);
    c_svr <: ret;
  }
  return;
}

/* Function call to apply a configuration to an array of swallow boards */
int swallow_xlinkboot(unsigned boards_w, unsigned boards_h, unsigned reset, struct xlinkboot_pll_t PLL[], unsigned PLL_len)
{
  unsigned cols = boards_w * SWXLB_CHIPS_W * SWXLB_CORES_CHIP,
    rows = boards_h * SWXLB_CHIPS_H,
    total_cores = cols*rows;
  if (total_cores > SWXLB_MAX_CORES ||
    cols > COUNT_FROM_BITS(SWXLB_LBITS + SWXLB_HBITS) ||
    rows > COUNT_FROM_BITS(SWXLB_VBITS))
  {
    return -SWXLB_INVALID_BOARD_DIMENSIONS;
  }
  return -SWXLB_GENERIC_FAIL;
} 

