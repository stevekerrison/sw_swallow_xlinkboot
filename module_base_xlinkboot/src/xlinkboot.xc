/*
 * xlinkboot - Boot chips over XLink
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
#include "xlinkboot.h"
#include "swallow_comms.h"

/** 
 * Try to safely bring up a link ready to communicate over it.
 * Assumes other end is coreID 0 and will route from src correctly.
**/
int xlinkboot_link_up(unsigned id, unsigned local_link,
  unsigned local_config, unsigned remote_link, unsigned remote_config)
{
  unsigned data, tv;
  timer t;
  /* Put the link on a different network to avoid routing garbage */
  write_sswitch_reg_clean(id,0x20 + local_link,0x000002f0);
  read_sswitch_reg(id,0x80 + local_link,data);
  while((data & (XLB_ERR | XLB_CAN_TX)) != XLB_CAN_TX)
  {
    if (data & XLB_ERR)
    {
      return -XLB_LINK_FAIL;
    }
    write_sswitch_reg(id,0x80 + local_link, local_config | XLB_HELLO);
    t :> tv;
    tv += XLB_UP_DELAY;
    t when timerafter(tv) :> void;
    read_sswitch_reg(id,0x80 + local_link,data);
  }
  /* Ask the remote switch to change speed and issue a HELLO back to us */
  write_sswitch_reg_no_ack(0,0x80 + remote_link, remote_config | XLB_HELLO);
  while((data & (XLB_ERR | XLB_CAN_TX | XLB_CAN_RX)) != (XLB_CAN_TX | XLB_CAN_RX))
  {
    read_sswitch_reg(id,0x80 + local_link,data);
    if (data & XLB_ERR)
    {
      return -XLB_LINK_FAIL;
    }
  }
  return 0;
}

unsigned xlinkboot_pll_search(unsigned id, struct xlinkboot_pll_t PLLs[], unsigned PLL_len)
{
  int i;
  for (i = 0; i < PLL_len; i += 1)
  {
    if (id >= PLLs[i].start && id <= PLLs[i].end && (id & PLLs[i].mask) == id)
    {
      return i;
    }
  }
  return XLB_PLL_DEFAULT;
}

int xlinkboot_initial_configure(unsigned local_id, unsigned remote_id, unsigned local_link, unsigned remote_link,
  unsigned local_config, unsigned remote_config, struct xlinkboot_pll_t PLLs[], unsigned PLL_len, unsigned PLL_default)
{
  int result, i;
  unsigned data;
  /* Make sure no links are considered outgoing (dir 0) at the start */
  for (i = 0; i < XLB_L_LINK_COUNT; i += 1)
  {
    read_sswitch_reg(local_id,0x20 + i,data);
    if ((data & XLB_DIR_MASK) >> XLB_DIR_SHIFT == 0)
    {
      write_sswitch_reg_clean(local_id,0x20 + i,0x00000200);
    }
  }
  result = xlinkboot_link_up(local_id, local_link, local_config, remote_link, remote_config);
  if (result < 0)
  {
    return result;
  }
  result = xlinkboot_pll_search(remote_id, PLLs, PLL_len);
  /* Reprogram the PLL, triggering a soft-reset of the core & switch */
  write_sswitch_reg_no_ack_clean(0,0x06,result == XLB_PLL_DEFAULT ? PLL_default : PLLs[result].val);
  result = xlinkboot_link_up(local_id, local_link, local_config, remote_link, remote_config);
  if (result < 0)
  {
    return result;
  }
  /* Now set the ref and switch clock dividers (no reset required) */
  if (result != XLB_PLL_DEFAULT)
  {
    write_sswitch_reg_no_ack_clean(0,0x7,PLLs[result].switch_div);
    write_sswitch_reg_no_ack_clean(0,0x8,PLLs[result].ref_div);
  }
  /* Make the route back to me follow direction "1" and deeper into the compute array be "0" (default) */    
  write_sswitch_reg_no_ack_clean(0,0x20 + remote_link,0x00000100);
  write_sswitch_reg_clean(0,0x20 + local_link,0x00000000);
  /* Initial routing tables, everything not for us goes out on direction 0, except bit-15 which returns to origin */
  write_sswitch_reg_no_ack_clean(0,0xc,0x00000000);
  write_sswitch_reg_no_ack_clean(0,0xd,0x10000000);
  /* Set up my real node ID */
  write_sswitch_reg_no_ack_clean(0,0x05,remote_id);
  return remote_id;
}

