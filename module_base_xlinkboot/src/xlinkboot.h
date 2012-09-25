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
};

#define XLB_GENERIC_FAIL      0x1
#define XLB_PLL_LENGTH        0x2
#define XLB_LINK_FAIL         0x3

#define XLB_L_LINKA           2
#define XLB_L_LINKB           3
#define XLB_L_LINKC           0
#define XLB_L_LINKD           1
#define XLB_L_LINKG           4
#define XLB_L_LINKH           5
#define XLB_L_LINKE           6
#define XLB_L_LINKF           7

/* TODO: PLL-based calculation of what the delay should be */
#define XLB_UP_DELAY          0x1000
#define XLB_HELLO             0x01000000
#define XLB_CAN_TX            0x02000000
#define XLB_CAN_RX            0x04000000
#define XLB_ERR               0x08000000


int xlinkboot_link_up(unsigned id, unsigned link, unsigned local_config, unsigned remote_config);

#endif //XLINKBOOT_H
