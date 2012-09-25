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
 
#ifndef XLINKBOOT_H
#define XLINKBOOT_H

/* Help program groups of chips with PLL values */
struct xlinkboot_pll_t {
  unsigned mask;
  unsigned start;
  unsigned end;
  unsigned val;
  unsigned switch_div;
  unsigned ref_div;
};

#define XLB_GENERIC_FAIL      0x1
#define XLB_PLL_LENGTH        0x2
#define XLB_LINK_FAIL         0x3

/* Sensibly labelled link IDs... LOL */
#define XLB_L_LINKA           2
#define XLB_L_LINKB           3
#define XLB_L_LINKC           0
#define XLB_L_LINKD           1
#define XLB_L_LINKE           6
#define XLB_L_LINKF           7
#define XLB_L_LINKG           4
#define XLB_L_LINKH           5
#define XLB_L_LINK_COUNT      8

/**
 * Use the top bit exclusively for routing back to origin.
 * The LSB is just to distinguish ourselves from XScope and has no real significance
**/
#define XLB_ORIGIN_ID         0x8001

#define XLB_PLL_DEFAULT       -1
#define XLB_PLL_LEN_MAX       128

/* TODO: PLL-based calculation of what the delay should be */
#define XLB_UP_DELAY          0x1000
#define XLB_HELLO             0x01000000
#define XLB_CAN_TX            0x02000000
#define XLB_CAN_RX            0x04000000
#define XLB_ERR               0x08000000

/* Dir/net masks */
#define XLB_DIR_MASK          0x00000f00
#define XLB_DIR_SHIFT         8
#define XLB_NET_MASK          0x000000f0
#define XLB_NET_SHIFT         4

unsigned xlinkboot_pll_search(unsigned id, struct xlinkboot_pll_t PLLs[], unsigned PLL_len);

int xlinkboot_link_up(unsigned id, unsigned local_link,
  unsigned local_config, unsigned remote_link, unsigned remote_config);
  
int xlinkboot_initial_configure(unsigned local_id, unsigned remote_id, unsigned local_link, unsigned remote_link,
  unsigned local_config, unsigned remote_config, struct xlinkboot_pll_t PLLs[], unsigned PLL_len, unsigned PLL_default);

#endif //XLINKBOOT_H
