#!/usr/bin/env python

import xmostest
import os
import random
import sys
from mii_clock import Clock
from mii_phy import MiiTransmitter, MiiReceiver
from rgmii_phy import RgmiiTransmitter, RgmiiReceiver
from mii_packet import MiiPacket
from helpers import do_rx_test, get_dut_mac_address, check_received_packet

def do_test(impl, tx_clk, tx_phy):
    resources = xmostest.request_resource("xsim")

    binary = 'test_etype_filter/bin/{impl}_{phy}/test_etype_filter_{impl}_{phy}.xe'.format(
        impl=impl, phy=tx_phy.get_name())

    dut_mac_address = get_dut_mac_address()
    packets = [
        MiiPacket(dst_mac_addr=dut_mac_address, src_mac_addr=[0 for x in range(6)],
                  ether_len_type=[0x11, 0x11], data_bytes=[1,2,3,4] + [0 for x in range(50)]),
        MiiPacket(dst_mac_addr=dut_mac_address, src_mac_addr=[0 for x in range(6)],
                  ether_len_type=[0x22, 0x22], data_bytes=[5,6,7,8] + [0 for x in range(60)])
      ]

    tx_phy.set_packets(packets)

    tester = xmostest.pass_if_matches(open('test_etype_filter.expect'),
                                     'lib_ethernet', 'basic_tests',
                                      'etype_filter_test',
                                      {'impl':impl, 'phy':tx_phy.get_name(), 'clk':tx_clk.get_name()})

    xmostest.run_on_simulator(resources['xsim'], binary,
                              simthreads = [tx_clk, tx_phy],
                              tester = tester)

def runtest():
    random.seed(1)

    # Test 100 MBit - MII
    tx_clk_25 = Clock('tile[0]:XS1_PORT_1J', Clock.CLK_25MHz)
    tx_mii = MiiTransmitter('tile[0]:XS1_PORT_4E',
                            'tile[0]:XS1_PORT_1K',
                            tx_clk_25, verbose=True)

    do_test("standard", tx_clk_25, tx_mii)
    do_test("rt", tx_clk_25, tx_mii)