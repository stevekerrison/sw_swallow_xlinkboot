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

static unsigned swallow_xlinkboot_genid(unsigned row, unsigned col)
{
  return (row << SWXLB_VPOS) | (col << SWXLB_LPOS);
}

/* Launch a server thread, receives configuration and then applies it */
void swallow_xlinkboot_server(chanend c_svr)
{
  unsigned boards_w, boards_h, reset, PLL_len, position, ret, i;
  struct xlinkboot_pll_t PLL[XLB_PLL_LEN_MAX];
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
    if (i > XLB_PLL_LEN_MAX)
    {
      c_svr <: -XLB_PLL_LENGTH;
    }
    ret = swallow_xlinkboot(boards_w,boards_h,reset,position,PLL,PLL_len);
    c_svr <: ret;
  }
  return;
}

/* Function call to apply a configuration to an array of swallow boards */
int swallow_xlinkboot(unsigned boards_w, unsigned boards_h, unsigned reset, unsigned position,
  struct xlinkboot_pll_t PLL[], unsigned PLL_len)
{
  unsigned cols = boards_w * SWXLB_CHIPS_W * SWXLB_CORES_CHIP,
    rows = boards_h * SWXLB_CHIPS_H,
    total_cores = cols*rows,
    rowstride = COUNT_FROM_BITS(SWXLB_LBITS + SWXLB_HBITS),
    myid;
  int c, r, result;
  if (total_cores > SWXLB_MAX_CORES ||
    cols > rowstride ||
    rows > COUNT_FROM_BITS(SWXLB_VBITS))
  {
    return -SWXLB_INVALID_BOARD_DIMENSIONS;
  }
  /* Make my ID something we can pre-boot the compute nodes from */
  myid = get_core_id();
  write_sswitch_reg_no_ack_clean(myid,0x5,XLB_ORIGIN_ID);
  myid = XLB_ORIGIN_ID;
  /* We are origin for now, everything routes out of us... */
  write_sswitch_reg_clean(myid,0xc,0x0);
  write_sswitch_reg_clean(myid,0xd,0x0);
  
  /* Special cases to bring-up the corner, before we launch into generic bring-up of switches */
  if (position == SWXLB_POS_BOTTOM || position == SWXLB_POS_RIGHT)
  {
    unsigned rid = swallow_xlinkboot_genid(rows-1,cols-1);
    if (!position)
    {
      rid &= ~(1 << SWXLB_LPOS);
    }
    result = xlinkboot_initial_configure(myid, rid, XLB_L_LINKD, XLB_L_LINKB,
      SWXLB_PERIPH_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
    /* TODO: What links will I need? */
    if (result < 0)
    {
      return result;
    }
    /* Now bring up the other core */
    result = xlinkboot_initial_configure(rid,rid ^ ((position) << SWXLB_LPOS), XLB_L_LINKF, XLB_L_LINKG,
      SWXLB_COMPUTE_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
    if (result < 0)
    {
      return result;
    }
  }
  else
  {
    return -SWXLB_INVALID_PERIPHERAL_POS;
  }
  c = cols - 3;
  for (r = rows - 1; r >= 0; r -= 1)
  {
    for ( /* BLANK */ ; c >= 0; c -= 1)
    {
      unsigned srcid, dstid = swallow_xlinkboot_genid(r,c);
      /* Right-most core (layer 1) needs booting over internal-link */
      if (c == (cols-1))
      {
        srcid = swallow_xlinkboot_genid(r,cols-2);
        result = xlinkboot_initial_configure(srcid, dstid, XLB_L_LINKF, XLB_L_LINKG,
          SWXLB_COMPUTE_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
      }
      /* Second-right-most core (layer 0) needs botting from the below core */
      else if (c == (cols-2))
      {
        srcid = swallow_xlinkboot_genid(r+1,c);
        result = xlinkboot_initial_configure(srcid, dstid, XLB_L_LINKA, XLB_L_LINKB,
          SWXLB_COMPUTE_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
      }
      /* All other layer 1 cores are booted from their neighbour over link B */
      else if (c & 1)
      {
        srcid = swallow_xlinkboot_genid(r,c+2);
        result = xlinkboot_initial_configure(srcid, dstid, XLB_L_LINKA, XLB_L_LINKB,
          SWXLB_COMPUTE_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
      }
      /* All other layer 0 cores are booted over internal-link */
      else
      {
        srcid = swallow_xlinkboot_genid(r,c+1);
        result = xlinkboot_initial_configure(srcid, dstid, XLB_L_LINKF, XLB_L_LINKG,
          SWXLB_COMPUTE_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
      }
    }
    /* Update c here to allow initial skip */
    c = cols - 1;
  }
  /* TODO: Bring up other links */
  /* TODO: Apply final routing table */
  /* TODO: Reconfigure links in 5-wire mode */
  /* TODO: Test & bring up any connected peripheral links */
  
  return -SWXLB_GENERIC_FAIL;
} 


