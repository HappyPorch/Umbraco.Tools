using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Xml.Linq;

namespace Umbraco.Tools.Package
{
    public class PackageBuilder : IDisposable
    {
        private ZipArchive archive;
        private XDocument packageFile;

        public PackageBuilder(string packageFileName, string destination)
        {
            var stream = new FileStream(destination, FileMode.Create);
            archive = new ZipArchive(stream, ZipArchiveMode.Create, false);

            packageFile = XDocument.Load(packageFileName);
        }

        public void AddDll(string filename)
        {
            var file = new FileInfo(filename);
            if (!file.Exists)
                throw new InvalidOperationException($"The requested file {filename} does not exist");

            using (var fileStream = file.Open(FileMode.Open))
            {
                AddFile(file.Name, "/bin", fileStream);
            } 
        }

        public void AddBackofficeFile(string filename)
        {
            var file = new FileInfo(filename);
            if (!file.Exists)
                throw new InvalidOperationException($"The requested file {filename} does not exist");

            var destination = GetBackOfficeFileDestinationDir(file);
            using (var fileStream = file.Open(FileMode.Open))
            {
                AddFile(file.Name, destination, fileStream);
            }
        }

        private string GetBackOfficeFileDestinationDir(FileInfo file)
        {
            var dirs = new Stack<string>();
            var currentDir = file.Directory;
            while (currentDir.Name != "App_Plugins")
            {
                dirs.Push(currentDir.Name);
                currentDir = currentDir.Parent;
            }
            var sb = new StringBuilder();
            sb.Append("/App_Plugins");
            while (dirs.Count > 0)
            {
                sb.Append("/");
                sb.Append(dirs.Pop());  
            }

            return sb.ToString();
        }

        private void AddFile(string filename, string destinationDir, Stream fileStream)
        {
            var filesNode = packageFile.Descendants("files").First();
            filesNode.Add(
                new XElement("file",
                    new XElement("guid", filename),
                    new XElement("orgPath", destinationDir),
                    new XElement("orgName", filename)
            ));

            AddEntryToArchive(filename, fileStream.CopyTo);
        }

        private void AddEntryToArchive(string entryName, Action<Stream> streamAction)
        {
            var entry = archive.CreateEntry(entryName, CompressionLevel.Optimal);
            using (var entryStream = entry.Open())
            {
                streamAction(entryStream);
            }
        }

        public void Done()
        {
            AddEntryToArchive("Package.xml", packageFile.Save);
        }

        public void Dispose()
        {
            ((IDisposable)archive).Dispose();
        }
    }
}
