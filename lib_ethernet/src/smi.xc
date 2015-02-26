// Copyright (c) 2011, XMOS Ltd., All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#include <xs1.h>
#include "smi.h"
#include "print.h"
#include "xassert.h"

// Clock is 4 times this rate.
#define SMI_CLOCK_DIVIDER   (100 / 10)


// Constants used in calls to smi_bit_shift and smi_reg.

#define SMI_READ 1
#define SMI_WRITE 0

#ifndef SMI_MDIO_RESET_MUX
#define SMI_MDIO_RESET_MUX 0
#endif

#ifndef SMI_MDIO_REST
#define SMI_MDIO_REST 0
#endif


// Shift in a number of data bits to or from the SMI port
static int smi_bit_shift(port p_smi_mdc, port ?p_smi_mdio,
                         unsigned data,
                         unsigned count, unsigned inning,
                         unsigned SMI_MDIO_BIT,
                         unsigned SMI_MDC_BIT)
{
    int i = count, data_bit = 0, t;

    if (isnull(p_smi_mdio)) {
        p_smi_mdc :> void @ t;
        if (inning) {
            while (i != 0) {
                i--;
                p_smi_mdc @ (t + 30) :> data_bit;
                data_bit &= (1 << SMI_MDIO_BIT);
                if (SMI_MDIO_RESET_MUX)
                  data_bit |= SMI_MDIO_REST;
                p_smi_mdc            <: data_bit;
                data = (data << 1) | (data_bit >> SMI_MDIO_BIT);
                p_smi_mdc @ (t + 60) <: 1 << SMI_MDC_BIT | data_bit;
                p_smi_mdc            :> void;
                t += 60;
            }
            p_smi_mdc @ (t+30) :> void;
        } else {
          while (i != 0) {
                i--;
                data_bit = ((data >> i) & 1) << SMI_MDIO_BIT;
                if (SMI_MDIO_RESET_MUX)
                  data_bit |= SMI_MDIO_REST;
                p_smi_mdc @ (t + 30) <:                    data_bit;
                p_smi_mdc @ (t + 60) <: 1 << SMI_MDC_BIT | data_bit;
                t += 60;
            }
            p_smi_mdc @ (t+30) <: 1 << SMI_MDC_BIT | data_bit;
        }
        return data;
    }
    else {
      p_smi_mdc <: ~0 @ t;
      while (i != 0) {
        i--;
        p_smi_mdc @ (t+30) <: 0;
        if (!inning) {
          int data_bit;
          data_bit = ((data >> i) & 1) << SMI_MDIO_BIT;
          if (SMI_MDIO_RESET_MUX)
            data_bit |= SMI_MDIO_REST;
          p_smi_mdio <: data_bit;
        }
        p_smi_mdc @ (t+60) <: ~0;
        if (inning) {
          p_smi_mdio :> data_bit;
          data_bit = data_bit >> SMI_MDIO_BIT;
          data = (data << 1) | data_bit;
        }
        t += 60;
      }
      p_smi_mdc @ (t+30) <: ~0;
      return data;
    }
}


[[distributable]]
void smi(server interface smi_if i, unsigned phy_address,
         port p_smi_mdio, port p_smi_mdc)
{
  if (SMI_MDIO_RESET_MUX) {
    timer tmr;
    int t;
    p_smi_mdio <: 0x0;
    tmr :> t;tmr when timerafter(t+100000) :> void;
    p_smi_mdio <: SMI_MDIO_REST;
  }

  p_smi_mdc <: 1;

  while (1) {
    select {
    case i.read_reg(uint8_t reg) -> uint16_t res:
      int inning = 1;
      int val;
      // Register access: lots of 1111, then a code (read/write), phy address,
      // register, and a turn-around, then data.
      smi_bit_shift(p_smi_mdc, p_smi_mdio, 0xffffffff, 32, SMI_WRITE,
                    0, 0);         // Preamble
      smi_bit_shift(p_smi_mdc, p_smi_mdio, (5+inning) << 10 | phy_address << 5 | reg,
                    14, SMI_WRITE,
                    0, 0);
      smi_bit_shift(p_smi_mdc, p_smi_mdio, 2, 2, inning,
                    0, 0);
      res = smi_bit_shift(p_smi_mdc, p_smi_mdio, val, 16, inning, 0, 0);
      break;
    case i.write_reg(uint8_t reg, uint16_t val):
      int inning = 0;
      // Register access: lots of 1111, then a code (read/write), phy address,
      // register, and a turn-around, then data.
      smi_bit_shift(p_smi_mdc, p_smi_mdio, 0xffffffff, 32, SMI_WRITE,
                    0, 0);         // Preamble
      smi_bit_shift(p_smi_mdc, p_smi_mdio, (5+inning) << 10 | phy_address << 5 | reg,
                    14, SMI_WRITE,
                    0, 0);
      smi_bit_shift(p_smi_mdc, p_smi_mdio, 2, 2, inning,
                    0, 0);
      (void) smi_bit_shift(p_smi_mdc, p_smi_mdio, val, 16, inning, 0, 0);
      break;
    }
  }
}

[[distributable]]
void smi_singleport(server interface smi_if i, unsigned phy_address,
                    port p_smi, unsigned SMI_MDIO_BIT, unsigned SMI_MDC_BIT)
{
  if (SMI_MDIO_RESET_MUX) {
    timer tmr;
    int t;
    p_smi <: 0x0;
    tmr :> t;tmr when timerafter(t+100000) :> void;
    p_smi <: SMI_MDIO_REST;
  }

  p_smi <: 1 << SMI_MDC_BIT;

  while (1) {
    select {
    case i.read_reg(uint8_t reg) -> uint16_t res:
      int inning = 1;
      int val;
      // Register access: lots of 1111, then a code (read/write), phy address,
      // register, and a turn-around, then data.
      smi_bit_shift(p_smi, null, 0xffffffff, 32, SMI_WRITE,
                    SMI_MDIO_BIT, SMI_MDC_BIT);         // Preamble
      smi_bit_shift(p_smi, null, (5+inning) << 10 | phy_address << 5 | reg,
                    14, SMI_WRITE,
                    SMI_MDIO_BIT, SMI_MDC_BIT);
      smi_bit_shift(p_smi, null, 2, 2, inning,
                    SMI_MDIO_BIT, SMI_MDC_BIT);
      res = smi_bit_shift(p_smi, null, val, 16, inning, SMI_MDIO_BIT, SMI_MDC_BIT);
      break;
    case i.write_reg(uint8_t reg, uint16_t val):
      int inning = 0;
      // Register access: lots of 1111, then a code (read/write), phy address,
      // register, and a turn-around, then data.
      smi_bit_shift(p_smi, null, 0xffffffff, 32, SMI_WRITE,
                    SMI_MDIO_BIT, SMI_MDC_BIT);         // Preamble
      smi_bit_shift(p_smi, null, (5+inning) << 10 | phy_address << 5 | reg,
                    14, SMI_WRITE,
                    SMI_MDIO_BIT, SMI_MDC_BIT);
      smi_bit_shift(p_smi, null, 2, 2, inning,
                    SMI_MDIO_BIT, SMI_MDC_BIT);
      (void) smi_bit_shift(p_smi, null, val, 16, inning, SMI_MDIO_BIT, SMI_MDC_BIT);
      break;
    }
  }
}



unsigned smi_get_id(client smi_if smi) {
  unsigned lo = smi.read_reg(PHY_ID1_REG);
  unsigned hi = smi.read_reg(PHY_ID2_REG);
  return ((hi >> 10) << 16) | lo;
}

void smi_configure(client smi_if smi, int speed_mbps, int enable_auto_neg)
{
  if (speed_mbps != 10 && speed_mbps != 100 && speed_mbps != 1000) {
    fail("Invalid Ethernet speed provided, must be 10, 100 or 1000");
  }

  if (enable_auto_neg) {
    uint16_t auto_neg_advert_100_reg = smi.read_reg(AUTONEG_ADVERT_REG);
    uint16_t gige_control_reg = smi.read_reg(GIGE_CONTROL_REG);

    // Clear bits [9:5]
    auto_neg_advert_100_reg &= 0xfc1f;
    // Clear bits [9:8]
    gige_control_reg &= 0xfcff;

    switch (speed_mbps) {
    #pragma fallthrough
      case 1000: gige_control_reg |= 1 << AUTONEG_ADVERT_1000BASE_T_FULL_DUPLEX;
    #pragma fallthrough
      case 100: auto_neg_advert_100_reg |= 1 << AUTONEG_ADVERT_100BASE_TX_FULL_DUPLEX;
      case 10: auto_neg_advert_100_reg |= 1 << AUTONEG_ADVERT_10BASE_TX_FULL_DUPLEX; break;
      default: __builtin_unreachable(); break;
    }

    // Write back
    smi.write_reg(AUTONEG_ADVERT_REG, auto_neg_advert_100_reg);
    smi.write_reg(GIGE_CONTROL_REG, gige_control_reg);
  }

  uint16_t basic_control = smi.read_reg(BASIC_CONTROL_REG);
  if (enable_auto_neg) {
    // set autoneg bit
    basic_control |= 1 << BASIC_CONTROL_AUTONEG_EN_BIT;
    smi.write_reg(BASIC_CONTROL_REG, basic_control);
    // restart autoneg
    basic_control |= 1 << BASIC_CONTROL_RESTART_AUTONEG_BIT;
  }
  else {
    // set duplex mode, clear autoneg and speed
    basic_control |= 1 << BASIC_CONTROL_FULL_DUPLEX_BIT;
    basic_control &= ~( (1 << BASIC_CONTROL_AUTONEG_EN_BIT)|
                          (1 << BASIC_CONTROL_100_MBPS_BIT)|
                         (1 << BASIC_CONTROL_1000_MBPS_BIT));

    if (speed_mbps == 100) {
      basic_control |= 1 << BASIC_CONTROL_100_MBPS_BIT;
    } else if (speed_mbps == 1000) {
      fail("Autonegotiation cannot be disabled in 1000 Mbps mode");
    }
  }
  smi.write_reg(BASIC_CONTROL_REG, basic_control);
}

void smi_set_loopback_mode(client smi_if smi, int enable)
{
  uint16_t control_reg = smi.read_reg(BASIC_CONTROL_REG);

  // First clear both autoneg and loopback
  control_reg = control_reg & ~ ((1 << BASIC_CONTROL_AUTONEG_EN_BIT) |
                               (1 << BASIC_CONTROL_LOOPBACK_BIT));
  // Now selectively set one of them
  if (enable) {
    control_reg = control_reg | (1 << BASIC_CONTROL_LOOPBACK_BIT);
  } else {
    control_reg = control_reg | (1 << BASIC_CONTROL_AUTONEG_EN_BIT);
  }

  smi.write_reg(BASIC_CONTROL_REG, control_reg);
}


int smi_is_link_up(client smi_if smi) {
  int link_up = ((smi.read_reg(BASIC_STATUS_REG) >> BASIC_STATUS_LINK_BIT) & 1);
  return link_up;
}
