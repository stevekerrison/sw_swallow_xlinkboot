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

#include <platform.h>
#include "swallow_xlinkboot.h"
#include "swallow_comms.h"


/* Launch a server thread, receives configuration and then applies it */
void swallow_xlinkboot_server(chanend c_svr)
{
  unsigned boards_w, boards_h, reset, PLL_len, position, ret, i;
  struct xlinkboot_pll_t PLL[128];
  while(1)
  {
    c_svr :> boards_w;
    c_svr :> boards_h;
    c_svr :> reset;
    c_svr :> position;
    c_svr :> PLL_len;
    for (i = 0; i < PLL_len; i += 1)
    {
      c_svr :> PLL[i];
    }
    if (i > 128)
    {
      c_svr <: -XLB_PLL_LENGTH;
    }
    ret = swallow_xlinkboot(boards_w,boards_h,reset,position,PLL,PLL_len);
    c_svr <: ret;
  }
  return;
}

/* Function call to apply a configuration to an array of swallow boards */
int swallow_xlinkboot(unsigned boards_w, unsigned boards_h, unsigned reset, unsigned position, struct xlinkboot_pll_t PLL[], unsigned PLL_len)
{
  unsigned cols = boards_w * SWXLB_CHIPS_W * SWXLB_CORES_CHIP,
    rows = boards_h * SWXLB_CHIPS_H,
    total_cores = cols*rows,
    rowstride = COUNT_FROM_BITS(SWXLB_LBITS + SWXLB_HBITS),
    myid;
  if (total_cores > SWXLB_MAX_CORES ||
    cols > rowstride ||
    rows > COUNT_FROM_BITS(SWXLB_VBITS))
  {
    return -SWXLB_INVALID_BOARD_DIMENSIONS;
  }
  /* Choose my ID based on which edge of the board I'm connected to... */
  if (position == SWXLB_POS_BOTTOM || position == SWXLB_POS_RIGHT)
  {
    unsigned myid = (MASK_FROM_BITS(SWXLB_VBITS) << SWXLB_VPOS) |
      (MASK_FROM_BITS(SWXLB_HBITS) << SWXLB_HPOS) | (position << SWXLB_LPOS) | 1,
      curid = get_core_id();
    if (curid != myid)
    {
      write_sswitch_reg_no_ack_clean(curid,0x5,myid);
    }
  }
  else
  {
    return -SWXLB_INVALID_PERIPHERAL_POS;
  }
  myid = get_core_id();
  /* Special cases to bring-up the corner, before we launch into generic bring-up of switches */
  if (position == SWXLB_POS_BOTTOM)
  {
    int result;
    /* Bring up core 1 then core 0 */
    result = xlinkboot_link_up(myid, XLB_L_LINKD, SWXLB_PERIPH_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG);
    if (result < 0)
    {
      return result;
    }
  }
  else
  {
    /* Bring up core 0 then core 1 */
  }
  /* We program all the switches by going across each row and up the rightmost edge */
  return -SWXLB_GENERIC_FAIL;
} 

