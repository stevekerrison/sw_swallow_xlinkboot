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

#include <platform.h>
#include <print.h>
#include "swallow_xlinkboot.h"
#include "swallow_comms.h"

static unsigned swallow_xlinkboot_genid(unsigned row, unsigned col)
{
  return (row << SWXLB_VPOS) | (col << SWXLB_LPOS);
}

/**
 * We use this to send the kissoflife program to a core at an appropriate moment to signify that
 * it's ready to receive a full program.
**/
static void bootone(unsigned id)
{
  unsigned ce = getChanend(0x2), size, crc = 0xd15ab1e, loc, i, word;
  DBG(printstrln,"Light 'em up");
  asm("ldap r11,kissoflife\n"
    "mov %0,r11\n"
    "ldap r11,kissoflife_end\n"
    "sub %0,r11,%0\n"
    "shr %0,%0,2":"=r"(size):);
  asm("ldap r11,kissoflife\n"
    "mov %0,r11":"=r"(loc)::"r11");
  asm("setd res[%0],%1"::"r"(ce),"r"((id << 16) | 0x2));
  asm("out res[%0],%0\n"
    "out res[%0],%1"::"r"(ce),"r"(size));
  for (i = loc; i < loc + (size*4); i += 4)
  {
    asm("ldw %0,%1[0]\n"
      "out res[%2],%0\n":"=r"(word):"r"(i),"r"(ce));
  }
  asm("out res[%0],%1\n"::"r"(ce),"r"(crc));
  asm("outct res[%0],1\n"
    "chkct res[%0],1\n"::"r"(ce));
  freeChanend(ce);
  DBG(printstrln,"Done");
}

/* Make the remaining 2-wire links 5-wire links */
static void gofive(unsigned rows, unsigned cols)
{
  unsigned lid, rid, result;
  /* First do the vertical links */
  for (int c = 0; c < cols; c += 2)
  {
    for (int r = 1; r < rows; r += 1)
    {
      rid = swallow_xlinkboot_genid(r-1,c);
      lid = swallow_xlinkboot_genid(r,c);
      xlinkboot_go5(lid,XLB_L_LINKA,SWXLB_COMPUTE_LINK_CONFIG,rid,XLB_L_LINKB,SWXLB_PERIPH_LINK_CONFIG);
    }
  }
  /* Now do the horizontal links */
  for (int r = 0; r < rows; r += 1)
  {
    for (int c = 3; c < cols; c += 2)
    {
      rid = swallow_xlinkboot_genid(r,c-2);
      lid = swallow_xlinkboot_genid(r,c);
      xlinkboot_go5(lid,XLB_L_LINKA,SWXLB_COMPUTE_LINK_CONFIG,rid,XLB_L_LINKB,SWXLB_PERIPH_LINK_CONFIG);
    }
  }
  return;
}

#ifdef DEMO_MODE
/**
 * This is not very useful except as a demo, to show that all the cores can be booted and flash LEDs
 * You can't do very much with the grid after running this, however
**/
static void bootall(unsigned rows, unsigned cols)
{
  unsigned ce = getChanend(0x2), r, c, id, size, crc = 0xd15ab1e, loc, i, word;
  asm("ldap r11,testprog\n"
    "mov %0,r11\n"
    "ldap r11,testprog_end\n"
    "sub %0,r11,%0\n"
    "shr %0,%0,2":"=r"(size):);
  for (r = 0; r < rows; r += 1)
  {
    for (c = 0; c < cols; c += 1)
    {
      asm("ldap r11,testprog\n"
        "mov %0,r11":"=r"(loc)::"r11");
      id = swallow_xlinkboot_genid(r,c);
      //printhex(id);
      asm("setd res[%0],%1"::"r"(ce),"r"((id << 16) | 0x2));
      asm("out res[%0],%0\n"
        "out res[%0],%1"::"r"(ce),"r"(size));
      for (i = loc; i < loc + (size*4); i += 4)
      {
        asm("ldw %0,%1[0]\n"
          "out res[%2],%0\n":"=r"(word):"r"(i),"r"(ce));
        //printchar('.');
      }
      //printcharln('\0');
      asm("out res[%0],%1\n"::"r"(ce),"r"(crc));
      asm("outct res[%0],1\n"
        "chkct res[%0],1\n"::"r"(ce));
    }
  }
  freeChanend(ce);
}
#endif

/* Launch a server thread, receives configuration and then applies it */
void swallow_xlinkboot_server(chanend c_svr, out port rst)
{
  unsigned boards_w, boards_h, reset, PLL_len, position, ret, i;
  struct xlinkboot_pll_t PLL[XLB_PLL_LEN_MAX];
  while(1)
  {
    c_svr :> boards_w;
    c_svr :> boards_h;
    c_svr :> reset;
    c_svr :> position;
    c_svr :> PLL_len;
    for (i = 0; i < PLL_len; i += 1)
    {
      c_svr :> PLL[i];
    }
    if (i > XLB_PLL_LEN_MAX)
    {
      c_svr <: -XLB_PLL_LENGTH;
    }
    ret = swallow_xlinkboot(boards_w,boards_h,reset,position,PLL,PLL_len,rst);
    c_svr <: ret;
  }
  return;
}

/* We now reprogram the switch to enable all desired links for the final network and do proper routing */
static int swallow_xlinkboot_route_configure(unsigned r, unsigned c, unsigned rows, unsigned cols, unsigned link_config,
  unsigned bootpos)
{
  unsigned id = swallow_xlinkboot_genid(r,c);
  unsigned dir, layer = (id >> SWXLB_LPOS) & MASK_FROM_BITS(SWXLB_LBITS);
  int result;
  int i;
  DBG(printstr,"Doing *full* route config for 0x");
  DBG(printhexln,id);
  /* The core above us rebooted earlier, so doesn't think we have credit. Say HELLO again */
  if (r > 0 && c != 1)
  {
    result = xlinkboot_half_link_up(id, XLB_L_LINKA, SWXLB_COMPUTE_LINK_CONFIG);
    if (result < 0)
    {
      return result;
    }
  }
  for (i = SWXLB_LINK_ENABLE_BEGIN; i < SWXLB_LINK_ENABLE_END; i += 1)
  {
    switch (i)
    {
      default:
        //Internal links 
        dir = layer ? SWXLB_DIR_AWAY : SWXLB_DIR_TOWARDS;
        break;
      case 2:
        //Left or upward link
        dir = layer ? SWXLB_DIR_LEFT : SWXLB_DIR_UP;
        break;
      case 3:
        //Right or downward link
        dir = layer ? SWXLB_DIR_RIGHT : SWXLB_DIR_DOWN;
        break;
    }
    //Always write the direction, regardless of whether we're going to use the link */
    write_sswitch_reg_no_ack_clean(id,0x20 + i,dir << XLB_DIR_SHIFT);
  }
  {
    unsigned row = id >> SWXLB_VPOS, col = (id >> SWXLB_HPOS) & MASK_FROM_BITS(SWXLB_HBITS),
      layer = (id >> SWXLB_LPOS) & MASK_FROM_BITS(SWXLB_LBITS), i;
    unsigned ldirbits = layer ? SWXLB_DIR_AWAY : SWXLB_DIR_TOWARDS;
    unsigned vdirbits = 0, hdirbits = 0, xscopedirbits = 0, pdirbit = 0;
    unsigned dirbits[2];
    if (layer)
    {
      pdirbit = (col == 0) ? SWXLB_DIR_LEFT : SWXLB_DIR_RIGHT;
      //xscopedirbits = row == 1 ? SWXLB_DIR_LEFT : SWXLB_DIR_AWAY;
      if (row == rows - 1)
        if (col == cols/2 - 1 && bootpos != SWXLB_POS_RIGHT)
          xscopedirbits = SWXLB_DIR_AWAY;
        else
          xscopedirbits = SWXLB_DIR_RIGHT;
      else
        xscopedirbits = SWXLB_DIR_AWAY;
      for (i = 0; i < SWXLB_VBITS; i++)
      {
        vdirbits <<= XLB_DIR_BITS;
        vdirbits |= SWXLB_DIR_AWAY;
      }
      for (i = SWXLB_HBITS; i != 0; i--)
      {
        hdirbits <<= XLB_DIR_BITS;
        hdirbits |= (((col >> (i-1)) & 1) ? SWXLB_DIR_LEFT : SWXLB_DIR_RIGHT);
      }
    }
    else
    {
      pdirbit = (row == 0) ? SWXLB_DIR_UP : SWXLB_DIR_DOWN;
      if (row != rows - 1)
        xscopedirbits = SWXLB_DIR_DOWN;
      else if (bootpos == SWXLB_POS_BOTTOM && col == cols/2 - 1)
        xscopedirbits = SWXLB_DIR_DOWN;
      else
        xscopedirbits = SWXLB_DIR_TOWARDS;
      for (i = 0; i < SWXLB_HBITS; i++)
      {
        hdirbits <<= XLB_DIR_BITS;
        hdirbits |= SWXLB_DIR_TOWARDS;
      }
      for (i = SWXLB_VBITS; i != 0; i--)
      {
        vdirbits <<= XLB_DIR_BITS;
        vdirbits |= (((row >> (i-1)) & 1) ? SWXLB_DIR_UP : SWXLB_DIR_DOWN);
      }
    }
    dirbits[0] = (((hdirbits << XLB_DIR_BITS) | ldirbits) << XLB_DIR_BITS) | pdirbit;
    dirbits[1] = (xscopedirbits << (XLB_DIR_BITS * SWXLB_VBITS)) | vdirbits;
    write_sswitch_reg_no_ack_clean(id,0xc,dirbits[0]);
    write_sswitch_reg_no_ack_clean(id,0xd,dirbits[1]);
  }
  DBG(printstrln,"Done!");
  return 0;
}

static void swallow_xlinkboot_reset(out port rst)
{
  timer t;
  unsigned tv;
  t :> tv;
  rst <: 1;
  tv += XLB_RST_INIT;
  t when timerafter(tv) :> void;
  rst <: 0;
  tv += XLB_RST_PULSE;
  t when timerafter(tv) :> void;
  rst <: 1;
  tv += XLB_RST_INIT;
  t when timerafter(tv) :> void;
  return;
}

static int swallow_xlinkboot_internal_links(unsigned fside, unsigned gside)
{
  unsigned i;
  int result;
  static unsigned flinks[] = {XLB_L_LINKG,XLB_L_LINKE,XLB_L_LINKH},
    glinks[] = {XLB_L_LINKF,XLB_L_LINKH,XLB_L_LINKE};
  for (i = 0; i < 3; i += 1)
  {
    result = xlinkboot_secondary_link_up(fside, flinks[i],SWXLB_L2_LINK_CONFIG,
      gside, glinks[i], SWXLB_L2_LINK_CONFIG);
    if (result < 0)
      return result;
    result = xlinkboot_go5(fside, flinks[i],SWXLB_L2_LINK_CONFIG,
      gside, glinks[i], SWXLB_L2_LINK_CONFIG);
    if (result < 0)
      return result;
  }
  return 0;
}

void swallow_xlinkboot_xscope_init(void)
{
  unsigned data, tv;
  timer t;
  /* Routing table is probably wrong */
  write_sswitch_reg_no_ack_clean(SWXLB_BOOT_ID,0xd,0x00000000);
  write_sswitch_reg_no_ack_clean(SWXLB_BOOT_ID,0xc,0x0000000f);
  /*for (int i = 0; i < 8; i += 1)
  {
    read_sswitch_reg(SWXLB_BOOT_ID,0x20 + i,data);
    if ((data >> 8) & 0xf == 0xf)
    {
      read_sswitch_reg(SWXLB_BOOT_ID,0x80 + i,data);
      write_sswitch_reg_no_ack_clean(SWXLB_BOOT_ID,0x80 + i, data | XLB_HELLO)
    }
  }*/
  return;
}


/* Function call to apply a configuration to an array of swallow boards */
int swallow_xlinkboot(unsigned boards_w, unsigned boards_h, unsigned reset, unsigned position,
  struct xlinkboot_pll_t PLL[], unsigned PLL_len, out port rst)
{
  unsigned cols = boards_w * SWXLB_CHIPS_W * SWXLB_CORES_CHIP,
    rows = boards_h * SWXLB_CHIPS_H,
    total_cores = cols*rows,
    rowstride = COUNT_FROM_BITS(SWXLB_LBITS + SWXLB_HBITS),
    myid, data;
  int c, r, result;
  if (total_cores > SWXLB_MAX_CORES ||
    cols > rowstride ||
    rows > COUNT_FROM_BITS(SWXLB_VBITS))
  {
    return -SWXLB_INVALID_BOARD_DIMENSIONS;
  }
  /* Make my ID something we can pre-boot the compute nodes from */
  myid = get_local_tile_id();
  write_sswitch_reg_no_ack_clean(myid,0x5,XLB_ORIGIN_ID);
  myid = XLB_ORIGIN_ID;
  /* We are origin for now, everything routes out of us... */
  write_sswitch_reg_no_ack_clean(myid,0xc,0x0000000);
  write_sswitch_reg_no_ack_clean(myid,0xd,0x000000f); //Last nibble for XScope :)
  read_sswitch_reg(myid,0x5,data);
  DBG(printstr,"Control board ID: 0x");
  DBG(printhexln,data);
  xlinkboot_disable_links(myid);
  swallow_xlinkboot_reset(rst);
  /* Special cases to bring-up the corner, before we launch into generic bring-up of switches */
  if (position == SWXLB_POS_BOTTOM || position == SWXLB_POS_RIGHT)
  {
    unsigned rid = swallow_xlinkboot_genid(rows-1,cols-1), rid2;
    if (!position)
    {
      rid &= ~(1 << SWXLB_LPOS);
      rid2 = rid | (1 << SWXLB_LPOS);
    }
    else
    {
      rid2 = rid ^ (1 << SWXLB_LPOS);
    }
    result = xlinkboot_initial_configure(myid, rid, XLB_L_LINKD, XLB_L_LINKB,
      SWXLB_PERIPH_LINK_CONFIG, SWXLB_PERIPH_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
    /* TODO: What links will I need? */
    if (result < 0)
    {
      return result;
    }
    result = xlinkboot_go5(myid, XLB_L_LINKD, SWXLB_PERIPH_LINK_CONFIG, rid, XLB_L_LINKB, SWXLB_PERIPH_LINK_CONFIG);
    if (result < 0)
    {
      return result;
    }
    bootone(rid);
    /* Now bring up the other core */
    result = xlinkboot_initial_configure(rid,rid2, XLB_L_LINKF, XLB_L_LINKG,
      SWXLB_L2_LINK_CONFIG, SWXLB_L2_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
    if (result < 0)
    {
      return result;
    }
    result = xlinkboot_go5(rid, XLB_L_LINKF, SWXLB_L2_LINK_CONFIG, rid2, XLB_L_LINKG, SWXLB_L2_LINK_CONFIG);
    if (result < 0)
    {
      return result;
    }
    bootone(rid2);
    swallow_xlinkboot_internal_links(rid,rid2);
  }
  else
  {
    return -SWXLB_INVALID_PERIPHERAL_POS;
  }
  c = cols - 3;
  for (r = rows - 1; r >= 0; r -= 1)
  {
    /* Handle switching the bottom-right node's routing if we are booting from the right-link */
    if (r == (rows - 2) && position == SWXLB_POS_RIGHT)
    {
      unsigned dstid = swallow_xlinkboot_genid(rows-1,cols-1);
      write_sswitch_reg_no_ack_clean(dstid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
      write_sswitch_reg_no_ack_clean(dstid,0x20 + XLB_L_LINKF, 0x00000000);
    }
    for ( /* BLANK */ ; c >= 0; c -= 1)
    {
      unsigned srcid, dstid = swallow_xlinkboot_genid(r,c);
      /* Swap the right-most cores around to make them reachable */
      /* Second-right-most core (layer 0) needs booting from the below core */
      if (c == (cols-1))
      {
        srcid = swallow_xlinkboot_genid(r+1,cols-2);
        dstid = swallow_xlinkboot_genid(r,cols-2);
        //printhexln(dstid);
        result = xlinkboot_initial_configure(srcid, dstid, XLB_L_LINKA, XLB_L_LINKB,
          SWXLB_COMPUTE_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
        if (result < 0)
        {
          return result;
        }
        bootone(dstid);
      }
      /*Right-most core (layer 1) needs booting over internal-link */
      else if (c == (cols-2))
      {
        srcid = swallow_xlinkboot_genid(r,cols-2);
        dstid = swallow_xlinkboot_genid(r,cols-1);
        //printhexln(dstid);
        result = xlinkboot_initial_configure(srcid, dstid, XLB_L_LINKF, XLB_L_LINKG,
          SWXLB_L2_LINK_CONFIG, SWXLB_L2_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
        if (result < 0)
        {
          return result;
        }
        result = xlinkboot_go5(srcid, XLB_L_LINKF, SWXLB_L2_LINK_CONFIG, dstid, XLB_L_LINKG, SWXLB_L2_LINK_CONFIG);
        if (result < 0)
        {
          return result;
        }
        bootone(dstid);
        swallow_xlinkboot_internal_links(srcid,dstid);
      }
      /* All other layer 1 cores are booted from their neighbour over link B */
      else if (c & 1)
      {
        srcid = swallow_xlinkboot_genid(r,c+2);
        //printhexln(dstid);
        result = xlinkboot_initial_configure(srcid, dstid, XLB_L_LINKA, XLB_L_LINKB,
          SWXLB_COMPUTE_LINK_CONFIG, SWXLB_COMPUTE_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
        if (result < 0)
        {
          return result;
        }
        bootone(dstid);
      }
      /* All other layer 0 cores are booted over internal-link */
      else
      {
        srcid = swallow_xlinkboot_genid(r,c+1);
        //printhexln(dstid);
        result = xlinkboot_initial_configure(srcid, dstid, XLB_L_LINKF, XLB_L_LINKG,
          SWXLB_L2_LINK_CONFIG, SWXLB_L2_LINK_CONFIG, PLL, PLL_len, SWXLB_PLL_DEFAULT);
        if (result < 0)
        {
          return result;
        }
        result = xlinkboot_go5(srcid, XLB_L_LINKF, SWXLB_L2_LINK_CONFIG, dstid, XLB_L_LINKG, SWXLB_L2_LINK_CONFIG);
        if (result < 0)
        {
          return result;
        }
        bootone(dstid);
        swallow_xlinkboot_internal_links(srcid,dstid);
        /* Hello its up/down links as necessary */
        if (r < rows - 1)
        {
          result = xlinkboot_half_link_up(dstid, XLB_L_LINKB, SWXLB_COMPUTE_LINK_CONFIG);
          if (result < 0)
          {
            return result;
          }
        }
        if (r > 0)
        {
          result = xlinkboot_half_link_up(dstid, XLB_L_LINKA, SWXLB_COMPUTE_LINK_CONFIG);
          if (result < 0)
          {
            return result;
          }
        }
      }
    }
    /* Update c here to allow initial skip */
    c = cols - 1;
  }
  DBG(printstrln,"Links up, now to do final routing configuration");
  for (r = 0; r < rows - 1; r += 1)
  {
    /* Neighbour's ID */
    unsigned nid = swallow_xlinkboot_genid(r,cols-2);
    DBG(printstr,"R: ");
    DBG(printintln,r);
    /* When we start a row, make sure the vertical entry point to the row then switches packets horizontally */
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, 0x00000000);
    for (c = 0; c < cols; c += 1)
    {
      /* Ugly hack to swap the order we program the last two nodes in a row */
      if (c == cols - 2)
      {
        c = cols - 1;
      }
      else if (c == cols - 1)
      {
        c = cols - 2;
      }
      /* Tweaks routes to communicate with cores on the "0" layer as we move horizontally along the "1" plane */
      if ((c & 1) == 0 && c + 2 < cols)
      {
        nid = swallow_xlinkboot_genid(r,c+1);
        write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
        write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, 0x00000000);
      }
      result = swallow_xlinkboot_route_configure(r,c,rows,cols,SWXLB_COMPUTE_LINK_CONFIG,position);
      if (result < 0)
      {
        return result;
      }
      /* Ugly hack to swap the order we program the last two nodes in a row */
      if (c == cols - 1)
      {
        c = cols - 2;
      }
      else if (c == cols - 2)
      {
        c = cols - 1;
      }
    }
  }
  DBG(printstrln,"Routing bottom row now...");
  /* Now do the final row as a special case */
  if (position == SWXLB_POS_RIGHT) //TODO: Generalise for both cases
  {
    /* Neighbour's ID */
    unsigned nid = swallow_xlinkboot_genid(rows-1,cols-1);
    /* When we start a row, make sure the vertical entry point to the row then switches packets horizontally */
    DBG(printstr,"Temporary reroute on core 0x");
    DBG(printhexln,nid);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, XLB_ROUTE_AVOID);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, 0x00000000);
    for (c = 0; c < cols - 2; c += 1)
    {
      /* Tweaks routes to communicate with cores on the "0" layer as we move horizontally along the "1" plane */
      if ((c & 1) == 0 && c + 2 < cols)
      {
        nid = swallow_xlinkboot_genid(rows-1,c+1);
        DBG(printstr,"ID: ");
        DBG(printhexln,nid);
        write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
        write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, 0x00000000);
        //result = xlinkboot_half_link_up(swallow_xlinkboot_genid(rows-1,c), XLB_L_LINKA, SWXLB_COMPUTE_LINK_CONFIG);
        if (result < 0)
        {
          return result;
        }
      }
      result = swallow_xlinkboot_route_configure(rows-1,c,rows,cols,SWXLB_COMPUTE_LINK_CONFIG,position);
      if (result < 0)
      {
        return result;
      }
    }
    nid = swallow_xlinkboot_genid(rows-1,cols-1);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, 0x00000000);
    result = swallow_xlinkboot_route_configure(rows-1,cols-2,rows,cols,SWXLB_COMPUTE_LINK_CONFIG,position);
    if (result < 0)
    {
      return result;
    }
    result = swallow_xlinkboot_route_configure(rows-1,cols-1,rows,cols,SWXLB_COMPUTE_LINK_CONFIG,position);
    if (result < 0)
    {
      return result;
    }
  }
  else
  {
    /* Entry point into grid */
    unsigned nid = swallow_xlinkboot_genid(rows-1,cols-2);
    /* When we start a row, make sure the vertical entry point to the row then switches packets horizontally */
    DBG(printstr,"Temporary reroute on core 0x");
    DBG(printhexln,nid);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, 0x00000000);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
    nid = swallow_xlinkboot_genid(rows-1,cols-1);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, 0x00000000);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, XLB_ROUTE_AVOID);
    for (c = 0; c < cols - 2; c += 1)
    {
      /* Tweaks routes to communicate with cores on the "0" layer as we move horizontally along the "1" plane */
      if ((c & 1) == 0 && c + 2 < cols)
      {
        nid = swallow_xlinkboot_genid(rows-1,c+1);
        DBG(printstr,"ID: ");
        DBG(printhexln,nid);
        write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
        write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, 0x00000000);
        //result = xlinkboot_half_link_up(swallow_xlinkboot_genid(rows-1,c), XLB_L_LINKA, SWXLB_COMPUTE_LINK_CONFIG);
        if (result < 0)
        {
          return result;
        }
      }
      result = swallow_xlinkboot_route_configure(rows-1,c,rows,cols,SWXLB_COMPUTE_LINK_CONFIG,position);
      if (result < 0)
      {
        return result;
      }
    }
    
    nid = swallow_xlinkboot_genid(rows-1,cols-2);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKA, XLB_ROUTE_AVOID);
    write_sswitch_reg_no_ack_clean(nid,0x20 + XLB_L_LINKF, 0x00000000);
    result = swallow_xlinkboot_route_configure(rows-1,cols-1,rows,cols,SWXLB_COMPUTE_LINK_CONFIG,position);
    if (result < 0)
    {
      return result;
    }
    result = swallow_xlinkboot_route_configure(rows-1,cols-2,rows,cols,SWXLB_COMPUTE_LINK_CONFIG,position);
    if (result < 0)
    {
      return result;
    }
  }
#if 0
  DBG(printstrln,"Configured all links and routes except my own. Doing that now...");
  /* Now my ID is wrong! So I must give myself a new one - our compute grid address with the P-bit set */
  {
    unsigned nid = swallow_xlinkboot_genid(rows-1,cols-2+position) | 1;
    write_sswitch_reg_no_ack_clean(myid,0x5,nid);
    /* Yes, this is unnecessary, but consider it a soft-test that it worked :) */
    read_sswitch_reg(nid,0x5,myid);
  }
#endif
  /* Just checking we can communicate across the network - not exactly a thorough test but it should catch
   * if things are really boned */
  read_sswitch_reg(0x0,0x5,data);
  gofive(rows,cols);
#ifdef DEMO_MODE
  /* Now run a tiny program to test the cores and let there be light! */
  bootall(rows,cols);
#endif

  /* TODO: Test & bring up any connected peripheral links */
  return 0;
}

