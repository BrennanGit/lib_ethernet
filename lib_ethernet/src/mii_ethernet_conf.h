#ifndef ETHERNET_SUPPORT_HP_QUEUES
#define ETHERNET_SUPPORT_HP_QUEUES (0)
#endif

#ifndef ETHERNET_SUPPORT_TRAFFIC_SHAPER
#define ETHERNET_SUPPORT_TRAFFIC_SHAPER (0)
#endif

#ifndef ETHERNET_FILTER_SPECIALIZATION
  #define ETHERNET_FILTER_SPECIALIZATION
  #ifndef ETHERNET_ENABLE_FILTER_TIMING
  #define ETHERNET_ENABLE_FILTER_TIMING 0
  #endif
#else
  #ifndef ETHERNET_ENABLE_FILTER_TIMING
  #define ETHERNET_ENABLE_FILTER_TIMING 1
  #endif
#endif

#define MII_CREDIT_FRACTIONAL_BITS 16

#define ETHERNET_FILTER_PORT_FORWARD_MASK 0x80000000

#ifndef ETHERNET_RX_CLIENT_QUEUE_SIZE
  #if RGMII
    #define ETHERNET_RX_CLIENT_QUEUE_SIZE (16)
  #else
    #define ETHERNET_RX_CLIENT_QUEUE_SIZE (4)
  #endif
#endif

#ifndef ETHERNET_TX_MAX_PACKET_SIZE
#define ETHERNET_TX_MAX_PACKET_SIZE ETHERNET_MAX_PACKET_SIZE
#endif

#ifndef ETHERNET_RX_MAX_PACKET_SIZE
#define ETHERNET_RX_MAX_PACKET_SIZE ETHERNET_MAX_PACKET_SIZE
#endif

#ifndef RGMII_MAC_BUFFER_COUNT
// Provide enough buffers to receive all minumum sized frames after
// a maximum sized frame - using a power of 2 value is more efficient
#define RGMII_MAC_BUFFER_COUNT 32
#endif

#ifndef ETHERNET_USE_HARDWARE_LOCKS
#define ETHERNET_USE_HARDWARE_LOCKS 1
#endif

