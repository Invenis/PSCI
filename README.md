[![Build status](https://ci.appveyor.com/api/projects/status/eweae6q9yd27kcno/branch/master?svg=true)](https://ci.appveyor.com/project/ObjectivityAdminsTeam/psci/branch/master)

### PSCI - Powershell Continuous Integration / Configuration as Code
-------------
PSCI is a build and deployment automation library that provides a simple Powershell DSC-like language allowing to express configuration as code. The general flow is presented on the image below:
![PSCI overview](https://github.com/ObjectivityBSS/PSCI/wiki/images/PSCI_overview.png)

There are several possibilities to run the deployment code - see [Remoting configuration](https://github.com/ObjectivityBSS/PSCI/wiki/Remoting-configuration) for diagrams:
- Powershell function run on local machine.
- Powershell function run on destination machine.
- DSC configuration run on destination machine.
- Double-hop deployments - e.g. WebDeploy + DSC.

PSCI provides following features:
- Simple DSL to describe Environments, Server Roles, Server Connections and Tokens (per-environment parameters).
- Written entirely in Powershell (requires Powershell 3.0, or 4.0 for DSC support).
- Provisioning mechanism that is based on Powershell Desired State Configuration resources or custom Powershell functions.
- Agentless architecture - deployment to remote environments pushes packages and execute code remotely using Powershell Remoting (WinRM) or Web Deploy.
- Reliable logging mechanism throughout the whole build and deployment process - every step is logged to console, text file and event log (optionally), errors include full stack trace / script lines information and friendly messages.
- Building and deploying various types of packages (MsDeploy - e.g. ASP.NET MVC or WPF, SQL, DbDeploy, Entity Framework Migrations, SSRS, SSAS, SSIS), easily extensible with new types of packages.
- Supports several methods of tokenizing configuration files (e.g. Web.config) - directly replace tokens in files (using regex), transform using XDT (Web.\<env_name\>.config) or use Web Deploy parameterization.
- Supports Windows Server 2008 R2 SP1 / 7 and above (some available DSC resources like xWebsite have been fixed to work with pre-Server 2012).

Additionally, [Objectivity.TeamcityMetarunners](https://github.com/ObjectivityLtd/Objectivity.TeamcityMetarunners) provides a set of TeamCity metarunners that make use of PSCI functions.

#### Why PSCI?

See [Why PSCI](https://github.com/ObjectivityBSS/PSCI/wiki/Why%20PSCI).

#### Where to start?
-------------
- See [Getting started](https://github.com/ObjectivityBSS/PSCI/wiki/Getting-started).
- Checkout the code or get it from [Powershell Gallery](https://www.powershellgallery.com/packages/PSCI) or [nuget](https://www.nuget.org/packages/PSCI/) and use [Powershell Tools for Visual Studio 2015](https://visualstudiogallery.msdn.microsoft.com/c9eb3ba8-0c59-4944-9a62-6eee37294597) or [PsISEProjectExplorer](https://github.com/mgr32/PsISEProjectExplorer) to explore.

