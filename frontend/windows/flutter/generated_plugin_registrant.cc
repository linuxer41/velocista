//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <bluetooth_classic_multiplatform/bluetooth_classic_multiplatform_plugin_c_api.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  BluetoothClassicMultiplatformPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("BluetoothClassicMultiplatformPluginCApi"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
}
