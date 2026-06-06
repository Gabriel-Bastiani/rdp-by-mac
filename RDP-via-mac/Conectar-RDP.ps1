# ============================================================
#  Conectar-RDP.ps1
#  Localiza um computador na rede pelo MAC address e conecta via RDP
#  Credenciais gerenciadas pelo Windows Credential Manager
# ============================================================
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ── CONFIGURACOES ────────────────────────────────────────────
$MAC_ALVO       = "AA:BB:CC:DD:EE:FF"   # <-- Altere para o MAC do computador alvo
$PORTA_RDP      = 3389
$CRED_LABEL     = "RDP-MAC-ALVO"        # Nome da entrada no Credential Manager (nao altere)
# ────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Localizador RDP por MAC Address" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""


# ── PASSO 0: Gerenciar credenciais no Credential Manager ─────

function Salvar-Credencial {
    Write-Host "Nenhuma credencial salva para '$CRED_LABEL'." -ForegroundColor Yellow
    Write-Host "Informe as credenciais RDP (serao salvas no Windows Credential Manager):" -ForegroundColor Cyan
    Write-Host ""

    $cred = Get-Credential -Message "Credenciais RDP para o computador alvo"

    if (-not $cred) {
        Write-Host "[ERRO] Nenhuma credencial informada. Encerrando." -ForegroundColor Red
        exit 1
    }

    $usuario = $cred.UserName
    $senhaTexto = $cred.GetNetworkCredential().Password

    Start-Process -FilePath "cmdkey.exe" `
        -ArgumentList "/generic:$CRED_LABEL /user:$usuario /pass:$senhaTexto" `
        -WindowStyle Hidden -Wait

    Write-Host ""
    Write-Host "Credenciais salvas com sucesso para '$CRED_LABEL'." -ForegroundColor Green
    Write-Host ""

    return @{ Usuario = $usuario; Senha = $senhaTexto }
}

function Ler-Credencial {
    $existe = cmdkey /list | Select-String -SimpleMatch $CRED_LABEL

    if (-not $existe) {
        return $null
    }

    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class CredManager {
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern bool CredRead(string target, uint type, uint flags, out IntPtr credential);

    [DllImport("advapi32.dll")]
    public static extern void CredFree(IntPtr buffer);

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CREDENTIAL {
        public uint Flags;
        public uint Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static string[] GetCredential(string target) {
        IntPtr ptr;
        if (!CredRead(target, 1, 0, out ptr)) return null;
        var cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
        string password = "";
        if (cred.CredentialBlobSize > 0) {
            password = Marshal.PtrToStringUni(cred.CredentialBlob, (int)(cred.CredentialBlobSize / 2));
        }
        string user = cred.UserName ?? "";
        CredFree(ptr);
        return new string[] { user, password };
    }
}
"@ -ErrorAction SilentlyContinue

        $dados = [CredManager]::GetCredential($CRED_LABEL)
        if ($dados -and $dados[0]) {
            return @{ Usuario = $dados[0]; Senha = $dados[1] }
        }
    } catch { }

    return $null
}

function Apagar-Credencial {
    Start-Process -FilePath "cmdkey.exe" -ArgumentList "/delete:$CRED_LABEL" -WindowStyle Hidden -Wait
    Write-Host "Credenciais removidas do Credential Manager." -ForegroundColor Yellow
}

if ($args -contains "-resetcred") {
    Apagar-Credencial
    Write-Host "Na proxima execucao, novas credenciais serao solicitadas." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Pressione qualquer tecla para sair..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 0
}

$credencial = Ler-Credencial
if (-not $credencial) {
    $credencial = Salvar-Credencial
}

$USUARIO_RDP = $credencial.Usuario
$SENHA_RDP   = $credencial.Senha

Write-Host "Usuario  : $USUARIO_RDP" -ForegroundColor Yellow
Write-Host "MAC alvo : $MAC_ALVO" -ForegroundColor Yellow
Write-Host ""

$MAC_NORMALIZADO = $MAC_ALVO.ToUpper() -replace "[:\-\.]", ""


# ── PASSO 1: Ler a tabela ARP e buscar o MAC ─────────────────
Write-Host "[1/2] Consultando tabela ARP..." -ForegroundColor Cyan

$IP_ENCONTRADO  = $null
$tentativas     = 0
$MAX_TENTATIVAS = 3

do {
    $tentativas++
    if ($tentativas -gt 1) {
        Write-Host "  Tentativa $tentativas de $MAX_TENTATIVAS..." -ForegroundColor DarkYellow
        Start-Sleep -Seconds 2
    }

    $arpOutput = arp -a

    foreach ($linha in $arpOutput) {
        if ($linha -match "(\d+\.\d+\.\d+\.\d+)\s+([\da-f]{2}[-:][\da-f]{2}[-:][\da-f]{2}[-:][\da-f]{2}[-:][\da-f]{2}[-:][\da-f]{2})") {
            $ipLinha  = $matches[1]
            $macLinha = $matches[2].ToUpper() -replace "[:\-]", ""

            if ($macLinha -eq $MAC_NORMALIZADO) {
                $IP_ENCONTRADO = $ipLinha
                break
            }
        }
    }

} while (-not $IP_ENCONTRADO -and $tentativas -lt $MAX_TENTATIVAS)


# ── PASSO 2: Conectar via RDP ─────────────────────────────────
if ($IP_ENCONTRADO) {
    Write-Host ""
    Write-Host "[2/2] MAC encontrado!" -ForegroundColor Green
    Write-Host "  IP: $IP_ENCONTRADO" -ForegroundColor Green
    Write-Host ""

    Write-Host "  Verificando porta RDP ($PORTA_RDP)..." -ForegroundColor Cyan
    $portaAberta = Test-NetConnection -ComputerName $IP_ENCONTRADO -Port $PORTA_RDP -WarningAction SilentlyContinue

    if ($portaAberta.TcpTestSucceeded) {
        Write-Host "  Porta RDP aberta. Conectando..." -ForegroundColor Green
        Write-Host ""

        Start-Process -FilePath "cmdkey.exe" `
            -ArgumentList "/generic:TERMSRV/$IP_ENCONTRADO /user:$USUARIO_RDP /pass:$SENHA_RDP" `
            -WindowStyle Hidden -Wait

        # Abre o RDP
        Start-Process -FilePath "mstsc.exe" -ArgumentList "/v:$IP_ENCONTRADO /f"

        # Ping em background enquanto o RDP esta autenticando
        Start-Job -ScriptBlock {
            param($ip)
            ping -n 5 -w 1000 $ip | Out-Null
        } -ArgumentList $IP_ENCONTRADO | Out-Null

        # Aguarda o mstsc iniciar antes de limpar a entrada temporaria
        Start-Sleep -Seconds 6
        Start-Process -FilePath "cmdkey.exe" `
            -ArgumentList "/delete:TERMSRV/$IP_ENCONTRADO" `
            -WindowStyle Hidden

    } else {
        Write-Host ""
        Write-Host "[AVISO] Porta RDP ($PORTA_RDP) fechada ou inacessivel em $IP_ENCONTRADO" -ForegroundColor Red
        Write-Host "  Verifique se o RDP esta habilitado no computador alvo." -ForegroundColor Red
    }

} else {
    Write-Host ""
    Write-Host "[ERRO] MAC $MAC_ALVO nao encontrado na rede apos $MAX_TENTATIVAS tentativas." -ForegroundColor Red
    Write-Host ""
    Write-Host "Possiveis causas:" -ForegroundColor Yellow
    Write-Host "  - O computador alvo esta desligado ou em sleep" -ForegroundColor Yellow
    Write-Host "  - Ele esta conectado em uma sub-rede diferente" -ForegroundColor Yellow
    Write-Host "  - O MAC informado esta incorreto" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Dica: rode 'arp -a' no terminal para ver a tabela ARP atual." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")