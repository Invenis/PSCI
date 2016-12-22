
# TODO: 
# * define token path separator "." as const and use it in various places instead of inline literal
# * write unit tests    


# facade - entry point that exposes API to operate on scoped tokens hierarchy
Class TokenContainer {

    EnvironmentTokens([string] $ContainerId)  {
        $this.ContainerId = $ContainerId
    }
    
    [string] $ContainerId
    [TokenScope] $Tokens = [TokenScope]::CreateRootScope()

    [array] GetCategories() {
        return $this.Tokens.GetInnerScopes()
    }
 
    [TokenScope] AddCategory([string] $Name) {
        return $this.Tokens.CreateInnerScope($Name)        
    }    
    
    [void] Override([string] $TokenReference, [string] $NewValue) {
        $override = [TokenOverride]::new($TokenReference, $NewValue)
        $override.ApplyTo($this.Tokens)
    } 
    
    [void] OverrideTokens([hashtable] $Overrides) {        
        $this.Tokens.OverrideTokens($Overrides) 
    }      
    
    
    [hashtable] ToHashTable() {
        return $this.Tokens.ToHashTable()
    }     
}
    

Class TokenScope {

    static [TokenScope] CreateRootScope() {
        return [TokenScope]::new("$", $null)
    }

    TokenScope([string] $Name, [TokenScope] $ParentScope)
    {
        $this.Name = $Name        
        $this.FullName = if ($ParentScope) { "$($ParentScope.FullName).$Name" } else { $Name }
        $this.ParentScope = $ParentScope
    }
    
    [string] $Name
    [string] $FullName
    [TokenScope] $ParentScope
    [hashtable] $InnerScopes = @{}
    [hashtable] $Tokens = @{}

    [TokenScope] CreateInnerScope([string] $Name) {        
        $innerScope = [TokenScope]::new($Name, $this)
        $this.InnerScopes.Add($Name, $innerScope)
        return $innerScope
    }

    [array] GetInnerScopes() {
        return $this.InnerScopes.Values
    }     

    [TokenScope] GetRootScope() {
        $result = $this
        
        while ($result.ParentScope) { $result = $result.ParentScope }

        return $result
    }

    [Token] AddToken([string] $Name, [object] $Value) {

        $tokenFullName = "$($this.FullName).$Name"
        $token = [Token]::new($tokenFullName, $Value)
        $this.Tokens.Add($Name, $token)
        return $token
    }

    [Token] GetToken([TokenPath] $RelativePath) {                   
        return $RelativePath.GetToken($this)
    }
            
    [bool] TokenExists([TokenPath] $RelativePath) {
        return $RelativePath.Exists($this)
    }

    [void] OverrideTokens([hashtable] $overrides) {
        
        $overrides.Keys | ForEach {            
            
            $overridenKey = $_
            $newValue = $overrides[$overridenKey]

            if ($newValue -is [hashtable]) {
                
                if (-not $this.InnerScopes.ContainsKey($overridenKey)) {
                    $this.CreateInnerScope($overridenKey)
                }

                $this.InnerScopes[$overridenKey].Override($newValue)
                
            } else { # override token - create new or override existing value
                
                if ($this.Tokens.ContainsKey($overridenKey)) {
                    $this.Tokens[$overridenKey].OverrideValue($newValue)
                } else {
                    $this.AddToken($overridenKey, $newValue)
                }
            }
        }
    }

    # converts the token scope model to hashtable
    [hashtable] ToHashTable() {
        $result = @{}

        $this.InnerScopes.Values | ForEach { $result.Add($_.Name, $_.ToHashTable()) }
        $this.Tokens.Values | ForEach { $result.Add($_.FullName, $_.RawValue) }
        
        return $result         
    } 
}


Class Token {

    Token($FullName, $RawValue) {
        $this.FullName = $FullName
        $this.RawValue = $RawValue
    }

    [string] $FullName
    [object] $RawValue

    UpdateValue([object] $NewValue) {
        $this.UpdateValue($NewValue, $null)
    }

    UpdateValue([object] $NewValue, [string] $TokenMemberExpression) {
        try { 
           
            if ($TokenMemberExpression) {
                # update using dynamically composed expression when reference to token is provided
                 Invoke-Expression -Command "`$this.RawValue$TokenMemberExpression = `$NewValue"                 
            }
            else {
                $this.RawValue = $NewValue
            }                        
                   
        } catch {
            throw "Failed to override token '$($this.FullName) = $NewValue'. Error message: $($_.Exception.Message)"
        }
    }

    [object] GetValue([string] $TokenMemberExpression) {
        return Invoke-Expression -Command "`$this.RawValue$TokenMemberExpression"
    }
}

class TokenOverride {       

    TokenOverride([string] $Reference, [string] $Value) {

        $this.Value = [TokenOverride]::Parse($Value)
               
        # TODO: token reference concept may deserve for a dedicated, simple class which
        # will take away all details of playing with plain string in here
        if ($Reference -match [TokenOverride]::ReferencePattern) {
            $this.TokenPath = [TokenPath]::new($Matches["tokenPath"])
            $this.IsObjectMemberAccess = $Matches["objectMemberAccess"]
            $this.TokenMemberExpression = $Matches["tokenMemberExpression"]
        } else {
            throw "Unrecognized TokenOverride syntax: $Reference = $Value"
        }                  
    }

    # reference is token path + optional expression accessing token type specific member
    # if token is object, then reference can contain "=>" to access object property e.g. SomeScope.SomeObjectTypeToken=>ObjectProperty    
    [string] static $ReferencePattern = "^(?<tokenPath>[\w-]+(\.[\w-]+)*)(<objectMemberAccess>\=>)?(?<tokenMemberExpression>.*)"

    [TokenPath] $TokenPath
    [bool] $IsObjectMemberAccess
    [string] $TokenMemberExpression
    [object] $Value

    [bool] static IsValidTokenReferenceSyntax([string] $Reference) {
        return $Reference -match [TokenOverride]::ReferencePattern
    }

    static [object] Parse($Value) {
        if (!$Value) {
            return $Value
        }

        if ($Value -ieq '$true') {
            return $true
        }

        if ($Value -ieq '$false') {
            return $false
        }

        if ($Value -match '^{\s+.+\s+}$') {
            return [ScriptBlock]::Create($Value)
        }
    
        return $Value 
    }

    [void] ApplyTo([TokenScope] $Context) {

        $targetTokens = $this.LookupTokensToOverride($Context)

        if ($targetTokens.Count) {
            $targetTokens | ForEach { $_.UpdateValue($this.Value) }
        } else {
            Write-Warning "Could not override token '$($this.TokenPath.FullPath)'. Token has not been found."
        }        
    }

    [array] LookupTokensToOverride([TokenScope] $Context) {

        $lookup = [InnerScopeTokenLookup]::new($this.TokenPath)
        return $lookup.GetTokens($Context)
    }
}


Class ScopePath {

    ScopePath([string] $Path) {   
    
        #todo: validate path syntax 
         
        $this.ScopeNames = if ([string]::IsNullOrEmpty($Path)) { @() } else { $Path.Split(".") }
    }

    static [string] $RootScopeName = "$"        
    [array] $ScopeNames

    [bool] IsRelative() {
        return ($this.ScopeNames | Select -First 1) -ne [ScopePath]::RootScopeName
    }

    [bool] Exists([TokenScope] $Context) {
        return $this.GetTargetScope($Context) -ne $null
    }
        
    [TokenScope] GetTargetScope([TokenScope] $Context) {
        $targetScope = $Context

        $this.ScopeNames | ?{$_} | ForEach { 
                $targetScope = if ($targetScope) { 
                        if ($_ -eq $this.RootScopeName) { $Context.GetRootScope() } else { $targetScope.InnerScopes[$_] }                        
                    } else { 
                        $null 
                    } 
            }
                
        return $targetScope    
    }
}


Class TokenPath {

    TokenPath([string] $Path) {     

        #todo: validate path syntax                

        if ($Path.Contains(".")) { # complex path - at least one "." separator
            $tokenNameSeparatorIndex = $Path.LastIndexOf(".")
            $this.TokenName = $Path.Substring($tokenNameSeparatorIndex+1)        
            $this.ScopePath = [ScopePath]::new($Path.Substring(0, $tokenNameSeparatorIndex))
        } else { # path is simple token name
            $this.TokenName = $Path  
            $this.ScopePath = [ScopePath]::new("")          
        }

        $this.FullPath = $Path
    }

    [string] $FullPath
    [string] $TokenName
    [ScopePath] $ScopePath

    [bool] IsRelative() {
        return $this.ScopePath.IsRelative()
    }

    [bool] Exists([TokenScope] $SearchRootScope) {
        return $this.GetToken($SearchRootScope) -ne $null
    }

    [Token] GetToken([TokenScope] $SearchRootScope) { 
        
        $targetScope = $this.ScopePath.GetTargetScope($SearchRootScope)

        if ($targetScope) { 
            return $targetScope.Tokens[$This.TokenName] 
        } else { 
            return $null
        }
    }
}


# defines strategy of token lookup in the scopes tree
Class TokenLookup {
    [array] GetTokens([TokenScope] $Context) {
        throw 'Not implemented'
    }
}


# lookups token by path (rooted or relative) in the context of specified scope,
# If provided lookup path is relative, then it additionally tries to lookup tokens directly in inner scopes of given context scope using the same path
Class InnerScopeTokenLookup : TokenLookup {

    InnerScopeTokenLookup([string] $Path) {
        $this.Path = [TokenPath]::new($Path)
    }

    InnerScopeTokenLookup([TokenPath] $Path) {
        $this.Path = $Path
    }

    [TokenPath] $Path

    [array] GetTokens([TokenScope] $Context) {
    
        $result = @()

        if ($Context.TokenExists($this.Path)) {
            $result += $Context.GetToken($this.Path)
        }

        # if path is relative (not rooted explicitly) we also try to obtain tokens using the same path on inner scopes, but no more than one level deep
        if ($this.Path.IsRelative()) {
            $innerScopeTokens = $Context.GetInnerScopes() | Where { $_.TokenExists($this.Path) } | %{ $_.GetToken($this.Path) }          
            $result += $innerScopeTokens            
        }  
        
        return $result      
    }
}


# UNIT TESTS



Describe “TokenPath" {


    It "create simple path" {

        $path = [TokenPath]::new("Token1")

        $path.TokenName | Should Be "Token1"
        $path.ScopePath | Should Not Be $null
    }

    It "create multipart path" {

        $path = [TokenPath]::new("RootCategory.S1.S2.S3.S4.S5.Token1")

        $path.TokenName | Should Be "Token1"
        $path.ScopePath | Should Not Be $null
    }

    It "IsRelative for simple path" {

        $path = [TokenPath]::new("Token1")

        $path.IsRelative() | Should Be $true        
    }

    It "IsRelative for simple path starting with $" {

        $path = [TokenPath]::new('$Token1')

        $path.IsRelative() | Should Be $true        
    }

    It "NOT IsRelative for simple rooted path" {

        $path = [TokenPath]::new("$.Token1")

        $path.IsRelative() | Should Be $false        
    }

}


Describe “TokenOverride" {


    Context "ApplyTo nested tokens hierarchy" {
       
        $rootScope = [TokenScope]::CreateRootScope()
        $portToken = $rootScope.CreateInnerScope("WebAPI").CreateInnerScope("Binding").AddToken("Port", 80) 
        
        Mock Write-Warning {}  

        It "replaces existing token value" {

            $override = [TokenOverride]::new("WebAPI.Binding.Port", 443)
            
            $override.ApplyTo($rootScope)

            $portToken.RawValue | Should Be 443
        }

        It "does not throw when token does not exist" {

            $override = [TokenOverride]::new("WebAPI.Binding.Protocol", "https")
            
            { $override.ApplyTo($rootScope) } | Should Not Throw            
        }

        It "write warnings when token does not exist" {

            $override = [TokenOverride]::new("WebAPI.Binding.Protocol", "https")
            
            Assert-MockCalled Write-Warning -Times 1          
        }
    }
}