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
 
#ifndef SWALLOW_XLINKBOOT_H
#define SWALLOW_XLINKBOOT_H

#include "swallow_comms.h"
#include "xlinkboot.h"

/* Parameters */

#define SWXLB_LINK_ENABLE_BEGIN   2
#define SWXLB_LINK_ENABLE_END     8

/* Always the bottom-right corner, but are we using the bottom or right link to load the boards? */
#define SWXLB_POS_BOTTOM          0
#define SWXLB_POS_RIGHT           1

#define SWXLB_PERIPH_LINK_CONFIG  0x80004002
#define SWXLB_COMPUTE_LINK_CONFIG 0x80002001
#define SWXLB_L2_LINK_CONFIG      0x80002001


#define SWXLB_DIR_TOWARDS         0
#define SWXLB_DIR_AWAY            1
#define SWXLB_DIR_LEFT            2
#define SWXLB_DIR_RIGHT           3
#define SWXLB_DIR_UP              4
#define SWXLB_DIR_DOWN            5

/* 500MHz from a 25MHz oscillator */
#define SWXLB_PLL_DEFAULT         0x00002700

/* Error numbers */

#define SWXLB_GENERIC_FAIL              0x10000
#define SWXLB_INVALID_BOARD_DIMENSIONS  0x20000
#define SWXLB_INVALID_PERIPHERAL_POS    0x30000

#define SWXLB_DIVIDER_DEFAULT   0xff

/* Macros for many-core init */
#define PERIPHERALS_STEP  2 //Don't change me
#define PERIPHERALS_TOP_INIT(num) \
    par (unsigned i = 0; i < num * PERIPHERALS_STEP; i += 2) {    \
      on tile[i]: peripheral_link_up();                           \
    }

struct swallow_xlinkboot_cfg {
  unsigned boards_w;
  unsigned boards_h;
  unsigned do_reset;
  unsigned position;
  struct xlinkboot_pll_t PLL[XLB_PLL_LEN_MAX];
  unsigned PLL_len;
  out port reset_port;
  
};

/*
 * Brings up a link on an already configured system, to talk to a peripheral
 * board.
 */
int peripheral_link_up();

/*
 *  Issue power saving measures to all cores (slow down their clocks when idle)
 */
int swallow_xlinkboot_powersave_remote();

/*
 *  Issue power saving measures to the local core, optionally only if no other
 *  threads appear allocated.
 *  
 *  If permanent = 1, clock divider will be enabled regardless of thread
 *  activity, if 0, divider will be enabled only when all threads idle/waiting.
 *  If only_unused = 1, divider will be configured only if no other threads
 *  appear to be allocated on the core. This MAY RACE and steal thread
 *  resources, possibly causing exception or false positive in some situations.
 */
int swallow_xlinkboot_powersave_local(unsigned divider, unsigned permanent,
  unsigned only_unused);

/* Launch a server thread, receives configuration and then applies it */
void swallow_xlinkboot_server(chanend c_svr, out port rst);

/* Function call to apply a configuration to an array of swallow boards */
int swallow_xlinkboot(unsigned boards_w, unsigned boards_h, unsigned reset,
  unsigned position, struct xlinkboot_pll_t PLL[], unsigned PLL_len, out port rst); 

/* Make sure xscope will work... */  
void swallow_xlinkboot_xscope_init(void);
  
#endif //SWALLOW_XLINKBOOT_H
