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

#endif //XLINKBOOT_H
