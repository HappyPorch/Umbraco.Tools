#Umbraco.Tools
Custom tools to aid Umbraco plugin development and maintenance in general.

These tools are automatically built and deployed to NuGet by Endzone.io's AppVeyor account.

##Building the Solution
We use Visual Studio 2015 RTM with [Microsoft ASP.NET and Web Tools 2015 (Beta6) – Visual Studio 2015](http://www.microsoft.com/en-us/download/details.aspx?id=48222).

##Tooling

###Packager

Generates plugin packages for Umbraco. You give it dlls, back-office files and it updates the Package.xml file and compresses it into a single installable archive.

####Usage
`dnx . package settings.json`

##Running the tools

Tools are written for [DNX](http://docs.asp.net/en/latest/dnx/overview.html) (though you can publish them as standalone executables). You can obtain these tools via NuGet and install them globally into your environment using `dnu commands install`. 
To run the tools look at sample usage with each tool.

Alternatively you may close this repository and build the tools locally. Make sure to install VS 2015 or manually install DNX to be able to run it. Before running a DNX command you need to restore the dependencies. You can do this by running: `dnu restore`.

