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

#include "xlinkboot.h"

/* Configuration bits */

#define COUNT_FROM_BITS(x)        (1 << x)
#define MASK_FROM_BITS(x)         (COUNT_FROM_BITS(x) - 1)
#define SWXLB_PBITS               1
#define SWXLB_PPOS                0
#define SWXLB_LBITS               1
#define SWXLB_LPOS                (SWXLB_PPOS + SWXLB_PBITS)
#define SWXLB_HBITS               6
#define SWXLB_HPOS                (SWXLB_LPOS + SWXLB_LBITS)
#define SWXLB_VBITS               7
#define SWXLB_VPOS                (SWXLB_HPOS + SWXLB_HBITS)
#define SWXLB_XSCOPE_BITS         1
#define SWXLB_XSCOPE_POS          (SWXLB_VPOS + SWXLB_VBITS)
#define SWXLB_CHIPS_W             2
#define SWXLB_CHIPS_H             4
#define SWXLB_CORES_CHIP          2
#define SWXLB_MAX_CORES           COUNT_FROM_BITS(SWXLB_LBITS + SWXLB_HBITS + SWXLB_VBITS)

/* Parameters */

#define SWXLB_LINK_ENABLE_BEGIN   2
#define SWXLB_LINK_ENABLE_END     8

/* Always the bottom-right corner, but are we using the bottom or right link to load the boards? */
#define SWXLB_POS_BOTTOM          0
#define SWXLB_POS_RIGHT           1

#define SWXLB_PERIPH_LINK_CONFIG  0x80004002
#define SWXLB_COMPUTE_LINK_CONFIG 0x80004002


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

struct swallow_xlinkboot_cfg {
  unsigned boards_w;
  unsigned boards_h;
  unsigned do_reset;
  unsigned position;
  struct xlinkboot_pll_t PLL[XLB_PLL_LEN_MAX];
  unsigned PLL_len;
  out port reset_port;
  
};

/* Launch a server thread, receives configuration and then applies it */
void swallow_xlinkboot_server(chanend c_svr, out port rst);

/* Function call to apply a configuration to an array of swallow boards */
int swallow_xlinkboot(unsigned boards_w, unsigned boards_h, unsigned reset,
  unsigned position, struct xlinkboot_pll_t PLL[], unsigned PLL_len, out port rst); 
  
#endif //SWALLOW_XLINKBOOT_H
