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
int xlinkboot_link_up(unsigned id, unsigned link, unsigned local_config, unsigned remote_config)
{
  unsigned data, tv;
  timer t;
  /* Put the link on a different network to avoid routing garbage */
  write_sswitch_reg_clean(id,0x20 + link,0x000000f0);
  read_sswitch_reg(id,0x80 + link,data);
  while((data & (XLB_ERR | XLB_CAN_TX)) != XLB_CAN_TX)
  {
    if (data & XLB_ERR)
    {
      return -XLB_LINK_FAIL;
    }
    write_sswitch_reg(id,0x80 + link, local_config | XLB_HELLO);
    t :> tv;
    tv += XLB_UP_DELAY;
    t when timerafter(tv) :> void;
    read_sswitch_reg(id,0x80 + link,data);
  }
  /* Ask the remote switch to change speed and issue a HELLO back to us */
  write_sswitch_reg_no_ack(0,0x80 + link, remote_config | XLB_HELLO);
  while((data & (XLB_ERR | XLB_CAN_TX | XLB_CAN_RX)) != (XLB_CAN_TX | XLB_CAN_RX))
  {
    read_sswitch_reg(id,0x80 + link,data);
    if (data & XLB_ERR)
    {
      return -XLB_LINK_FAIL;
    }
  }
  /* Now link is up, put it back into network */
  write_sswitch_reg(id,0x20 + link,0x00000000);
  return 0;
}

