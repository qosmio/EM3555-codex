/***************************************************************************//**
 * @file
 * @brief SoC routines for the Network Steering plugin.
 *******************************************************************************
 * # License
 * <b>Copyright 2018 Silicon Laboratories Inc. www.silabs.com</b>
 *******************************************************************************
 *
 * The licensor of this software is Silicon Laboratories Inc. Your use of this
 * software is governed by the terms of Silicon Labs Master Software License
 * Agreement (MSLA) available at
 * www.silabs.com/about-us/legal/master-software-license-agreement. This
 * software is distributed to you in Source Code format and is governed by the
 * sections of the MSLA applicable to Source Code.
 *
 ******************************************************************************/

#include "app/framework/include/af.h"
#include "debug_output.h"
#include "app/framework/plugin/network-steering/network-steering.h"
#include "app/framework/plugin/network-steering/network-steering-internal.h"

//============================================================================
// Globals

#define MAX_NETWORKS (PACKET_BUFFER_SIZE >> 1)  // 16

#define NULL_PAN_ID 0xFFFF

static uint16_t storedNetworks[MAX_NETWORKS];
static bool storedNetworksInitialized = false;

#define PLUGIN_NAME emAfNetworkSteeringPluginName

static void steeringSocSerialLog(const char *format, ...)
{
  va_list args;

  if (!em3555DebugOutputActive()) {
    return;
  }

  va_start(args, format);
  em3555DebugOutputVPrintf(format, args);
  va_end(args);
  em3555DebugOutputWrite("\r\n");
}

//============================================================================
// Forward Declarations

//============================================================================

uint8_t emAfPluginNetworkSteeringGetMaxPossiblePanIds(void)
{
  return MAX_NETWORKS;
}

void emAfPluginNetworkSteeringClearStoredPanIds(void)
{
  for (uint8_t i = 0; i < MAX_NETWORKS; i++) {
    storedNetworks[i] = NULL_PAN_ID;
  }
  storedNetworksInitialized = false;
}

uint16_t* emAfPluginNetworkSteeringGetStoredPanIdPointer(uint8_t index)
{
  if (index >= MAX_NETWORKS) {
    return NULL;
  }

  if (!storedNetworksInitialized) {
    emAfPluginNetworkSteeringClearStoredPanIds();
    storedNetworksInitialized = true;
    steeringSocSerialLog("steer buffer static slots=%d", MAX_NETWORKS);
  }

  return &storedNetworks[index];
}

void emberAfPluginNetworkSteeringMarker(void)
{
  // PAN candidate storage is kept in static RAM, so there is no packet buffer
  // handle to mark during GC.
}
