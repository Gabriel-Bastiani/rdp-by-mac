# RDP MAC Finder

Script PowerShell que localiza automaticamente um computador na rede pelo seu **MAC address** e conecta via RDP, resolvendo o problema de IP dinâmico em redes com roteadores mesh ou múltiplos DHCP.

## Problema que resolve

Em redes com modem + roteador mesh, um computador pode receber IPs diferentes dependendo de qual ponto de acesso ele se conecta. Mesmo com DHCP bind configurado no roteador principal, o mesh pode atribuir um IP diferente.

Este script identifica o IP atual pelo MAC (que nunca muda) e conecta automaticamente via RDP.

## Como funciona

1. Consulta a tabela ARP local para encontrar o IP associado ao MAC configurado
2. Verifica se a porta RDP (3389) está acessível
3. Abre o RDP com autenticação automática via Credential Manager
4. Dispara pings em background para estabilizar a conexão durante a autenticação

## Requisitos

- Windows 10 ou superior
- PowerShell 5.1 ou superior
- RDP habilitado no computador alvo

## Configuracao

Edite as linhas no topo do `Conectar-RDP.ps1`:

```powershell
$MAC_ALVO  = "AA:BB:CC:DD:EE:FF"   # MAC do computador que voce quer acessar
$PORTA_RDP = 3389                  # Porta RDP (padrao: 3389)
```

### Como descobrir o MAC do computador alvo

No computador alvo, abra o CMD e rode:
```
ipconfig /all
```
Procure o campo **Endereco Fisico** do adaptador Wi-Fi ou Ethernet.

### Como descobrir sua subnet

No seu computador, abra o CMD e rode:
```
ipconfig
```
O `$SUBNET` no script ja vem configurado para `192.168.1` (padrao da maioria dos roteadores). Ajuste se o seu IPv4 tiver um prefixo diferente.

## Uso

### Primeira execucao
Duplo clique em `Conectar-RDP.bat`. Uma janela pedira usuario e senha RDP — elas serao salvas criptografadas no Windows Credential Manager e nao serao solicitadas novamente.

### Execucoes seguintes
Duplo clique em `Conectar-RDP.bat`. O script localiza o IP e conecta automaticamente.

### Trocar senha ou usuario
Duplo clique em `Resetar-Credencial.bat`. Na proxima execucao normal as novas credenciais serao solicitadas.

## Arquivos

```
Conectar-RDP.ps1       — Script principal
Conectar-RDP.bat       — Atalho para executar sem abrir o PowerShell
Resetar-Credencial.bat — Apaga a credencial salva no Credential Manager
```

## Seguranca

- Nenhuma senha e armazenada em texto puro em nenhum arquivo
- As credenciais ficam no **Windows Credential Manager**, criptografadas pelo proprio sistema operacional, vinculadas ao seu usuario Windows
- A entrada temporaria `TERMSRV/<ip>` criada para o `mstsc` e apagada automaticamente apos 6 segundos
