
# TODO: 
# * define token path separator "." as const and use it in various places instead of inline literal
# * write unit tests    


# facade - entry point that exposes API to operate on scoped tokens hierarchy
Class TokenContainer {

    TokenContainer([string] $ContainerId)  {
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
    
    [void] Override([string] $Key, [object] $NewValue) {   
        
        $override = [TokenOverride]::new($Key, $NewValue)
        $override.ApplyTo($this.Tokens)        
    } 
    
    [void] Override([hashtable] $Overrides) {        
        $this.Tokens.Override($Overrides) 
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

    
    [TokenScope] GetRootScope() {
        $result = $this
        
        while ($result.ParentScope) { $result = $result.ParentScope }

        return $result
    }

    [array] GetInnerScopes() {
        return $this.InnerScopes.Values
    } 

    [TokenScope] GetScope([ItemPath] $Path) {
        $innerScopeName = $Path.GetRootItemName()
        $subpath = $Path.ToSubpath()

        $nextScope = if ($Path.IsRelative()) { $this.InnerScopes[$innerScopeName] } else { $this.GetRootScope() }

        if ($subpath -and $nextScope) {
            return $nextScope.GetScope($subpath)
        } else {
            return $nextScope
        }
    }

    [TokenScope] EnsureScope([string] $Path) {                                
        return $this.EnsureScope([ItemPath]::new($Path))
    }

    [TokenScope] EnsureScope([ItemPath] $Path) {                        
        
        $innerScopeName = $Path.GetRootItemName()
        $subpath = $Path.ToSubpath()

        $scope = 
            if ($Path.IsRelative()) { 
                if ($this.InnerScopes.ContainsKey($innerScopeName)) { 
                    $this.InnerScopes[$innerScopeName] 
                } else { 
                    $this.CreateInnerScope($innerScopeName) 
                }
            } else { 
                $this.GetRootScope() 
            }

        if ($subpath) {
            $scope = $scope.EnsureScope($subpath)
        }

        return $scope
    }

    [TokenScope] CreateInnerScope([string] $Name) {        
        $innerScope = [TokenScope]::new($Name, $this)
        $this.InnerScopes.Add($Name, $innerScope)
        return $innerScope
    }  
    
    [Token] GetToken([ItemPath] $Path) {                   
        $scopePath = $Path.ToBasePath()
        $tokenName = $Path.GetTargetItemName()
        
        if ($scopePath) { 
            $scope = $this.GetScope($scopePath)
            if ($scope) {
                return $scope.GetToken($tokenName)
            } else {
                return $null
            }            
        } else { 
            return $this.Tokens[$tokenName]
        }  
    }
            
    [bool] TokenExists([ItemPath] $Path) {
        return $this.GetToken($Path) -ne $null
    }         

    [Token] AddToken([string] $Name, [object] $Value) {
        
        $token = [Token]::new($this.FullName, $Name, $Value)
        $this.Tokens.Add($Name, $token)
        return $token
    }

    [Token] CreateToken([ItemPath] $Path) {
        return $this.CreateToken($Path, $null)
    }

    [Token] CreateToken([ItemPath] $Path, [object] $Value) {
        
        $tokenName = $Path.GetTargetItemName()
        $scopePath = $Path.ToBasePath()
        $targetScope = if ($scopePath) { $this.EnsureScope($scopePath) } else { $this }

        return $targetScope.AddToken($tokenName, $Value)
    }

    [void] Override([string] $TokenName, [object] $NewValue) {
            
        if ([ValueReferencePlaceholder]::IsValidPlaceholderSyntax($TokenName)) {
            $reference = [ValueReferencePlaceholder]::TryExtractReference($TokenName)
            $reference.TrySetValue($this, $NewValue)
        } else {
            if ($this.Tokens.ContainsKey($TokenName)) {
                $this.Tokens[$TokenName].UpdateValue($newValue)
            } else {
                $this.AddToken($TokenName, $newValue)
            }
        }         
    } 

    [void] Override([hashtable] $overrides) {

        if (-not $overrides) {
            return
        }
        
        $overrides.Keys | ForEach {            
            
            $overridenKey = $_
            $newValue = $overrides[$overridenKey]

            if ($newValue -is [hashtable]) {                
                $innerScope = $this.EnsureScope($overridenKey)                
                $innerScope.Override($newValue)              
            } else {         
                $this.Override($overridenKey, $newValue)  
            }
        }
    }

    # converts the token scope model to hashtable
    [hashtable] ToHashTable() {
        $result = @{}

        $this.InnerScopes.Values | ForEach { $result.Add($_.Name, $_.ToHashTable()) }
        $this.Tokens.Values | ForEach { $result.Add($_.Name, $_.RawValue) }
        
        return $result         
    } 
}


Class Token {

    Token($ScopeFullName, $Name, $RawValue) {
        
        if ([string]::IsNullOrWhiteSpace($ScopeFullName)) {
            throw "Argument ScopeFullName can not be empty string"
        }

        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw "Argument Name can not be empty string"
        }

        $this.Name = $Name
        $this.FullName = "$ScopeFullName.$Name"
        $this.RawValue = $RawValue
    }

    [string] $Name
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


Class ValueReferencePlaceholder {
    [regex] static $PlaceholderPattern = "\$\{(?<reference>.+)\}"

    [bool] static IsValidPlaceholderSyntax([string] $Value) {
        return $Value -match [ValueReferencePlaceholder]::PlaceholderPattern
    }

    [ValueReference] static TryExtractReference([string] $Placeholder) {
        if ($Placeholder -match [ValueReferencePlaceholder]::PlaceholderPattern) {
            return [ValueReference]::new($Matches["reference"])
        } else {
            return $null
        }
    }
}


# reference is token path + optional expression accessing token type specific member
# if token is object, then reference can contain "=>" to access object property e.g. SomeScope.SomeObjectTypeToken=>ObjectProperty    
class ValueReference {
    
    [regex] static $Pattern = "^(?<tokenPath>$([ItemPath]::Pattern))(?<tokenMemberExpression>(=>)?.*)$" 

    ValueReference([string] $Reference) {

        if ($Reference -match [ValueReference]::Pattern) {
            $this.TokenPath = [ItemPath]::new($Matches["tokenPath"])
            $this.TokenMemberExpression = [ValueReference]::ParseTokenMemberExpression($Matches["tokenMemberExpression"])            
        } else {
            throw "Unrecognized token override syntax: $Reference"
        }  
    }

    [ItemPath] $TokenPath
    [string] $TokenMemberExpression
    
    static [string] ParseTokenMemberExpression([string] $expression) {

        if (!$expression) {
            return $null
        }

        $isObjectMemberAccess = $expression.StartsWith("=>")

        if ($isObjectMemberAccess) {
            $expression = ".$($expression.Substring(2))"
        }

        return $expression        
    }

    [bool] TrySetValue([TokenScope] $Context, [object] $NewValue) {

        $referencedToken = $Context.GetToken($this.TokenPath)

        if ($referencedToken) {           
            $referencedToken.UpdateValue($NewValue, $this.TokenMemberExpression)   
            return $true    
        } else {
            return $false
        }           
    }

    [ValueReference] UpdateTokenPath([ItemPath] $Path) {
        $reference = [ValueReference]::new($Path)
        $reference.TokenMemberExpression = $this.TokenMemberExpression
        return $reference 
    }
}


class TokenOverride {       

    TokenOverride([string] $Key, [object] $NewValue) {

        $this.NewValue = [TokenOverride]::ParseValue($NewValue)
        $this.ValueReference = [ValueReference]::new($Key)                
    }  
    
    [ValueReference] $ValueReference
    [object] $NewValue

    static [object] ParseValue($Value) {
        
        if (!$Value) {
            return $Value
        }

        if ($Value -is [string]) {

            if ($Value -ieq '$true') {
                return $true
            }

            if ($Value -ieq '$false') {
                return $false
            }

            if ($Value -match '^{\s+.+\s+}$') {
                return [ScriptBlock]::Create($Value)
            }
        }
    
        return $Value 
    }

    [void] ApplyTo([TokenScope] $Context) {

        $overriddenTokens = $this.LookupOverridenTokens($Context)

        if ($overriddenTokens.Count) {
            $overriddenTokens | ForEach {
                $reference = $this.ValueReference.UpdateTokenPath($_.FullName)
                $reference.TrySetValue($Context, $this.NewValue) 
            }
        } else {
            Write-Warning "Could not override token '$($this.ValueReference.TokenPath.ToString())' in scope of '$($Context.FullName)'. Token has not been found."
        }
    }

    [array] LookupOverridenTokens([TokenScope] $Context) {
        $lookup = [InnerScopeTokenLookup]::new($this.ValueReference.TokenPath)
        return $lookup.GetTokens($Context)
    }
}


Class Identifier {
    
    static [string] $Pattern = "((?<identifier>[\w-$]+)|\[(?<identifier>[^\[^\]]+)\])"    
    
    static [string] Parse([string] $Value) {
        if ($Value -match "^$([Identifier]::Pattern)$") {
            return $Matches["identifier"]
        } else {
            throw "Invalid identifier '$Value'"
        }
    }
}


Class ItemPath {

    static [string] $PathSeparator = "."
    static [string] $Pattern = "($([Identifier]::Pattern)\.)*$([Identifier]::Pattern)"
    static [regex] $PatternRegex = "^$([ItemPath]::Pattern)$"
    static [string] $RootScopeName = "$" 

    ItemPath([string] $Path) {        
        $this.Identifiers = [ItemPath]::Split($Path)        
    }

    ItemPath([array] $Identifiers) {   
     
        if ($Identifiers.Count -eq 0) {
            throw "Item path must contain at least one identifier"
        }
        
        $this.Identifiers = $Identifiers                      
    }
    
    [array] $Identifiers
    
    static [array] Split([string] $Path) {        
        
        $match = [ItemPath]::PatternRegex.Match($Path)
        
        if ($match.Success) {
            return $match.Groups["identifier"].Captures.Value
        } else {
            throw "Invalid syntax of item path: '$Path'"
        }
    }

    [bool] IsRelative() {
        return ($this.Identifiers[0] -ne [ItemPath]::RootScopeName)
    }    

    [ItemPath] ToSubpath() {
        $innerIdentifiers = $this.Identifiers | Select -Skip 1
        $subpath = if ($innerIdentifiers.Count -eq 0) { $null } else { [ItemPath]::new($innerIdentifiers) }        
        return $subpath
    }

    [ItemPath] ToBasePath() {
        $baseIdentifiers = $this.Identifiers | Select -SkipLast 1
        $basePath = if ($baseIdentifiers.Count -eq 0) { $null } else { [ItemPath]::new($baseIdentifiers) }
        return $basePath
    }
    
    [string] GetRootItemName() {
        return $this.Identifiers | Select -First 1
    }

    [string] GetTargetItemName() {
        return $this.Identifiers[$this.Identifiers.Count-1]
    }

    [string] ToString() {
        return $this.Identifiers -join [ItemPath]::PathSeparator
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
        $this.Path = [ItemPath]::new($Path)
    }

    InnerScopeTokenLookup([ItemPath] $Path) {
        $this.Path = $Path
    }

    [ItemPath] $Path

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
