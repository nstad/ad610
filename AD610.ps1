configuration NewDomain             
{     
   
    Node localhost             
    {             
            
        LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true            
        }            
            
        File ADFiles            
        {            
            DestinationPath = 'C:\NTDS'            
            Type = 'Directory'            
            Ensure = 'Present'            
        }   
        
         WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"		
        }

        WindowsFeature DnsTools
	    {
	        Ensure = "Present"
            Name = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]DNS"
	    }      
                    
        WindowsFeature ADDSInstall             
        {             
            Ensure = "Present"             
            Name = "AD-Domain-Services"
            DependsOn="[WindowsFeature]DNS"     
        }            
            
        # Optional GUI tools            
        WindowsFeature ADDSTools            
        {             
            Ensure = "Present"             
            Name = "RSAT-ADDS"
            DependsOn="[WindowsFeature]ADDSInstall"              
        }            
            
        # No slash at end of folder paths            
        Script NewForest             
        {    
            TestScript = { Test-Path C:\NTDS\ADFinish.txt } 
            #GetScript =  { @{Result = $true} }           
            SetScript = {
                        Install-ADDSForest -DomainName saplab.local -DomainNetBiosName saplab -DomainMode WinThreshold -ForestMode WinThreshold -SkipPreChecks -InstallDns:$true -SafeModeAdministratorPassword (ConvertTo-SecureString -AsPlainText "Pa55w.rd1234" -Force)
                        New-Item C:\NTDS\ADFinish.txt
                        Sleep 10
                        #Restart-Computer -Force
                        $global:DSCMachineStatus = 1
                        }
            GetScript = { return @{result = 'result'}}
            DependsOn = "[WindowsFeature]ADDSInstall","[File]ADFiles","[WindowsFeature]ADDSTools"            
        }    
        
        Script SetDNSServerSettings
        {
        TestScript = { Test-Path C:\NTDS\DNSFinish.txt } 
        GetScript =  { @{Result = $true} }
        SetScript = {
          Add-DnsServerResourceRecordA -Name "tstew1sapad" -ZoneName "saplab.local" -AllowUpdateAny -IPv4Address "10.0.0.4"
          Add-DnsServerResourceRecordA -Name "tstew1sapapp" -ZoneName "saplab.local" -AllowUpdateAny -IPv4Address "10.0.1.4" 
          Add-DnsServerResourceRecordA -Name "tstew1sapdb" -ZoneName "saplab.local" -AllowUpdateAny -IPv4Address "10.0.1.5"
          New-Item C:\NTDS\DNSFinish.txt
                    }
             
        DependsOn = "[Script]NewForest"
        }

        Script CreateDNSZone
        {
        TestScript = { Test-Path C:\NTDS\DNSZoneFinish.txt } 
        GetScript =  { @{Result = $true} }
        SetScript = {
          sleep 20
          Add-DnsServerPrimaryZone -NetworkId "10.0.0.0/16" -ReplicationScope Forest  
          sleep 10 
          New-Item C:\NTDS\DNSZoneFinish.txt
                    }
             
        DependsOn = "[Script]SetDNSServerSettings"
        }

        Script CreatePTRRecords
        {
        TestScript = { Test-Path C:\NTDS\DNSPTRFinish.txt } 
        GetScript =  { @{Result = $true} }
        SetScript = {
          Add-DnsServerResourceRecordPtr -Name "4.0" -ZoneName "0.10.in-addr.arpa" -AllowUpdateAny -PtrDomainName "tstew1sapad.saplab.local"
          Add-DnsServerResourceRecordPtr -Name "4.1" -ZoneName "0.10.in-addr.arpa" -AllowUpdateAny -PtrDomainName "tstew1sapapp.saplab.local"
          Add-DnsServerResourceRecordPtr -Name "5.1" -ZoneName "0.10.in-addr.arpa" -AllowUpdateAny -PtrDomainName "tstew1sapdb.saplab.local"
          New-Item C:\NTDS\DNSPTRFinish.txt
                    }
        DependsOn = "[Script]CreateDNSZone"
        }

        Script ADJoin             
        {    
            TestScript = { Test-Path C:\NTDS\ADjoinFinish.txt } 
            GetScript =  { @{Result = $true} }           
            SetScript = {
                        $password = ConvertTo-SecureString "AD661!Pa55w.rd" -AsPlainText -Force
                        $cred= New-Object System.Management.Automation.PSCredential ("local-adm", $password )
                        Enter-PSSession 10.0.1.4 -Credential $cred 
                        $passwordAD = ConvertTo-SecureString "AD661!Pa55w.rd" -AsPlainText -Force
                        $adcred = New-Object System.Management.Automation.PSCredential ("saplab\ad-adm", $passwordAD )
                        Add-Computer -DomainName saplab.local -Credential $adcred
                        Sleep 10
                        exit
                        Restart-Computer 10.0.0.4 -Credential $cred
                        New-Item C:\NTDS\ADjoinFinish.txt
                        }          
            DependsOn = "[Script]NewForest"            
        }    
            
            
    }             
}            
                    
#Create MOF Files
NewDomain
            
# Make sure that LCM is set to continue configuration after reboot            
Set-DSCLocalConfigurationManager -Path .\NewDomain –Verbose            
            
# Build the domain            
Start-DscConfiguration -Wait -Force -Path .\NewDomain -Verbose