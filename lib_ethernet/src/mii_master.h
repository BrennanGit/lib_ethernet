#ifndef __mii_master_h__
#define __mii_master_h__
#include "mii_buffering.h"
#include "mii_ts_queue.h"

#ifdef __XC__

void mii_master_init(in port p_rxclk, in buffered port:32 p_rxd, in port p_rxdv,
                     clock clk_rx,
                     in port p_txclk, out port p_txen, out buffered port:32 p_txd,
                     clock clk_tx);

unsafe void mii_master_rx_pins(mii_mempool_t rxmem_hp,
                               mii_mempool_t rxmem_lp,
                               in port p_mii_rxdv,
                               in buffered port:32 p_mii_rxd,
                               in buffered port:1 p_rxer,
                               streaming chanend c);

unsafe void mii_master_tx_pins(mii_mempool_t hp_queue,
                               mii_mempool_t lp_queue,
                               mii_ts_queue_t ts_queue_lp,
                               out buffered port:32 p_mii_txd,
                               int enable_shaper,
                               volatile int * unsafe idle_slope);

#endif

#endif // __mii_master_h__
