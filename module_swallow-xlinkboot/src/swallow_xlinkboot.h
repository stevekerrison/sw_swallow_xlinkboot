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

/* Error numbers */

#define SWXLB_GENERIC_FAIL              1
#define SWXLB_INVALID_BOARD_DIMENSIONS  2

/* Launch a server thread, receives configuration and then applies it */
void swallow_xlinkboot_server(chanend c_svr);

/* Function call to apply a configuration to an array of swallow boards */
int swallow_xlinkboot(unsigned boards_w, unsigned boards_h, unsigned reset, unsigned PLL[], unsigned PLL_len); 

#endif //SWALLOW_XLINKBOOT_H
