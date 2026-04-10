from java.lang import System
from org.eclipse.core.runtime import Platform

print("Platform running:", Platform.isRunning())
bundle = Platform.getBundle("com.ember.app_configurator")
print("AppBuilder bundle:", bundle)
if bundle is not None:
    print("Bundle state:", bundle.getState())
    bundle.start()
    print("Bundle state after start:", bundle.getState())
    from com.ember.workbench.app_configurator.core import AppConfiguratorScriptingUtils
    print("Embedded generation entrypoint:", AppConfiguratorScriptingUtils)
else:
    print("Bundle not available")
