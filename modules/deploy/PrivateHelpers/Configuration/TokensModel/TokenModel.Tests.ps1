Describe "TokenContainer" {

    It "Constructor: does not throw when creating with id" {
        
        { [TokenContainer]::new("Default") } | Should Not Throw
    }

    It "Override: overrides tokens in multiple child scopes" {
        
        $tokens = @{
            WebAPI = @{
                Port = 443
                Database = @{ Name = "Test" }
            }
            WebUI = @{
                Port = 443
                Database = @{ Name = "Test" }
            }
        }

        $container = [TokenContainer]::new("Default")
        $container.Override($tokens)
        $container.Override("Port", 80)        
             
        $container.Tokens.GetToken("$.Port") | Should Be $null
        $container.Tokens.GetToken("$.WebAPI.Port").RawValue | Should Be 80
        $container.Tokens.GetToken("$.WebUI.Port").RawValue | Should Be 80
    }

    It "Override: overrides nested tokens in multiple child scopes" {
        
        $tokens = @{
            WebAPI = @{                
                Binding = @{ Port = 443 }
            }
            WebUI = @{                
                Binding = @{ Port = 443 }
            }
        }

        $container = [TokenContainer]::new("Default")
        $container.Override($tokens)
        $container.Override("Binding.Port", 80)        
             
        $container.Tokens.GetToken("$.Binding.Port") | Should Be $null
        $container.Tokens.GetToken("$.WebAPI.Binding.Port").RawValue | Should Be 80
        $container.Tokens.GetToken("$.WebUI.Binding.Port").RawValue | Should Be 80
    }

    It "Override: creates new scopes and tokens" {
        
        $tokens = @{
            WebAPI = @{
                Website = @{
                    Port = 443
                }
            }
            General = @{
                Url = ""
            }
        }

        $container = [TokenContainer]::new("Default")
        $container.Override($tokens)        

        $container.Tokens.GetInnerScopes().length | Should Be 2        
        $container.Tokens.GetToken("WebAPI.Website.Port").RawValue | Should Be 443
        $container.Tokens.GetToken("General.Url").RawValue | Should Be ""
    }
}

Describe "TokenScope" {

    $scope = [TokenScope]::CreateRootScope()
    $portToken = $scope.CreateInnerScope("WebAPI").CreateInnerScope("Binding").AddToken("Port", 80)  

    It "CreateToken: creates neccessary scopes" {
        
        $scope = [TokenScope]::CreateRootScope()
        $path = [ItemPath]::new('Website.Binding.Port')

        $scope.CreateToken($path)

        $scope.GetInnerScopes().Count | Should Be 1
        $scope.GetInnerScopes()[0].GetInnerScopes().Count | Should Be 1
    }

    It "CreateToken: creates token" {
        
        $scope = [TokenScope]::CreateRootScope()
        $path = [ItemPath]::new('Website.Binding.Port')

        $scope.CreateToken($path)

        $scope.TokenExists($path) | Should Be $true
    }

    It "CreateToken: created token has null value" {
        
        $scope = [TokenScope]::CreateRootScope()
        $path = [ItemPath]::new('Website.Binding.Port')

        $scope.CreateToken($path)

        $token.RawValue | Should Be $null
    }

    It "CreateToken: created token has expected name" {
        
        $scope = [TokenScope]::CreateRootScope()
        $path = [ItemPath]::new('Website.Binding.Port')

        $token = $scope.CreateToken($path)

        $token.Name | Should Be "Port"
        $token.FullName | Should Be "$.Website.Binding.Port"
    }

    It "OverrideTokens: override when key is token relative path" {
        
        $overrides = @{ '${WebAPI.Binding.Port}' = 443 }

        $scope.Override($overrides)

        $portToken.RawValue | Should Be 443
    }

    It "OverrideTokens: override when key is simple token name" {
        
        $overrides = @{ 'Port' = 80 }

        $scope.Override($overrides)

        $portToken.RawValue | Should Be 443
    }
}


Describe "Token" {

    It "throws when creating token with empty full scope name" {
        
        { [Token]::new("", "MyToken", $null) } | Should Throw
    }

    It "throws when creating token with empty name" {
        
        { [Token]::new("Scope", "", $null) } | Should Throw
    }

    It "does not throw when creating token with null value" {
        
        { [Token]::new("Scope", "MyToken", $null) } | Should Not Throw
    }

    It "does not throw when creating token with dash in full name" {
        
        { [Token]::new("SomeScope.AnotherScope", "My-Fancy-Token", $null) } | Should Not Throw
    }
}

Describe "Identifier" {

    It "Parse: identifier single dolar char" {

        $value = [Identifier]::Parse("$")

        $value | Should Be "$"        
    }

    It "Parse: identifier with dash" {

        $value = [Identifier]::Parse("this-is-a-name")

        $value | Should Be "this-is-a-name"        
    }

    It "Parse: throws when identifier with dots" {

        { [Identifier]::Parse("not.valid") } | Should Throw "Invalid identifier 'not.valid'"   
    }

    It "Parse: throws when identifier contains square brackets" {

        { [Identifier]::Parse("[invalid[]]") } | Should Throw "Invalid identifier '[invalid[]]'"   

    }


    It "Parse: identifier with dots in square brackets" {

        $value = [Identifier]::Parse("[is.allowed]")

        $value | Should Be "is.allowed"
    }
}


Describe "ItemPath" {
    It "Constructor: throws when creating from empty string" {
        { [ItemPath]::new("") } | Should Throw "Invalid syntax of item path: ''"        
    }

    It "Constructor: throws when creating from empty array" {
        { [ItemPath]::new(@()) } | Should Throw "Item path must contain at least one identifier"   
    }

    It "Constructor: path with identifiers in square brackets" {
        $path = [ItemPath]::new("[Scope.0].[Scope.1].[Scope.2]")

        $path.Identifiers.Count | Should Be 3
        $path.Identifiers[0] | Should Be "Scope.0"
        $path.Identifiers[1] | Should Be "Scope.1"
        $path.Identifiers[2] | Should Be "Scope.2"
    }

    It "IsRelative: false when path is root" {
        $path = [ItemPath]::new("$")
        $path.IsRelative() | Should Be $false
    }

    It "IsRelative: false when path is complex and rooted" {
        $path = [ItemPath]::new("$.S1.S2.S3")
        $path.IsRelative() | Should Be $false
    }

    It "IsRelative: true when path is identifier starting with '$'" {
        $path = [ItemPath]::new("`$ItemName")
        $path.IsRelative() | Should Be $true
    }

    It "IsRelative: true when path contains single item" {
        $path = [ItemPath]::new("ItemName")
        $path.IsRelative() | Should Be $true
    }

    It "IsRelative: true when path is complex" {
        $path = [ItemPath]::new("S1.S2.S3")
        $path.IsRelative() | Should Be $true
    }

    It "ToSubpath: returns null when for single component path" {
        $path = [ItemPath]::new("S1")
        $path.ToSubpath() | Should Be $null
    }
}

Describe “TokenOverride" {

    It "throws when creating with empty reference string" {
        
        { [TokenOverride]::new("", 123) } | Should Throw
    }


    Context "ApplyTo: nested tokens hierarchy" {  
    
        $rootScope = [TokenScope]::CreateRootScope()
        $portToken = $rootScope.CreateInnerScope("WebAPI").CreateInnerScope("Binding").AddToken("Port", 80)  
        
        Mock Write-Warning {}                          

        It "does not throw when reference points to namespace" {

            $override = [TokenOverride]::new("WebAPI.Binding", @{})
            
            { $override.ApplyTo($rootScope) } | Should Not Throw
        }

        It "does not throw when token does not exist" {

            $override = [TokenOverride]::new("WebAPI.Binding.Protocol", "https")
            
            { $override.ApplyTo($rootScope) } | Should Not Throw
        }

        It "does not affects token hierarchy when reference points to namespace" {

            $override = [TokenOverride]::new("WebAPI.Binding", @{})
            
            $override.ApplyTo($rootScope)

            $rootScope.TokenExists("WebAPI.Binding.Port")
        }

        It "write expected warning when token does not exist" {                   
                        
            $override = [TokenOverride]::new("WebAPI.Binding.Protocol", "https")

            $override.ApplyTo($rootScope)
            
            Assert-MockCalled Write-Warning -Exactly 1 -Scope It `
                -ParameterFilter { $message -eq "Could not override token 'WebAPI.Binding.Protocol' in scope of '$'. Token has not been found." }
        }
    }

    Context "ApplyTo: override with basic reference" {

        $scope = [TokenScope]::CreateRootScope()
        $orginalValue = @{}
        $token = $scope.AddToken("Token", $orginalValue)

        BeforeEach {
            $token.UpdateValue($orginalValue)
        }

        It "replaces simple numeric value" {
                                
            [TokenOverride]::new("Token", 443).ApplyTo($scope)

            $token.RawValue | Should Be 443     
        }  

        It "replace the reference even if new value is same hashtable" {
                                                       
            [TokenOverride]::new("Token", @{}).ApplyTo($scope)

            $token.RawValue | Should Not Be $orginalValue            
        }
    }

    Context "ApplyTo: override with token member reference" {

        $scope = [TokenScope]::CreateRootScope()
        $arrayToken = $scope.AddToken("ArrayToken", @(0,1,2,3,4))
        $hashtableToken = $scope.AddToken("HashtableToken", @{ ToReplace = "Foo"; KeepValue = "Fix" })
        $objectToken = $scope.AddToken("ObjectToken", (New-Object PSObject -Property @{ ToReplace = "Foo"; KeepValue = "Fix" }) )

        It "set one element in array" {
        
            $expectedAfterOverride = @(0,222,2,3,4)

            [TokenOverride]::new("ArrayToken[1]", 222).ApplyTo($scope)

            (Compare-Object $arrayToken.RawValue $expectedAfterOverride).length | Should Be 0
        }  

        It "set one element in hashtable" {
        
            $expectedAfterOverride = @{ ToReplace = "Bar"; KeepValue = "Fix" }

            [TokenOverride]::new("HashtableToken['ToReplace']", "Bar").ApplyTo($scope)                        

            (Compare-Object $hashtableToken.RawValue $expectedAfterOverride).length | Should Be 0
        }

        It "set one member of object" {
        
            $expectedAfterOverride = (New-Object PSObject -Property @{ ToReplace = "Bar"; KeepValue = "Fix" })

            [TokenOverride]::new("ObjectToken=>ToReplace", "Bar").ApplyTo($scope)                        

            (Compare-Object $objectToken.RawValue $expectedAfterOverride).length | Should Be 0
        }
    }
}