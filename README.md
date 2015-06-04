# Umbraco.Tools
Custom tools to aid Umbraco plugin development and maintenance in general.

These tools are automatically built and depoyled to NuGet by Endzone's AppVeyor account.

##Tooling

###Packager

Generates plugin packages for Umbraco. You give it dlls, back-office files and it updates the Package.xml file and compresses it into a single installable archive.

####Usage
`dnx . package settings.json`

##Running the tools

Tools are written for [DNX](http://docs.asp.net/en/latest/dnx/overview.html) (though you can publish them as standalone executables). You can obtain these tools via NuGet and install them globally into your environment using `dnu commands install`. 
To run the tools look at sample usage eith each tool.

Alternatively you may close this repository and build the tools locally. Make sure to install VS 2015 or manually install DNX to be able to run it. Before running a DNX command you need to restore the dependencies. You can do this by running: `dnu restore`.

