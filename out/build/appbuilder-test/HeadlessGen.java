import java.io.File;
import com.ember.workbench.app_framework.application.ApplicationModel;
import com.ember.workbench.app_framework.generator.GenerationResult;
import com.ember.workbench.app_framework.generator.GeneratorModel;
import com.ember.workbench.app_framework.isc.IscFile;
import com.ember.workbench.app_framework.model.ConfigurationValidator;
import com.ember.workbench.app_configurator.core.ConfigurationData;

public class HeadlessGen {
  public static void main(String[] args) throws Exception {
    if (args.length != 2) {
      throw new IllegalArgumentException("usage: HeadlessGen <stackDir> <isc>");
    }
    int count = ApplicationModel.scanStack(new File(args[0]));
    System.out.println("scanCount=" + count);
    var config = ConfigurationData.read(new IscFile(new File(args[1])), null);
    var validator = new ConfigurationValidator(config);
    validator.validate();
    System.out.println("valid=" + validator.isValid());
    if (!validator.isValid()) {
      System.out.println(validator.errorMessage());
      System.exit(2);
    }
    var gen = GeneratorModel.instance().findGenerator(config.framework());
    System.out.println("generator=" + gen);
    var result = GenerationResult.make(config);
    gen.generate(result);
    result.generateFromCommandLine(true, false);
    System.out.println("generated=" + result.items().length);
  }
}
