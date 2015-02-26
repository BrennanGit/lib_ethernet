#include <xs1.h>
#include <platform.h>
#include "otp_board_info.h"
#include "ethernet.h"
#include "icmp.h"
#include "smi.h"
#include "debug_print.h"

// These ports are for accessing the OTP memory
otp_ports_t otp_ports = on tile[0]: OTP_PORTS_INITIALIZER;

rgmii_ports_t rgmii_ports = on tile[1]: RGMII_PORTS_INITIALIZER;
port p_smi_mdio   = on tile[1]: XS1_PORT_1C;
port p_smi_mdc    = on tile[1]: XS1_PORT_1D;
port p_eth_reset  = on tile[1]: XS1_PORT_1N;

static unsigned char ip_address[4] = {192, 168, 1, 178};


// An enum to manage the array of connections from the ethernet component
// to its clients.
enum eth_clients {
  ETH_TO_ICMP,
  NUM_ETH_CLIENTS
};

enum cfg_clients {
  CFG_TO_ICMP,
  CFG_TO_PHY_DRIVER,
  NUM_CFG_CLIENTS
};

#define ETHERNET_SMI_PHY_ADDRESS 0x4

[[combinable]]
void phy_driver(client interface smi_if smi,
                client interface ethernet_cfg_if eth) {
  ethernet_link_state_t link_state = ETHERNET_LINK_DOWN;
  const int ethernet_phy_reset_delay_ms = 1;
  const int ethernet_link_poll_period_ms = 1000;
  timer tmr;
  int t;
  p_eth_reset <: 0;
  delay_milliseconds(ethernet_phy_reset_delay_ms);
  p_eth_reset <: 1;

  tmr :> t;

  delay_milliseconds(100);
  smi_configure(smi, 1000, 1);

  while (1 ) {
    select {
    case tmr when timerafter(t) :> t:
      int link_up = smi_is_link_up(smi);
      ethernet_link_state_t new_state = link_up ? ETHERNET_LINK_UP :
                                                  ETHERNET_LINK_DOWN;
      if (new_state != link_state) {
        link_state = new_state;
        eth.set_link_state(0, new_state);
      }
      t += ethernet_link_poll_period_ms * XS1_TIMER_KHZ;
      break;
    }
  }
}

int main()
{
  ethernet_cfg_if i_cfg[NUM_CFG_CLIENTS];
  ethernet_rx_if i_rx[NUM_ETH_CLIENTS];
  ethernet_tx_if i_tx[NUM_ETH_CLIENTS];
  streaming chan c_rgmii_cfg;
  smi_if i_smi;

  par {
    on tile[1]: rgmii_ethernet_mac(i_rx, NUM_ETH_CLIENTS,
                                   i_tx, NUM_ETH_CLIENTS,
                                   null, null,
                                   c_rgmii_cfg,
                                   rgmii_ports, 
                                   ETHERNET_DISABLE_SHAPER);
    on tile[1].core[0]: rgmii_ethernet_mac_config(i_cfg, NUM_CFG_CLIENTS, c_rgmii_cfg);
    on tile[1].core[0]: phy_driver(i_smi, i_cfg[CFG_TO_PHY_DRIVER]);
  
    on tile[1]: smi(i_smi, ETHERNET_SMI_PHY_ADDRESS, p_smi_mdio, p_smi_mdc);

    on tile[0]: icmp_server(i_cfg[CFG_TO_ICMP],
                            i_rx[ETH_TO_ICMP], i_tx[ETH_TO_ICMP],
                            ip_address, otp_ports);
  }
  return 0;
}
