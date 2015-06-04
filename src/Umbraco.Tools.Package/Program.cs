using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Framework.ConfigurationModel;
using Newtonsoft.Json;
using System.IO;
using Newtonsoft.Json.Serialization;

namespace Umbraco.Tools.Package
{
    public class ApplicationSettings
    {
        public string[] Dlls { get; set; }
        public string PackageXmlTemplate { get; set; }
        public string PluginFolder { get; set; }
    }

    public class Program
    {
        public void Main(string[] args)
        {
            Console.WriteLine(@"
  ______ _   _ _____ __________  _   _ ______      
 |  ____| \ | |  __ \___  / __ \| \ | |  ____|     
 | |__  |  \| | |  | | / / |  | |  \| | |__        
 |  __| | . ` | |  | |/ /| |  | | . ` |  __|       
 | |____| |\  | |__| / /_| |__| | |\  | |____      
 |______|_| \_|_____/_____\____/|_| \_|______|___  
 | |  | |  \/  |  _ \|  __ \     /\   / ____/ __ \ 
 | |  | | \  / | |_) | |__) |   /  \ | |   | |  | |
 | |  | | |\/| |  _ <|  _  /   / /\ \| |   | |  | |
 | |__| | |  | | |_) | | \ \  / ____ \ |___| |__| |
  \____/|_|  |_|____/|_|  \_\/_/    \_\_____\____/ 
                                                   
                                                  
");

            if (args.Length == 0)
            {
                Console.WriteLine(@"Usage: package settings.json 
Output: a zip file with the package for Umbraco
settings.json structure:
{
    dlls: ['DLL1', 'DLL2'],
    packageXmlTemplate: 'PATH_TO_PACKAGE.XML'
    pluginFolder: 'PATH_TO_PLUGIN_FOLDER'
}");
                Console.ReadLine();
                return;
            }

            var configText = File.OpenText(args[0]).ReadToEnd();
            var config = (ApplicationSettings)JsonConvert.DeserializeObject(configText, typeof (ApplicationSettings), new JsonSerializerSettings()
            {
                ContractResolver = new CamelCasePropertyNamesContractResolver()
            });

            Console.WriteLine("Dlls: " + string.Join(",", config.Dlls));
            Console.WriteLine("PackageXmlTemplate: " + config.PackageXmlTemplate);
            Console.WriteLine("PluginFolder: " + config.PluginFolder);

            Console.WriteLine();
            Console.WriteLine("Processing...");
            Console.WriteLine();

            using (var builder = new PackageBuilder(config.PackageXmlTemplate, "Package.zip"))
            {
                foreach (var dll in config.Dlls)
                {
                    Console.WriteLine($"Adding {dll}.");
                    builder.AddDll(dll);
                }

                var directory = new DirectoryInfo(config.PluginFolder);
                var files = directory.GetFiles("*.*", SearchOption.AllDirectories);

                foreach (var file in files)
                {
                    Console.WriteLine($"Adding {file.FullName}.");
                    builder.AddBackofficeFile(file.FullName);
                }

                builder.Done();
            }

            Console.WriteLine();
            Console.WriteLine("All done");
            Console.WriteLine();

            Console.ReadLine();
        }
    }
}
