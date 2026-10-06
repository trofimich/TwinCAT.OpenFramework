$publicAssemblies = 'C:/Program Files/Beckhoff/TcXaeShell/Common7/IDE/PublicAssemblies'
Add-Type -Path (Join-Path $publicAssemblies 'envdte.dll')
Add-Type -Path (Join-Path $publicAssemblies 'envdte80.dll')
Add-Type -Path (Join-Path $publicAssemblies 'Microsoft.VisualStudio.Interop.dll')
Add-Type -ReferencedAssemblies @((Join-Path $publicAssemblies 'envdte.dll'), (Join-Path $publicAssemblies 'envdte80.dll'), (Join-Path $publicAssemblies 'Microsoft.VisualStudio.Interop.dll')) -TypeDefinition @'
public static class OpenFrameworkXaeDiagnostics
{
    public static EnvDTE80.ErrorList Errors(object dte)
    {
        return ((EnvDTE80.DTE2)dte).ToolWindows.ErrorList;
    }
    public static EnvDTE.OutputWindow Output(object dte)
    {
        return ((EnvDTE80.DTE2)dte).ToolWindows.OutputWindow;
    }
}
'@
