# Keyboard Input Lag Tweaks

Conjunto de tweaks para reduzir latencia de teclado no Windows, prontos para executar.

## O que e aplicado
- `KeyboardDelay = 0` e `KeyboardSpeed = 31` (resposta mais rapida de repeticao)
- Desativacao de Sticky Keys, Toggle Keys e Filter Keys (evita atrasos e hooks de acessibilidade)
- Ajuste de `KeyboardDataQueueSize` para reduzir perdas de input em carga alta
- Desativacao de USB Selective Suspend no plano de energia atual (evita wake-up delay de dispositivos USB)

## Como executar
1. Abrir PowerShell como Administrador.
2. Navegar para esta pasta.
3. Aplicar tweaks:

```powershell
.\Apply-KeyboardInputLagTweaks.ps1
```

Ou com duplo clique no launcher:

```cmd
Apply-KeyboardInputLagTweaks.cmd
```

4. (Opcional) Nao mexer em energia USB:

```powershell
.\Apply-KeyboardInputLagTweaks.ps1 -SkipPowerTweaks
```

## Reverter
O script de apply cria backup automatico em `backups/input-lag-keyboard/`.

Para reverter o backup mais recente:

```powershell
.\Revert-KeyboardInputLagTweaks.ps1
```

Ou com duplo clique no launcher:

```cmd
Revert-KeyboardInputLagTweaks.cmd
```

Para reverter um backup especifico:

```powershell
.\Revert-KeyboardInputLagTweaks.ps1 -BackupFile "C:\caminho\backup.json"
```

## Nota
- Reinicio recomendado apos aplicar ou reverter.
- Estes tweaks focam-se em input lag de teclado e podem ter impacto diferente conforme hardware/driver.
