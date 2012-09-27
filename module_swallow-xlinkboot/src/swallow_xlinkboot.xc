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
#include <print.h>
#include "swallow_xlinkboot.h"
#include "swallow_comms.h"

static unsigned swallow_xlinkboot_genid(unsigned row, unsigned col)
{
  return (row << SWXLB_VPOS) | (col << SWXLB_LPOS);
}

/* Launch a server thread, receives configuration and then applies it */
void swallow_xlinkboot_server(chanend c_svr, out port rst)
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
    ret = swallow_xlinkboot(boards_w,boards_h,reset,position,PLL,PLL_len,rst);
    c_svr <: ret;
  }
  return;
}

/* We now reprogram the switch to enable all desired links for the final network and do proper routing */
static int swallow_xlinkboot_route_configure(unsigned r, unsigned c, unsigned rows, unsigned cols, unsigned link_config)
{
  unsigned id = swallow_xlinkboot_genid(r,c);
  unsigned dir, layer = (id >> SWXLB_LPOS) & MASK_FROM_BITS(SWXLB_LBITS);
  int i;
  for (i = SWXLB_LINK_ENABLE_BEGIN; i < SWXLB_LINK_ENABLE_END; i += 1)
  {
    switch (i)
    {
      default:
        //Internal links 
        dir = layer ? SWXLB_DIR_AWAY : SWXLB_DIR_TOWARDS;
        break;
      case 2:
        //Left or upward link
        dir = layer ? SWXLB_DIR_LEFT : SWXLB_DIR_UP;
        break;
      case 3:
        //Right or downward link
        dir = layer ? SWXLB_DIR_RIGHT : SWXLB_DIR_DOWN;
        break;
    }
    if ((i == XLB_L_LINKA && (r == 0 || c == 0)) ||
      (i == XLB_L_LINKB && (r == rows-1 || c == cols-1)))
    {
      /* Skip over links that are peripheral links for now. TODO? */
      continue;
    }
    else
    {
      write_sswitch_reg_no_ack_clean(id,0x20 + i,dir << 8);
      write_sswitch_reg_no_ack_clean(id,0x20 + i,link_config | XLB_HELLO);
    }
  }
  {
    unsigned row = id >> SWXLB_VPOS, col = (id >> SWXLB_HPOS) & MASK_FROM_BITS(SWXLB_HBITS),
      layer = (id >> SWXLB_LPOS) & MASK_FROM_BITS(SWXLB_LBITS), i;
    unsigned ldirbits = layer ? SWXLB_DIR_AWAY : SWXLB_DIR_TOWARDS;
    unsigned vdirbits = 0, hdirbits = 0, xscopedirbits = 0, pdirbit = 0;
    unsigned dirbits[2];
    if (layer)
    {
      pdirbit = (row == 0) ? SWXLB_DIR_LEFT : SWXLB_DIR_RIGHT;
      xscopedirbits = row == 1 ? SWXLB_DIR_LEFT : SWXLB_DIR_AWAY;
      for (i = 0; i < SWXLB_VBITS; i++)
      {
        vdirbits <<= XLB_DIR_BITS;
        vdirbits |= SWXLB_DIR_AWAY;
      }
      for (i = SWXLB_HBITS; i != 0; i--)
      {
        hdirbits <<= XLB_DIR_BITS;
        hdirbits |= (((col >> i) & 1) ? SWXLB_DIR_LEFT : SWXLB_DIR_RIGHT);
      }
    }
    else
    {
      pdirbit = (col == 0) ? SWXLB_DIR_UP : SWXLB_DIR_DOWN;
      xscopedirbits = ((row == 0) ? SWXLB_DIR_DOWN : ((row == 1) ? SWXLB_DIR_AWAY : SWXLB_DIR_UP));
      for (i = 0; i < SWXLB_HBITS; i++)
      {
        hdirbits <<= XLB_DIR_BITS;
        hdirbits |= SWXLB_DIR_TOWARDS;
      }
      for (i = SWXLB_VBITS; i != 0; i--)
      {
        vdirbits <<= XLB_DIR_BITS;
        vdirbits |= ((row & 1) ? SWXLB_DIR_UP : SWXLB_DIR_DOWN);
      }
    }
    dirbits[0] = (((hdirbits << XLB_DIR_BITS) | ldirbits) << XLB_DIR_BITS) | pdirbit;
    dirbits[1] = (xscopedirbits << (XLB_DIR_BITS * SWXLB_VBITS)) | vdirbits;
    write_sswitch_reg_no_ack_clean(id,0xc,dirbits[0]);
    write_sswitch_reg_no_ack_clean(id,0xd,dirbits[1]);
  }
  return 0;
}

/* Reconfigure all links in 5-wire mode */
static void swallow_xlinkboot_go5(unsigned rows, unsigned cols, unsigned position)
{
  unsigned r,c,
    lid = swallow_xlinkboot_genid(rows-1,cols-2+position) | 1,
    rid = swallow_xlinkboot_genid(rows-1,cols-2+position);
  xlinkboot_set5(lid,rid,XLB_L_LINKB,XLB_L_LINKB);
  lid = rid;
  rid = swallow_xlinkboot_genid(rows-1,cols-2+(!position));
  xlinkboot_set5(lid,rid,XLB_L_LINKF,XLB_L_LINKG);
  xlinkboot_set5(lid,rid,XLB_L_LINKG,XLB_L_LINKF);
  xlinkboot_set5(lid,rid,XLB_L_LINKE,XLB_L_LINKH);
  xlinkboot_set5(lid,rid,XLB_L_LINKH,XLB_L_LINKE);
  c = cols - 3;
  rid = swallow_xlinkboot_genid(rows-1,cols-1);
  for (r = rows - 1; r >= 0; r -= 1)
  {
    for ( /* BLANK */ ; c >= 0; c -= 1)
    {
      lid = swallow_xlinkboot_genid(r,c);
      if (c == cols - 1)
      {
        xlinkboot_set5(lid,rid,XLB_L_LINKF,XLB_L_LINKG);
        xlinkboot_set5(lid,rid,XLB_L_LINKG,XLB_L_LINKF);
        xlinkboot_set5(lid,rid,XLB_L_LINKE,XLB_L_LINKH);
        xlinkboot_set5(lid,rid,XLB_L_LINKH,XLB_L_LINKE);
      }
      else if (c & 1)
      {
        xlinkboot_set5(lid,rid,XLB_L_LINKA,XLB_L_LINKB);
      }
      else
      {
        xlinkboot_set5(lid,rid,XLB_L_LINKF,XLB_L_LINKG);
        xlinkboot_set5(lid,rid,XLB_L_LINKG,XLB_L_LINKF);
        xlinkboot_set5(lid,rid,XLB_L_LINKE,XLB_L_LINKH);
        xlinkboot_set5(lid,rid,XLB_L_LINKH,XLB_L_LINKE);
      }
    }
    c = cols - 1;
  }
  return;
}

static void swallow_xlinkboot_reset(out port rst)
{
  timer t;
  unsigned tv;
  rst <: 0;
  t :> tv;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  rst <: 1;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  return;
}

/* Function call to apply a configuration to an array of swallow boards */
int swallow_xlinkboot(unsigned boards_w, unsigned boards_h, unsigned reset, unsigned position,
  struct xlinkboot_pll_t PLL[], unsigned PLL_len, out port rst)
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
  swallow_xlinkboot_reset(rst);
  /* Make my ID something we can pre-boot the compute nodes from */
  myid = get_core_id();
  write_sswitch_reg_no_ack_clean(myid,0x5,XLB_ORIGIN_ID);
  myid = XLB_ORIGIN_ID;
  /* We are origin for now, everything routes out of us... */
  write_sswitch_reg_clean(myid,0xc,0x0);
  write_sswitch_reg_clean(myid,0xd,0x0);
  
  printstrln("Origin ready to start bringing up links");
  
  /* Special cases to bring-up the corner, before we launch into generic bring-up of switches */
  if (position == SWXLB_POS_BOTTOM || position == SWXLB_POS_RIGHT)
  {
    unsigned rid = swallow_xlinkboot_genid(rows-1,cols-1);
    if (!position)
    {
      rid &= ~(1 << SWXLB_LPOS);
    }
    printstr("Init configure of core 0x");
    printhexln(rid);
    result = xlinkboot_initial_configure(myid, rid, XLB_L_LINKB, XLB_L_LINKB,
      SWXLB_PERIPH_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
    printstrln("Done init configure");
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
  printstrln("Do init configure on rest of grid");
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
      xlinkboot_other_links(dstid,SWXLB_LINK_ENABLE_BEGIN,SWXLB_LINK_ENABLE_END,SWXLB_COMPUTE_LINK_CONFIG);
    }
    /* Update c here to allow initial skip */
    c = cols - 1;
  }
  for (r = 0; r < rows; r += 1)
  {
    /* Neighbour's ID */
    unsigned nid = swallow_xlinkboot_genid(r,cols-2);
    /* When we start a row, make sure the vertical entry point to the row then switches packets horizontally */
    write_sswitch_reg_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
    write_sswitch_reg_clean(nid,0x20 + XLB_L_LINKF, 0x00000100);
    for (c = 0; c < cols; c += 1)
    {
      /* Tweaks routes to communicate with cores on the "0" layer as we move horizontally along the "1" plane */
      if ((c & 1) == 0 && c + 2 < cols)
      {
        nid = swallow_xlinkboot_genid(r,c+1);
        write_sswitch_reg_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
        write_sswitch_reg_clean(nid,0x20 + XLB_L_LINKF, 0x00000100);
      }
      swallow_xlinkboot_route_configure(r,c,rows,cols,SWXLB_COMPUTE_LINK_CONFIG);
    }
  }
  /* Now my ID is wrong! So I must give myself a new one - our compute grid address with the P-bit set */
  write_sswitch_reg_no_ack_clean(myid,0x5,swallow_xlinkboot_genid(rows-1,cols-2+position) | 1);
  /* 5-wire mode please! */
  swallow_xlinkboot_go5(rows,cols,position);
  /* TODO: Test & bring up any connected peripheral links */
  
  return -SWXLB_GENERIC_FAIL;
}

