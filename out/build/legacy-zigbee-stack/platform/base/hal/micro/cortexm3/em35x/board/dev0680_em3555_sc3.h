#ifndef __BOARD_EM3555_SC3_H__
#define __BOARD_EM3555_SC3_H__

#include "dev0680.h"

/* EM35x uart.c expects EMBER_SERIAL_BAUD_CUSTOM to be the encoded baud
 * register value, not the plain enum/index from the stock board header.
 * 0x9A is the EM35x register setting for 921600 baud.
 */
#undef EMBER_SERIAL_BAUD_CUSTOM
#define EMBER_SERIAL_BAUD_CUSTOM  0x9A

#undef DEFINE_POWERUP_GPIO_CFG_VARIABLES
#define DEFINE_POWERUP_GPIO_CFG_VARIABLES()                                                      \
  uint16_t gpioCfgPowerUp[6] = {                                                                 \
    ((PWRUP_CFG_USBDM           << _GPIO_P_CFGL_Px0_SHIFT)                                       \
     | (PWRUP_CFG_USBDP           << _GPIO_P_CFGL_Px1_SHIFT)                                     \
     | (PWRUP_CFG_ENUMCTRL        << _GPIO_P_CFGL_Px2_SHIFT)                                     \
     | (PWRUP_CFG_VBUSMON         << _GPIO_P_CFGL_Px3_SHIFT)),                                   \
    ((PWRUP_CFG_PTI_EN          << _GPIO_P_CFGH_Px4_SHIFT)                                       \
     | (PWRUP_CFG_PTI_DATA        << _GPIO_P_CFGH_Px5_SHIFT)                                     \
     | (PWRUP_CFG_DFL_RHO         << _GPIO_P_CFGH_Px6_SHIFT)                                     \
     | (GPIO_P_CFGz_Pxy_OUT      << _GPIO_P_CFGH_Px7_SHIFT)),                                    \
    ((GPIO_P_CFGz_Pxy_OUT      << _GPIO_P_CFGL_Px0_SHIFT)                                        \
     | (PWRUP_CFG_SC1_TXD         << _GPIO_P_CFGL_Px1_SHIFT)                       /* SC1TXD  */ \
     | (GPIO_P_CFGz_Pxy_IN_PUD   << _GPIO_P_CFGL_Px2_SHIFT)                       /* SC1RXD  */  \
     | (GPIO_P_CFGz_Pxy_IN_PUD   << _GPIO_P_CFGL_Px3_SHIFT)),                     /* SC1nCTS */  \
    ((GPIO_P_CFGz_Pxy_OUT_ALT  << _GPIO_P_CFGH_Px4_SHIFT)                         /* SC1nRTS */  \
     | (GPIO_P_CFGz_Pxy_ANALOG   << _GPIO_P_CFGH_Px5_SHIFT)                                      \
     | (GPIO_P_CFGz_Pxy_IN_PUD   << _GPIO_P_CFGH_Px6_SHIFT)                                      \
     | (GPIO_P_CFGz_Pxy_OUT_ALT  << _GPIO_P_CFGH_Px7_SHIFT)),                                    \
    ((GPIO_P_CFGz_Pxy_IN       << _GPIO_P_CFGL_Px0_SHIFT)                                        \
     | (GPIO_P_CFGz_Pxy_IN       << _GPIO_P_CFGL_Px1_SHIFT)                         /* TP7/PC1 */ \
     | (GPIO_P_CFGz_Pxy_IN       << _GPIO_P_CFGL_Px2_SHIFT)                         /* TPV9/PC2 */ \
     | (GPIO_P_CFGz_Pxy_IN       << _GPIO_P_CFGL_Px3_SHIFT)),                                    \
    ((GPIO_P_CFGz_Pxy_IN       << _GPIO_P_CFGH_Px4_SHIFT)                                        \
     | (PWRUP_CFG_LED2            << _GPIO_P_CFGH_Px5_SHIFT)                                     \
     | (PWRUP_CFG_BUTTON1         << _GPIO_P_CFGH_Px6_SHIFT)                                     \
     | (CFG_TEMPEN                << _GPIO_P_CFGH_Px7_SHIFT))                                    \
  }

#undef DEFINE_POWERUP_GPIO_OUTPUT_DATA_VARIABLES
#define DEFINE_POWERUP_GPIO_OUTPUT_DATA_VARIABLES()                                      \
  uint8_t gpioOutPowerUp[3] = {                                                          \
    ((PWRUP_OUT_USBDM    << _GPIO_P_OUT_Px0_SHIFT)                                       \
     | (PWRUP_OUT_USBDP    << _GPIO_P_OUT_Px1_SHIFT)                                     \
     | (PWRUP_OUT_ENUMCTRL << _GPIO_P_OUT_Px2_SHIFT)                                     \
     | (PWRUP_OUT_VBUSMON  << _GPIO_P_OUT_Px3_SHIFT)                                     \
     | (PWRUP_OUT_PTI_EN   << _GPIO_P_OUT_Px4_SHIFT)                                     \
     | (PWRUP_OUT_PTI_DATA << _GPIO_P_OUT_Px5_SHIFT)                                     \
     | (PWRUP_OUT_DFL_RHO  << _GPIO_P_OUT_Px6_SHIFT)                                     \
     | (1                  << _GPIO_P_OUT_Px7_SHIFT)),                                   \
    ((1                  << _GPIO_P_OUT_Px0_SHIFT)                                       \
     | (1                  << _GPIO_P_OUT_Px1_SHIFT)                       /* SC1TXD  */ \
     | (1                  << _GPIO_P_OUT_Px2_SHIFT)                       /* SC1RXD  */ \
     | (1                  << _GPIO_P_OUT_Px3_SHIFT)                       /* SC1nCTS */ \
     | (0                  << _GPIO_P_OUT_Px4_SHIFT)                       /* SC1nRTS */ \
     | (0                  << _GPIO_P_OUT_Px5_SHIFT)                                     \
     | (1                  << _GPIO_P_OUT_Px6_SHIFT)                                     \
     | (0                  << _GPIO_P_OUT_Px7_SHIFT)),                                   \
    ((0                  << _GPIO_P_OUT_Px0_SHIFT)                                       \
     | (0                  << _GPIO_P_OUT_Px1_SHIFT)                         /* TP7/PC1 */ \
     | (1                  << _GPIO_P_OUT_Px2_SHIFT)                         /* TPV9/PC2 */ \
     | (0                  << _GPIO_P_OUT_Px3_SHIFT)                                     \
     | (0                  << _GPIO_P_OUT_Px4_SHIFT)                                     \
     | (PWRUP_OUT_LED2     << _GPIO_P_OUT_Px5_SHIFT)                                     \
     | (PWRUP_OUT_BUTTON1  << _GPIO_P_OUT_Px6_SHIFT)                                     \
     | (1                  << _GPIO_P_OUT_Px7_SHIFT))                                    \
  }

#undef DEFINE_POWERDOWN_GPIO_CFG_VARIABLES
#define DEFINE_POWERDOWN_GPIO_CFG_VARIABLES()                                                    \
  uint16_t gpioCfgPowerDown[6] = {                                                               \
    ((PWRDN_CFG_USBDM          << _GPIO_P_CFGL_Px0_SHIFT)                                        \
     | (PWRDN_CFG_USBDP          << _GPIO_P_CFGL_Px1_SHIFT)                                      \
     | (PWRDN_CFG_ENUMCTRL       << _GPIO_P_CFGL_Px2_SHIFT)                                      \
     | (PWRDN_CFG_VBUSMON        << _GPIO_P_CFGL_Px3_SHIFT)),                                    \
    ((PWRDN_CFG_PTI_EN         << _GPIO_P_CFGH_Px4_SHIFT)                                        \
     | (PWRDN_CFG_PTI_DATA       << _GPIO_P_CFGH_Px5_SHIFT)                                      \
     | (PWRDN_CFG_DFL_RHO        << _GPIO_P_CFGH_Px6_SHIFT)                                      \
     | (GPIO_P_CFGz_Pxy_OUT     << _GPIO_P_CFGH_Px7_SHIFT)),                                     \
    ((GPIO_P_CFGz_Pxy_OUT     << _GPIO_P_CFGL_Px0_SHIFT)                                         \
     | (GPIO_P_CFGz_Pxy_OUT     << _GPIO_P_CFGL_Px1_SHIFT)                         /* SC1TXD  */ \
     | (GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGL_Px2_SHIFT)                         /* SC1RXD  */ \
     | (GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGL_Px3_SHIFT)),                       /* SC1nCTS */ \
    ((GPIO_P_CFGz_Pxy_OUT     << _GPIO_P_CFGH_Px4_SHIFT)                           /* SC1nRTS */ \
     | (GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGH_Px5_SHIFT)                                         \
     | (GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGH_Px6_SHIFT)                                       \
     | (GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGH_Px7_SHIFT)),                                       \
    ((GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGL_Px0_SHIFT)                                         \
     | (GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGL_Px1_SHIFT)                         /* TP7/PC1 */ \
     | (GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGL_Px2_SHIFT)                         /* TPV9/PC2 */ \
     | (GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGL_Px3_SHIFT)),                                     \
    ((GPIO_P_CFGz_Pxy_IN_PUD  << _GPIO_P_CFGH_Px4_SHIFT)                                         \
     | (PWRDN_CFG_LED2           << _GPIO_P_CFGH_Px5_SHIFT)                                      \
     | (PWRDN_CFG_BUTTON1        << _GPIO_P_CFGH_Px6_SHIFT)                                      \
     | (CFG_TEMPEN               << _GPIO_P_CFGH_Px7_SHIFT))                                     \
  }

#undef DEFINE_POWERDOWN_GPIO_OUTPUT_DATA_VARIABLES
#define DEFINE_POWERDOWN_GPIO_OUTPUT_DATA_VARIABLES()                                      \
  uint8_t gpioOutPowerDown[3] = {                                                          \
    ((PWRDN_OUT_USBDM    << _GPIO_P_OUT_Px0_SHIFT)                                         \
     | (PWRDN_OUT_USBDP    << _GPIO_P_OUT_Px1_SHIFT)                                       \
     | (PWRDN_OUT_ENUMCTRL << _GPIO_P_OUT_Px2_SHIFT)                                       \
     | (PWRDN_OUT_VBUSMON  << _GPIO_P_OUT_Px3_SHIFT)                                       \
     | (PWRDN_OUT_PTI_EN   << _GPIO_P_OUT_Px4_SHIFT)                                       \
     | (PWRDN_OUT_PTI_DATA << _GPIO_P_OUT_Px5_SHIFT)                                       \
     | (PWRDN_OUT_DFL_RHO  << _GPIO_P_OUT_Px6_SHIFT)                                       \
     | (1                  << _GPIO_P_OUT_Px7_SHIFT)),                                     \
    ((0                  << _GPIO_P_OUT_Px0_SHIFT)                                         \
     | (1                  << _GPIO_P_OUT_Px1_SHIFT)                         /* SC1TXD  */ \
     | (1                  << _GPIO_P_OUT_Px2_SHIFT)                         /* SC1RXD  */ \
     | (1                  << _GPIO_P_OUT_Px3_SHIFT)                         /* SC1nCTS */ \
     | (PWRDN_OUT_SC1_nRTS << _GPIO_P_OUT_Px4_SHIFT)                         /* SC1nRTS */ \
     | (0                  << _GPIO_P_OUT_Px5_SHIFT)                                       \
     | (1                  << _GPIO_P_OUT_Px6_SHIFT)                                       \
     | (0                  << _GPIO_P_OUT_Px7_SHIFT)),                                     \
    ((1                  << _GPIO_P_OUT_Px0_SHIFT)                                         \
     | (0                  << _GPIO_P_OUT_Px1_SHIFT)                         /* TP7/PC1 */ \
     | (1                  << _GPIO_P_OUT_Px2_SHIFT)                         /* TPV9/PC2 */ \
     | (0                  << _GPIO_P_OUT_Px3_SHIFT)                                       \
     | (0                  << _GPIO_P_OUT_Px4_SHIFT)                                       \
     | (PWRDN_OUT_LED2     << _GPIO_P_OUT_Px5_SHIFT)                                       \
     | (PWRDN_OUT_BUTTON1  << _GPIO_P_OUT_Px6_SHIFT)                                       \
     | (0                  << _GPIO_P_OUT_Px7_SHIFT))                                      \
  }

#endif
