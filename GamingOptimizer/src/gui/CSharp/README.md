# GamingOptimizer - C# WPF UI

Novo frontend em **C# + WPF (.NET 8)** para melhorar a experiência do usuário.

## 🎯 Arquitetura

```
GamingOptimizer.UI/
├── Views/           # XAML UI Windows
├── ViewModels/      # MVVM ViewModels (CommunityToolkit.MVVM)
├── Services/        # Lógica de negócio
│   ├── PowerShellService.cs    # Integração com scripts PS
│   └── OptimizationService.cs  # Orchestração de tweaks
├── Models/          # Data models
└── Styles/          # Recursos XAML (cores, botões, textos)
```

## ⚙️ Setup

### Pré-requisitos
- .NET 8 SDK ([download](https://dotnet.microsoft.com/download))
- PowerShell 7+ (`pwsh.exe`)
- Windows 10/11

### Compilar

```powershell
cd "src\gui\CSharp\GamingOptimizer.UI"
dotnet build
```

### Executar

```powershell
dotnet run
```

### Build Release (distribua como .exe)

```powershell
dotnet publish -c Release -r win-x64 --self-contained=true
# Output: bin/Release/net8.0-windows/win-x64/publish/GamingOptimizer.exe
```

## 🔌 Integração com PowerShell

A arquitetura permite executar scripts PowerShell existentes:

```csharp
// Injeção de dependência
var psService = serviceProvider.GetRequiredService<IPowerShellService>();

// Executar script
var result = await psService.ExecuteScriptAsync(
    "src/modules/CPUTweaks.ps1",
    new Dictionary<string, string> { { "profile", "competitive" } }
);

if (result.Success)
{
    Console.WriteLine(result.Output);
}
else
{
    Console.WriteLine($"Error: {result.Error}");
}
```

## 🎨 UI Theme

- **Dark mode por padrão** (temas gamers preferem)
- **Cores primárias**: Cyan (#00D9FF), Verde (#00AA00), Vermelho (#CC0000)
- **Responsivo**: Adapta-se a diferentes resoluções
- **Moderno**: Botões com efeitos hover, ícones, etc.

## 📋 Próximos passos

- [ ] Conectar ComboBoxes de profiles
- [ ] Implementar lista de tweaks dinâmica
- [ ] Sistema de logs em tempo real
- [ ] Detecção automática de hardware (CPU/GPU)
- [ ] Temas customizáveis
- [ ] Restauração de pontos

## 🚀 Performance

- **Sem overhead de intérprete**: C# compilado é mais rápido que PowerShell puro
- **Background tasks**: Operações não-bloqueantes na UI
- **Memory efficient**: Cleanup automático via C# GC

---

Para questões técnicas, veja [CONTRIBUTING.md](../../docs/CONTRIBUTING.md)
