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
  return 0;
}

/**
 * Switch an /already active/ link to 5-wire mode
**/
int xlinkboot_go5(unsigned lid, unsigned local_link, unsigned local_config,
  unsigned rid, unsigned remote_link, unsigned remote_config)
{
  unsigned data, tv;
  timer t;
  DBG(printstrln,"Go 5-wire");
  t :> tv;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  write_sswitch_reg_no_ack_clean(rid,0x80 + remote_link,remote_config | XLB_FIVEWIRE);
  t :> tv;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  write_sswitch_reg_no_ack_clean(lid,0x80 + local_link,local_config | XLB_FIVEWIRE);
  t :> tv;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  return 1;
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
  DBG(printstr,"Half-up link 0x");
  DBG(printhex,link);
  DBG(printstr," on core 0x");
  DBG(printhex,id);
  /* Put the links on a different network to avoid routing garbage */
  write_sswitch_reg_no_ack_clean(id,0x20 + link,XLB_ROUTE_AVOID);
  write_sswitch_reg_no_ack_clean(id,0x80 + link, config | XLB_HELLO);
  t :> tv;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  read_sswitch_reg(id,0x80 + link,data);
  if((data & (XLB_ERR | XLB_CAN_TX)) != XLB_CAN_TX)
  {
    return -XLB_LINK_FAIL;
  }
  DBG(printstrln," ...done!");
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
  DBG(printstrln,"Bringing up additional link between two switches...");
  /* Put the links on a different network to avoid routing garbage */
  write_sswitch_reg_no_ack_clean(lid,0x20 + local_link,XLB_ROUTE_AVOID);
  write_sswitch_reg_no_ack_clean(rid,0x20 + remote_link,XLB_ROUTE_AVOID);
  write_sswitch_reg_no_ack_clean(lid,0x80 + local_link, local_config | XLB_HELLO);
  t :> tv;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  read_sswitch_reg(lid,0x80 + local_link,data);
  if((data & (XLB_ERR | XLB_CAN_TX)) != XLB_CAN_TX)
  {
    return -XLB_LINK_FAIL;
  }
  /* Ask the remote switch to change speed and issue a HELLO back to us */
  write_sswitch_reg_no_ack_clean(rid,0x80 + remote_link, remote_config | XLB_HELLO);
  t :> tv;
  tv += XLB_UP_DELAY;
  t when timerafter(tv) :> void;
  read_sswitch_reg(lid,0x80 + local_link,data);
  if ((data & (XLB_ERR | XLB_CAN_TX | XLB_CAN_RX)) != (XLB_CAN_TX | XLB_CAN_RX))
  {
    return -XLB_LINK_FAIL;
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
  int result, i, pllidx;
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
  result = xlinkboot_link_up(local_id, local_link, XLB_INITIAL_LINK_CONFIG, remote_link, XLB_INITIAL_LINK_CONFIG);
  if (result < 0)
  {
    return result;
  }
  DBG(printstrln,"Link up");
  pllidx = xlinkboot_pll_search(remote_id, PLLs, PLL_len);
  /* Reprogram the PLL, triggering a soft-reset of the core & switch */
  DBG(printstrln,"Programming PLL...");
  write_sswitch_reg_no_ack_clean(0,0x06,pllidx == XLB_PLL_DEFAULT ? PLL_default : PLLs[pllidx].val);
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
  if (pllidx != XLB_PLL_DEFAULT)
  {
    write_sswitch_reg_no_ack_clean(0,0x7,PLLs[pllidx].switch_div-1);
    write_sswitch_reg_no_ack_clean(0,0x8,PLLs[pllidx].ref_div-1);
  }
  DBG(printstr,"Programming direction: ");
  DBG(printhexln,remote_link);
  /* Make the route back to me follow direction "1" */    
  write_sswitch_reg_no_ack_clean(0,0x20 + remote_link,XLB_ROUTE_RETURN << XLB_DIR_SHIFT);
  /* Initial routing tables, everything not for us goes out on direction 0, except bit-15 which returns to origin */
  DBG(printstrln,"Programming route tables");
  write_sswitch_reg_no_ack_clean(0,0xc,0x00000000);
  write_sswitch_reg_no_ack_clean(0,0xd,XLB_ROUTE_RETURN << (7*XLB_DIR_BITS));
  DBG(printstr,"Programming Node ID: ");
  DBG(printhexln,remote_id);
  /* Set up my real node ID */
  write_sswitch_reg_no_ack_clean(0,0x05,remote_id);
  /*result = xlinkboot_go5(local_id, local_link, local_config, remote_id, remote_link, remote_config);
  if (result < 0)
  {
    return result;
  }*/
  /* Ditch the read-back because higher level boot agents may want to meddle with the routing table 
  DBG(printstrln,"Remote routing tables set, reading some data back");
  read_sswitch_reg(remote_id,0x05,data);
  read_sswitch_reg(remote_id,0x06,data);
  DBG(printstr,"Read successfully: ");
  DBG(printhexln,data);
  */
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
