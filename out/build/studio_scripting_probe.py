print("studio-scripting-probe: start")

try:
    import sys
    print("python-version=%s" % getattr(sys, "version", "unknown"))
    print("argv=%s" % list(getattr(sys, "argv", [])))
except Exception as exc:
    print("sys-import-failed=%s" % exc)

try:
    from java.lang import System
    print("java-version=%s" % System.getProperty("java.version"))
except Exception as exc:
    print("java-import-failed=%s" % exc)

try:
    from org.eclipse.core.runtime import Platform
    print("platform-running=%s" % Platform.isRunning())
    bundle = Platform.getBundle("com.ember.app_configurator")
    print("bundle-com.ember.app_configurator=%s" % bundle)
    try:
        from org.osgi.framework import FrameworkUtil
        current_bundle = FrameworkUtil.getBundle(Platform)
        print("current-bundle=%s" % current_bundle)
        if current_bundle is not None:
            bundle_context = current_bundle.getBundleContext()
            bundle_names = []
            for entry in bundle_context.getBundles():
                symbolic_name = entry.getSymbolicName()
                if symbolic_name and ("ember" in symbolic_name or "scripting" in symbolic_name):
                    bundle_names.append(symbolic_name)
            print("interesting-bundles=%s" % sorted(bundle_names))
    except Exception as exc:
        print("bundle-list-failed=%s" % exc)
except Exception as exc:
    print("platform-import-failed=%s" % exc)

for class_path in (
    ("com.silabs.ss.platform.api.scripting.core", "Script"),
    ("com.ember.workbench.app_configurator.rcp", "Application"),
    ("com.ember.workbench.app_configurator.generator", "Afv2Generator"),
):
    package_name, class_name = class_path
    try:
        module = __import__(package_name, fromlist=[class_name])
        klass = getattr(module, class_name)
        print("class-ok=%s.%s => %s" % (package_name, class_name, klass))
    except Exception as exc:
        print("class-failed=%s.%s err=%s" % (package_name, class_name, exc))

print("studio-scripting-probe: done")
