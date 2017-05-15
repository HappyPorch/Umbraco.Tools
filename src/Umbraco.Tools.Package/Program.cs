using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using System;
using System.IO;
using System.Linq;

namespace Umbraco.Tools.Package
{
    public class ApplicationSettings
    {
        private string[] _includeFolders;
        private string[] _dlls;

        public string[] Dlls
        {
            get { return _dlls ?? (_dlls = new string[0]); }
            set { _dlls = value; }
        }

        public string PackageXmlTemplate { get; set; }

        public string[] IncludeFolders
        {
            get { return _includeFolders ?? (_includeFolders = new string[0]); }
            set { _includeFolders = value; }
        }
    }

    public class Program
    {
        public static void Main(string[] args)
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

            if (args.Length != 1 || !File.Exists(args[0]))
            {
                Console.WriteLine(@"Usage: package settings.json 
Output: a zip file with the package for Umbraco
settings.json structure:
{
    dlls: ['DLL1', 'DLL2'],
    packageXmlTemplate: 'PATH_TO_PACKAGE.XML'
    includeFolders: ['PATH_TO_PLUGIN', 'PATH_TO_XSLT']
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
            Console.WriteLine("IncludeFolders:" + (config.IncludeFolders.Any() ? string.Empty : " None"));
            foreach (var folder in config.IncludeFolders)
            {
                Console.WriteLine($"  {folder}");
            }

            Console.WriteLine();
            Console.WriteLine("Processing...");
            Console.WriteLine();

            // ReSharper disable once PossibleNullReferenceException
            var workingDirectory = new FileInfo(args[0]).Directory.FullName;

            // set the current directory to the one of the pack.json file, as the paths within are relative to the it
            Directory.SetCurrentDirectory(workingDirectory);

            using (var builder = new PackageBuilder(config.PackageXmlTemplate, "Package.zip"))
            {
                foreach (var dll in config.Dlls)
                {
                    Console.WriteLine($"Adding {dll}.");
                    builder.AddDll(dll);
                }

                foreach (var folder in config.IncludeFolders)
                {
                    Console.WriteLine($"Processing {folder}.");
                    builder.AddPluginFolder(folder);
                }

                builder.Done();
            }

            Console.WriteLine();
            Console.WriteLine("All done");
        }
    }
}
