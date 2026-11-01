#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SigningDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$signingInput=$SigningDirectory
$testRepo=Split-Path $PSScriptRoot -Parent
. (Join-Path $testRepo 'experimental\role-policy\Test-RolePolicy.ps1')
if(-not('Usb4RolePolicy.SignatureCheck' -as [type])){Add-Type -Path (Join-Path $testRepo 'experimental\role-policy\Signing.Native.cs')}
$script:Checks=0
function Check([bool]$Condition,[string]$Label){$script:Checks++;if(-not $Condition){throw ('FAIL: '+$Label)}}
function Reject([scriptblock]$Action,[string]$Label){$yes=$false;try{& $Action|Out-Null}catch{$yes=$true};Check $yes $Label}
function Get-DerLength([byte[]]$Bytes,[int]$Offset){
    if($Bytes[$Offset]-ne 0x30){throw 'Expected DER sequence in signature fixture.'}
    $n=[int]$Bytes[$Offset+1];$header=2
    if($n-ge 128){$count=$n-band 127;if($count-lt 1-or $count-gt 4){throw 'Unexpected DER length.'};$n=0;for($i=0;$i-lt $count;$i++){$n=($n-shl 8)-bor $Bytes[$Offset+2+$i]};$header+=$count}
    if($n-lt 0-or $Offset+$header+$n-gt $Bytes.Length){throw 'Signature fixture bounds.'}
    return $header+$n
}
$recordPath=Join-Path $signingInput 'signing.private.json'
$signed=Get-Content -LiteralPath $recordPath -Raw|ConvertFrom-Json
$cert=Join-Path $signingInput 'LocalTest.cer';$sys=Join-Path $signingInput 'package\Usb4RolePolicy.sys';$cat=Join-Path $signingInput 'package\Usb4RolePolicy.cat';$inf=Join-Path $signingInput 'package\Usb4RolePolicy.inf'
$root=Join-Path $testRepo ('local\RolePolicySigning\checks-'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($root)
$before=[Usb4RolePolicy.SignatureCheck]::CodeIntegrityFlags()
Check $signed.PrivateKeyRemoved 'temporary signing key removed'
Check (-not(Test-Path ('Cert:\CurrentUser\My\'+$signed.CertificateThumbprint))) 'no remaining signing private certificate'
foreach($store in @('Root','TrustedPublisher')){Check (-not(Test-Path ('Cert:\LocalMachine\'+$store+'\'+$signed.CertificateThumbprint))) ('no production trust '+$store)}
foreach($file in @($sys,$cat)){[Usb4RolePolicy.SignatureCheck]::VerifySignatureMath($file,$cert);Check $true 'actual signature math'}
foreach($file in @($sys,$inf)){Check ([Usb4RolePolicy.SignatureCheck]::CatalogContains($cat,$file)) 'actual catalog membership'}
$bytes=[IO.File]::ReadAllBytes($sys);$pe=[BitConverter]::ToInt32($bytes,0x3c);$opt=$pe+24
$section=$opt+[BitConverter]::ToUInt16($bytes,$pe+20)
$code=[BitConverter]::ToInt32($bytes,$section+20)
$changed=[byte[]]$bytes.Clone();$changed[$code]=$changed[$code]-bxor 1
$bad=Join-Path $root 'modified-code.sys';[IO.File]::WriteAllBytes($bad,$changed)
Check (-not [Usb4RolePolicy.SignatureCheck]::CatalogContains($cat,$bad)) 'modified executable rejected by signed catalog digest'
$certificateOffset=[BitConverter]::ToInt32($bytes,$opt+144);$cmsEnd=$certificateOffset+8+(Get-DerLength $bytes ($certificateOffset+8))-1
$changed=[byte[]]$bytes.Clone();$changed[$cmsEnd]=$changed[$cmsEnd]-bxor 1
$badSignature=Join-Path $root 'modified-signature.sys';[IO.File]::WriteAllBytes($badSignature,$changed)
Reject {[Usb4RolePolicy.SignatureCheck]::VerifySignatureMath($badSignature,$cert)} 'modified embedded signature rejected'
$catBytes=[IO.File]::ReadAllBytes($cat);$catEnd=(Get-DerLength $catBytes 0)-1;$catBytes[$catEnd]=$catBytes[$catEnd]-bxor 1
$badCat=Join-Path $root 'modified-catalog.cat';[IO.File]::WriteAllBytes($badCat,$catBytes)
Reject {[Usb4RolePolicy.SignatureCheck]::VerifySignatureMath($badCat,$cert)} 'modified catalog signature rejected'
Reject {Assert-RpSignedPackage (Split-Path $sys -Parent) (Get-FileHash -LiteralPath $sys).Hash ''} 'production gate refuses real local-test package'
for($i=0;$i-lt 8;$i++){
    $security=[pscustomobject]@{SecureBoot=[bool]($i-band 1);TestSigning=[bool]($i-band 2);Hvci=[bool]($i-band 4)}
    Check ((Test-RpLocalSecurity $security) -eq ($i-eq 6)) 'only explicit test mode with HVCI running accepted'
}
$preview=& (Join-Path $testRepo 'experimental\role-policy\Sign-RolePolicy.ps1')
Check ($preview -match 'No root/publisher trust') 'actual signing Preview'
$preview=& (Join-Path $testRepo 'experimental\role-policy\Prepare-LocalTestBoot.ps1')
Check ($preview -match 'Snapshot saves') 'actual boot Preview'

# Real CLI argument preservation, without reaching privilege/device operations.
$process=New-Object Diagnostics.Process;$process.StartInfo=New-Object Diagnostics.ProcessStartInfo
$process.StartInfo.FileName=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$process.StartInfo.Arguments='-NoProfile -ExecutionPolicy Bypass -File '+(Quote-NativeArgument (Join-Path $testRepo 'experimental\role-policy\Test-RolePolicy.ps1'))+' -Mode Rollback -RunDirectory '+(Quote-NativeArgument $root)
$process.StartInfo.UseShellExecute=$false;$process.StartInfo.CreateNoWindow=$true;$process.StartInfo.RedirectStandardOutput=$true;$process.StartInfo.RedirectStandardError=$true
$null=$process.Start();$cli=$process.StandardOutput.ReadToEnd()+$process.StandardError.ReadToEnd();$process.WaitForExit()
Check ($cli -match 'Run must be inside the owned') 'saved run CLI argument survives imported parameter blocks'
$process.Dispose()

# Boot workflow doubles: no BCD, certificate trust or administrator operation executes.
$script:Original='{11111111-1111-4111-8111-111111111111}';$script:TestId='{22222222-2222-4222-8222-222222222222}'
$script:Current=$script:Original;$script:Entry=$false;$script:Label='';$script:FailCopyReply=$false;$script:FailDelete=$false;$script:WrongCopyId=$false
$script:Trust=@{};$script:BcdCalls=New-Object 'Collections.Generic.List[string]'
$script:Security=[pscustomobject]@{SecureBoot=$true;TestSigning=$false;Hvci=$true;Flags=$before}
function Assert-PolicyAdmin {}
function Assert-PolicyNoOldOverrides {}
function Get-DeepCaptureContext {return [pscustomobject]@{MachineHash='TEST'}}
function Get-DeepMachineHash {return 'TEST'}
function Get-PolicySecurity {return $script:Security}
function Test-PolicyTrust([string]$Store,[string]$Thumbprint){return $script:Trust.ContainsKey($Store)}
function Add-PolicyTrust([string]$Store,[string]$Certificate){$script:Trust[$Store]=$true}
function Remove-PolicyTrust([string]$Store,[string]$Thumbprint){$script:Trust.Remove($Store)}
function Read-Host {return 'PREPARE'}
function Get-WindowsDriver {return @()}
function Get-CimInstance {return $null}
function Invoke-PolicyBcd([string[]]$Arguments){
    $script:BcdCalls.Add(($Arguments-join '|'))
    if($Arguments[0]-eq '/copy'){$script:Entry=$true;$script:Label=$Arguments[3];if($script:FailCopyReply){return 'Reply omitted ID'};if($script:WrongCopyId){return ('Copied '+$script:Original)};return ('Copied '+$script:TestId)}
    if($Arguments[0]-eq '/delete'){if($script:FailDelete){throw 'mock interrupted deletion'};$script:Entry=$false;return 'Deleted'}
    if($Arguments[0]-eq '/set'){return 'Set test flag'}
    if($Arguments[1]-eq '{current}'){return ('Loader '+$script:Current)}
    if($Arguments[1]-eq '{bootmgr}'){return ('Boot manager original'+$(if($script:Entry){' '+$script:TestId}else{''}))}
    if($Arguments[1]-eq $script:TestId){return ('Windows loader '+$script:TestId+"`r`nDescription "+$script:Label)}
    return ('Windows loader '+$script:Original+"`r`nDescription Original`r`n`r`n"+$(if($script:Entry){'Windows loader '+$script:TestId+"`r`nDescription "+$script:Label}else{''}))
}
$state=Join-Path $root 'boot.private.json'
Invoke-LocalTestBoot 'Snapshot' $recordPath $state
Check (-not $script:Entry -and $script:Trust.Count-eq 0) 'snapshot makes no BCD/trust mutation'
Reject {Invoke-LocalTestBoot 'Prepare' '' $state} 'Secure Boot on blocks test preparation'
$script:Security.SecureBoot=$false;$script:Security.Hvci=$false
Reject {Invoke-LocalTestBoot 'Prepare' '' $state} 'HVCI off blocks preparation'
$script:Security.Hvci=$true
Invoke-LocalTestBoot 'Prepare' '' $state
$saved=Get-Content -LiteralPath $state -Raw|ConvertFrom-Json
Check ($saved.Phase-eq 'Prepared' -and $saved.TestEntry-eq $script:TestId -and $script:Trust.Count-eq 2) 'one owned entry and exact trust prepared'
Check ($script:BcdCalls.Contains('/set|'+$script:TestId+'|testsigning|on')) 'test flag targets only copied entry'
Check (-not @($script:BcdCalls|Where-Object {$_-match '/default|bootsequence|nointegritychecks|hypervisorlaunchtype'}).Count) 'original loader/default and other security flags untouched'
Reject {Invoke-LocalTestBoot 'Prepare' '' $state} 'no duplicate preparation'
$script:FailDelete=$true
Reject {Invoke-LocalTestBoot 'Restore' '' $state} 'interrupted deletion retains record'
Check $script:Entry 'entry remains after mocked failed delete'
$script:FailDelete=$false
Invoke-LocalTestBoot 'Restore' '' $state
Check (-not $script:Entry -and $script:Trust.Count-eq 0) 'owned entry and trust removed'
Reject {Invoke-LocalTestBoot 'Verify' '' $state} 'Secure Boot restoration not falsely claimed'
$script:Security.SecureBoot=$true
Invoke-LocalTestBoot 'Verify' '' $state
Check ((Get-Content -LiteralPath $state -Raw|ConvertFrom-Json).Phase-eq 'OriginalSecurityVerified') 'original security verified in mock'
$state2=Join-Path $root 'interrupted-copy.private.json'
Invoke-LocalTestBoot 'Snapshot' $recordPath $state2
$script:Security.SecureBoot=$false;$script:FailCopyReply=$true
Reject {Invoke-LocalTestBoot 'Prepare' '' $state2} 'copy identity failure is pending'
Invoke-LocalTestBoot 'Restore' '' $state2
Check (-not $script:Entry) 'unique saved label recovers interrupted copy'
$script:Security.SecureBoot=$true;$script:FailCopyReply=$false;$script:WrongCopyId=$true
$state3=Join-Path $root 'wrong-copy-id.private.json';Invoke-LocalTestBoot 'Snapshot' $recordPath $state3
$script:Security.SecureBoot=$false
Reject {Invoke-LocalTestBoot 'Prepare' '' $state3} 'original loader returned as copy ID is refused'
Check (-not $script:BcdCalls.Contains('/set|'+$script:Original+'|testsigning|on')) 'original loader never receives test flag'
Invoke-LocalTestBoot 'Restore' '' $state3
Check ([Usb4RolePolicy.SignatureCheck]::CodeIntegrityFlags()-eq $before) 'actual code-integrity flags unchanged by tests'
Check (-not(Test-Path ('Cert:\LocalMachine\Root\'+$signed.CertificateThumbprint))) 'actual root trust unchanged'
[pscustomobject]@{Checks=$script:Checks;Actual='Signature math, catalog membership, corruption refusal, signing-key cleanup, production refusal, CLI argument, security read';Mocked='BCD, root/publisher trust, administrator, reboot context';DriverLoaded=$false}|ConvertTo-Json
