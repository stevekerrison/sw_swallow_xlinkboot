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
#include <print.h>
#include "xlinkboot.h"
#include "swallow_comms.h"

/**
 * Disable all links, useful prior to reset, for example
**/
unsigned xlinkboot_disable_links(unsigned id)
{
  for (int i = 0; i < 8; i += 1)
  {
    write_sswitch_reg_no_ack_clean(id,0x80 + i, 0);
  }
}

/** 
 * Try to safely bring up a link ready to communicate over it.
 * Assumes other end is coreID 0 and will route from src correctly.
**/
int xlinkboot_link_up(unsigned id, unsigned local_link,
  unsigned local_config, unsigned remote_link, unsigned remote_config)
{
  unsigned data, tv;
  timer t;
  DBG(printstrln,"Enable link");
  /* Put the link on a different network to avoid routing garbage */
  //write_sswitch_reg_no_ack_clean(id,0x20 + local_link,XLB_ROUTE_AVOID);
  //write_sswitch_reg_no_ack_clean(id,0x80 + local_link,0x80800000);
  write_sswitch_reg_no_ack_clean(id,0x80 + local_link,local_config);
  /* Now put us on the outbound route so we can talk to node 0 */
  write_sswitch_reg_no_ack_clean(id,0x20 + local_link,0x00000000);
  read_sswitch_reg(id,0x80 + local_link,data);
  DBG(printhexln,data);
  DBG(printstrln,"Asking for credit...");
  write_sswitch_reg_no_ack_clean(id,0x80 + local_link,local_config | XLB_HELLO);
  t :> tv;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  read_sswitch_reg(id,0x80 + local_link,data);
  if((data & (XLB_ERR | XLB_CAN_TX)) != XLB_CAN_TX)
  {
    return -XLB_LINK_FAIL;
  }
  DBG(printstrln,"GOT CREDIT, CAN TX");
  /* Ask the remote switch to change speed and issue a HELLO back to us */
  write_sswitch_reg_no_ack_clean(0,0x80 + remote_link, remote_config);
  t :> tv;
  tv += XLB_UP_DELAY*10;
  t when timerafter(tv) :> void;
  write_sswitch_reg_no_ack_clean(0,0x80 + remote_link, remote_config | XLB_HELLO);
  t :> tv;
  tv += XLB_UP_DELAY*10;
  t when timerafter(tv) :> void;
  read_sswitch_reg(id,0x80 + local_link,data);
  if((data & (XLB_ERR | XLB_CAN_TX | XLB_CAN_RX)) != (XLB_CAN_TX | XLB_CAN_RX))
  {
    return -XLB_LINK_FAIL;
  }
  /*while((data & (XLB_ERR | XLB_CAN_TX | XLB_CAN_RX)) != (XLB_CAN_TX | XLB_CAN_RX))
  {
    if (data & XLB_ERR)
    {
      return -XLB_LINK_FAIL;
    }
    write_sswitch_reg_no_ack_clean(0,0x80 + remote_link, remote_config | XLB_HELLO);
    t :> tv;
    tv += XLB_UP_DELAY*10;
    t when timerafter(tv) :> void;
    read_sswitch_reg(id,0x80 + local_link,data);
  }*/
  DBG(printstrln,"CAN RX/TX!");
  return 0;
}

int xlinkboot_half_link_up(unsigned id, unsigned link, unsigned config)
{
  unsigned data = 0, tv;
  timer t;
  /* Put the links on a different network to avoid routing garbage */
  write_sswitch_reg_no_ack_clean(id,0x20 + link,XLB_ROUTE_AVOID);
  while((data & (XLB_ERR | XLB_CAN_TX)) != XLB_CAN_TX)
  {
    if (data & XLB_ERR)
    {
      return -XLB_LINK_FAIL;
    }
    write_sswitch_reg_no_ack_clean(id,0x80 + link, config | XLB_HELLO);
    t :> tv;
    tv += XLB_UP_DELAY;
    t when timerafter(tv) :> void;
    read_sswitch_reg(id,0x80 + link,data);
  }
  return 0;
}

/** 
 * Bring up a secondary link on a pair of already reachable switches
**/
int xlinkboot_secondary_link_up(unsigned lid, unsigned local_link,
  unsigned local_config, unsigned rid, unsigned remote_link, unsigned remote_config)
{
  unsigned data, tv;
  timer t;
  /* Put the links on a different network to avoid routing garbage */
  write_sswitch_reg_no_ack_clean(lid,0x20 + local_link,XLB_ROUTE_AVOID);
  write_sswitch_reg_no_ack_clean(rid,0x20 + remote_link,XLB_ROUTE_AVOID);
  read_sswitch_reg(lid,0x80 + local_link,data);
  //printstrln("Issuing HELLO");
  while((data & (XLB_ERR | XLB_CAN_TX)) != XLB_CAN_TX)
  {
    if (data & XLB_ERR)
    {
      return -XLB_LINK_FAIL;
    }
    write_sswitch_reg_no_ack_clean(lid,0x80 + local_link, local_config | XLB_HELLO);
    t :> tv;
    tv += XLB_UP_DELAY;
    t when timerafter(tv) :> void;
    read_sswitch_reg(lid,0x80 + local_link,data);
  }
  /* Ask the remote switch to change speed and issue a HELLO back to us */
  write_sswitch_reg_no_ack_clean(rid,0x80 + remote_link, remote_config | XLB_HELLO);
  while((data & (XLB_ERR | XLB_CAN_TX | XLB_CAN_RX)) != (XLB_CAN_TX | XLB_CAN_RX))
  {
    read_sswitch_reg(lid,0x80 + local_link,data);
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
  unsigned data, tv;
  timer t;
  /* Make sure no links are considered outgoing (dir 0) at the start */
  for (i = 0; i < XLB_L_LINK_COUNT; i += 1)
  {
    read_sswitch_reg(local_id,0x20 + i,data);
    if ((data & XLB_DIR_MASK) >> XLB_DIR_SHIFT == 0)
    {
      write_sswitch_reg_clean(local_id,0x20 + i,XLB_ROUTE_AVOID);
    }
  }
  DBG(printstrln,"Initialising link");
  result = xlinkboot_link_up(local_id, local_link, local_config, remote_link, remote_config);
  if (result < 0)
  {
    return result;
  }
  DBG(printstrln,"Link up");
  #if 1 //Disable PLL stuff for now...
  result = xlinkboot_pll_search(remote_id, PLLs, PLL_len);
  /* Reprogram the PLL, triggering a soft-reset of the core & switch */
  DBG(printstrln,"Programming PLL...");
  write_sswitch_reg_no_ack_clean(0,0x06,result == XLB_PLL_DEFAULT ? PLL_default : PLLs[result].val);
  t :> tv;
  tv += XLB_RST_INIT;
  t when timerafter(tv) :> void;
  DBG(printstrln,"Reinitialising link...");
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
  #endif
  DBG(printstrln,"Programming direction");
  DBG(printhexln,remote_link);
  /* Make the route back to me follow direction "1" */    
  write_sswitch_reg_no_ack_clean(0,0x20 + remote_link,XLB_ROUTE_RETURN << XLB_DIR_SHIFT);
  /* Initial routing tables, everything not for us goes out on direction 0, except bit-15 which returns to origin */
  DBG(printstrln,"Programming route tables");
  write_sswitch_reg_no_ack_clean(0,0xc,0x00000000);
  write_sswitch_reg_no_ack_clean(0,0xd,XLB_ROUTE_RETURN << (7*XLB_DIR_BITS));
  DBG(printstrln,"Programming Node ID");
  /* Set up my real node ID */
  write_sswitch_reg_no_ack_clean(0,0x05,remote_id);
  DBG(printstrln,"Remote routing tables set, reading some data back");
  read_sswitch_reg(remote_id,0x05,data);
  read_sswitch_reg(remote_id,0x06,data);
  return remote_id;
}

void xlinkboot_set5(unsigned local_id, unsigned remote_id, unsigned local_link, unsigned remote_link)
{
  unsigned ldata,rdata;
  read_sswitch_reg(local_id,0x80 + local_link,ldata);
  read_sswitch_reg(remote_id,0x80 + remote_link,rdata);
  if (!(ldata & XLB_FIVEWIRE))
  {
    rdata |= XLB_FIVEWIRE;
    write_sswitch_reg_no_ack_clean(remote_id,0x80 + remote_link,rdata);
    ldata |= XLB_FIVEWIRE;
    write_sswitch_reg_no_ack_clean(local_id,0x80 + local_link,ldata);
  }
  return;
}
