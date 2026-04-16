<#@ Assembly Name="System.Core" #>
<#@ Import Namespace="System.IO" #>
<#@ Import Namespace="System.Collections.Generic" #>

namespace GamingOptimizer.UI;

public static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        App app = new();
        app.InitializeComponent();
        app.Run();
    }
}
