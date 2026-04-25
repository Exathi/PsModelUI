BeforeAll {
    Import-Module '.\PsModelUI' -Force
}

# New-Class and New-ViewModel have a lot of shared code. New-ViewModel includes CreateMethodCommand
Describe 'New-ViewModel' {
    It 'Creates a new class with mandatory fields' {
        $TestClass = New-ViewModel -ClassName 'Test'
        $TestClass.psobject.GetType().Name | Should -BeExactly 'Test'
    }

    It 'Creates a new class with a property by name' {
        $TestClass = New-ViewModel -ClassName 'Test' -PropertyDeclaration 'ClassProperty'
        $BackingFieldName = '_ClassProperty'
        $TestClass.psobject.psobject.Properties.Name | Should -Contain $BackingFieldName
        $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
    }

    Context 'Type Int' {
        It 'Creates a new class with an initialized int property without a prefix backing field' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([int])
                    Init = { 0 }
                    ExcludePrefix = $false
                })
            $BackingFieldName = '_ClassProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain $BackingFieldName
            $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
        }

        It 'Creates a new class with an initialized int property' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([int])
                    Init = { 0 }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeExactly 0
            $TestClass.ClassProperty | Should -BeExactly 0
        }
    }

    Context 'Type String' {
        It 'Creates a new class with an initialized string property' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { 'Test' }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeExactly 'Test'
            $TestClass.ClassProperty | Should -BeExactly 'Test'
        }

        It 'Creates a new class with an initialized string property that contains single quote' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { "Te'st" }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly "Te'st"
        }

        It 'Creates a new class with an initialized string property that contains many single quotes' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { "'Te'st'" }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly "'Te'st'"
        }

        It 'Creates a new class with an initialized string property that contains many double quote' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { '"Te"st"' }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly '"Te"st"'
        }

        It 'Creates a new class with an initialized string property that contains double quotes' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { '"Te"st"' }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly '"Te"st"'
        }

        It 'Creates a new class with an initialized string property from single quote here string maintaining spacing' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { 'Lorem

            ipsum
do"lor '}
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly 'Lorem

            ipsum
do"lor '
            $TestClass.ClassProperty[-1] | Should -BeExactly ' '
        }

        It 'Creates a new class with an initialized string property from double quote here string maintaining spacing' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { "Lorem

            ipsum
do'lor "}
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly "Lorem

            ipsum
do'lor "
            $TestClass.ClassProperty[-1] | Should -BeExactly ' '
        }

        It 'Creates a new class with an initialized array of strings property' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string[]])
                    Init = { 'I', 'Can', 'Count', 'To', 'Four' }
                    ExcludePrefix = $true
                })
            foreach ($Expected in 'I', 'Can', 'Count', 'To', 'Four') {
                $TestClass.psobject.ClassProperty | Should -Contain $Expected
                $TestClass.ClassProperty | Should -Contain $Expected
            }
            $TestClass.ClassProperty.Count | Should -BeExactly 5
        }
    }

    Context 'Type Object' {
        It 'Creates a new class with an empty Init property that exists' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Init = { }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeNullOrEmpty
            $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
        }

        It 'Creates a new class with a scriptblock of $null Init property that exists' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Init = { $null }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeNullOrEmpty
            $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
        }

        It 'Creates a new class with a $null Init property that exists' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Init = $null
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeNullOrEmpty
            $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
        }

        It 'Creates a new class with an initialized generic list property' {
            $Type = ([System.Collections.Generic.List[object]])
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([System.Collections.Generic.List[object]])
                    Init = { [System.Collections.Generic.List[object]]::new() }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty.GetType().FullName | Should -Be $Type.FullName
        }

        It 'Creates a new class with an initialized generic list property with 4 items' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([System.Collections.Generic.List[object]])
                    Init = { [System.Collections.Generic.List[object]]::new(@('1', 2, 'three', 'Four!')) }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty.Count | Should -BeExactly 4
            foreach ($Expected in '1', 2, 'three', 'Four!') {
                $TestClass.ClassProperty | Should -Contain $Expected
            }
        }

        It 'Creates a new class with an initialized empty array' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([array])
                    Init = { @() }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty.GetType().BaseType.Name | Should -Be @().GetType().BaseType.Name
            $TestClass.ClassProperty.Count | Should -BeExactly 0
        }

        It 'Creates a new class with an initialized array with one item' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([array])
                    Init = { @('one') }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty.Count | Should -BeExactly 1
            $TestClass.ClassProperty[0] | Should -BeExactly 'one'
        }
    }

    It 'Creates a new class with a method and command' {
        $TestClass = New-ViewModel -ClassName 'Test' -Methods ([pscustomobject]@{
                Name = 'ClassMethod'
                Body = { return 'Test' }
                MethodParameterNames = $null
                Throttle = 1
                IsAsync = $false
            })
        $TestClass.psobject.ClassMethod() | Should -BeExactly 'Test'
        $TestClass.ClassMethodCommand | Should -Not -BeNullOrEmpty
    }

    It 'Creates a new class with a method and an automatic property from $this reference in method body' {
        $TestClass = New-ViewModel -ClassName 'Test' -Methods ([pscustomobject]@{
                Name = 'ClassMethod'
                Body = { $this.ClassProperty = 'Test' }
                MethodParameterNames = $null
                Throttle = 1
                IsAsync = $false
            }) -AutomaticProperties $true
        $TestClass.psobject.ClassMethod()
        $TestClass.psobject._ClassProperty | Should -BeExactly 'Test'
        $TestClass.ClassProperty | Should -BeExactly 'Test'
    }

    It 'Creates a new class with a method without a command' {
        $TestClass = New-ViewModel -ClassName 'Test' -CreateMethodCommand $false -Methods ([pscustomobject]@{
                Name = 'ClassMethod'
                Body = { return 'Test' }
                MethodParameterNames = $null
                Throttle = 1
                IsAsync = $false
            })
        $TestClass.psobject.ClassMethod() | Should -BeExactly 'Test'
        $TestClass.ClassMethodCommand | Should -BeNullOrEmpty
    }

    It 'Returns a string representation of the class definition' {
        $TestClass = New-ViewModel -ClassName 'Test' -AsString
        $TestClass | Should -BeOfType string
    }

    It 'Returns a string representation of the class definition that can be invoked then created.' {
        $TestClassDefinition = New-ViewModel -ClassName 'Test' -AsString
        $Definition = [scriptblock]::Create($TestClassDefinition)
        . $Definition
        $TestClass = [Test]::new()
        $TestClass.psobject.GetType().Name | Should -BeExactly 'Test'
    }
}

# All tests assume inheriting pscustomobject.
Describe 'New-Class' {
    It 'Creates a new class with mandatory fields' {
        $TestClass = New-Class -ClassName 'Test'
        $TestClass.psobject.GetType().Name | Should -BeExactly 'Test'
    }

    It 'Creates a new class with a property by name' {
        $TestClass = New-Class -ClassName 'Test' -PropertyDeclaration 'ClassProperty'
        $BackingFieldName = '_ClassProperty'
        $TestClass.psobject.psobject.Properties.Name | Should -Contain $BackingFieldName
        $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
    }

    Context 'Type Int' {
        It 'Creates a new class with an initialized int property without a prefix backing field' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([int])
                    Init = { 0 }
                    ExcludePrefix = $false
                })
            $BackingFieldName = '_ClassProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain $BackingFieldName
            $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
        }

        It 'Creates a new class with an initialized int property' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([int])
                    Init = { 0 }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeExactly 0
            $TestClass.ClassProperty | Should -BeExactly 0
        }
    }

    Context 'Type String' {
        It 'Creates a new class with an initialized string property' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { 'Test' }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeExactly 'Test'
            $TestClass.ClassProperty | Should -BeExactly 'Test'
        }

        It 'Creates a new class with an initialized string property that contains single quote' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { "Te'st" }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly "Te'st"
        }

        It 'Creates a new class with an initialized string property that contains many single quotes' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { "'Te'st'" }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly "'Te'st'"
        }

        It 'Creates a new class with an initialized string property that contains many double quote' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { '"Te"st"' }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly '"Te"st"'
        }

        It 'Creates a new class with an initialized string property that contains double quotes' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { '"Te"st"' }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly '"Te"st"'
        }

        It 'Creates a new class with an initialized string property from single quote here string maintaining spacing' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { 'Lorem

            ipsum
do"lor '}
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly 'Lorem

            ipsum
do"lor '
            $TestClass.ClassProperty[-1] | Should -BeExactly ' '
        }

        It 'Creates a new class with an initialized string property from double quote here string maintaining spacing' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Init = { "Lorem

            ipsum
do'lor "}
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty | Should -BeExactly "Lorem

            ipsum
do'lor "
            $TestClass.ClassProperty[-1] | Should -BeExactly ' '
        }

        It 'Creates a new class with an initialized array of strings property' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string[]])
                    Init = { 'I', 'Can', 'Count', 'To', 'Four' }
                    ExcludePrefix = $true
                })
            foreach ($Expected in 'I', 'Can', 'Count', 'To', 'Four') {
                $TestClass.psobject.ClassProperty | Should -Contain $Expected
                $TestClass.ClassProperty | Should -Contain $Expected
            }
            $TestClass.ClassProperty.Count | Should -BeExactly 5
        }
    }

    Context 'Type Object' {
        It 'Creates a new class with an empty Init property that exists' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Init = { }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeNullOrEmpty
            $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
        }

        It 'Creates a new class with a scriptblock of $null Init property that exists' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Init = { $null }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeNullOrEmpty
            $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
        }

        It 'Creates a new class with a $null Init property that exists' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Init = $null
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty | Should -BeNullOrEmpty
            $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
        }

        It 'Creates a new class with an initialized generic list property' {
            $Type = ([System.Collections.Generic.List[object]])
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([System.Collections.Generic.List[object]])
                    Init = { [System.Collections.Generic.List[object]]::new() }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty.GetType().FullName | Should -Be $Type.FullName
        }

        It 'Creates a new class with an initialized generic list property with 4 items' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([System.Collections.Generic.List[object]])
                    Init = { [System.Collections.Generic.List[object]]::new(@('1', 2, 'three', 'Four!')) }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty.Count | Should -BeExactly 4
            foreach ($Expected in '1', 2, 'three', 'Four!') {
                $TestClass.ClassProperty | Should -Contain $Expected
            }
        }

        It 'Creates a new class with an initialized empty array' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([array])
                    Init = { @() }
                    ExcludePrefix = $true
                })
            $TestClass.psobject.ClassProperty.GetType().BaseType.Name | Should -Be @().GetType().BaseType.Name
            $TestClass.ClassProperty.Count | Should -BeExactly 0
        }

        It 'Creates a new class with an initialized array with one item' {
            $TestClass = New-Class -ClassName 'Test' -PropertyInit ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([array])
                    Init = { @('one') }
                    ExcludePrefix = $true
                })
            $TestClass.ClassProperty.Count | Should -BeExactly 1
            $TestClass.ClassProperty[0] | Should -BeExactly 'one'
        }
    }

    It 'Creates a new class with a method and an automatic property from $this reference in method body' {
        $TestClass = New-Class -ClassName 'Test' -Methods ([pscustomobject]@{
                Name = 'ClassMethod'
                Body = { $this.ClassProperty = 'Test' }
                MethodParameterNames = $null
            }) -AutomaticProperties $true
        $TestClass.psobject.ClassMethod()
        $TestClass.psobject._ClassProperty | Should -BeExactly 'Test'
        $TestClass.ClassProperty | Should -BeExactly 'Test'
    }

    It 'Returns a string representation of the class definition' {
        $TestClass = New-Class -ClassName 'Test' -AsString
        $TestClass | Should -BeOfType string
    }

    It 'Returns a string representation of the class definition that can be invoked then created.' {
        $TestClassDefinition = New-Class -ClassName 'Test' -AsString
        $Definition = [scriptblock]::Create($TestClassDefinition)
        . $Definition
        $TestClass = [Test]::new()
        $TestClass.psobject.GetType().Name | Should -BeExactly 'Test'
    }
}

# New-ClassProperty is used in both New-Class and New-ViewModel. Tests other parameters not used above in New-ViewModel to ensure the property definition string is created correctly and can be used in both functions without issue.
Describe 'New-ClassProperty' {
    Context 'New-ViewModel' {
        It 'Creates a class property definition string with a type and no init' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty' -Type ([string])
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.psobject.Properties.Name | Should -BeExactly 'TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain '_TestProperty'
        }

        It 'Creates a class property definition string with a type and init' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty' -Type ([string]) -Init { 'Test' }
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.psobject.Properties.Name | Should -BeExactly 'TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain '_TestProperty'
            $TestClass.TestProperty | Should -BeExactly 'Test'
        }

        It 'Creates a class property definition string with a type and init and no prefix' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty' -Type ([string]) -Init { 'Test' } -ExcludePrefix
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.psobject.Properties.Name | Should -BeExactly 'TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Not -Contain '_TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain 'TestProperty'
            $TestClass.TestProperty | Should -BeExactly 'Test'
        }

        It 'Creates a class property definition string with only a name' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty'
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.psobject.Properties.Name | Should -BeExactly 'TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain '_TestProperty'
            $TestClass.TestProperty | Should -BeNullOrEmpty
        }

        It 'Creates a class property with a custom get and set' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty' -Type ([string]) -Init { 'Test' } -Get { return, $this.psobject._TestProperty.ToUpper() } -Set {
                param($value)
                $this.psobject._TestProperty = $value
            }
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.TestProperty | Should -BeExactly 'TEST'
            $TestClass.TestProperty = 'NewValue'
            $TestClass.TestProperty | Should -BeExactly 'NEWVALUE'
        }
    }

    Context 'New-Class' {
        It 'Creates a class property definition string with a type and no init' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty' -Type ([string])
            $TestClass = New-Class -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.psobject.Properties.Name | Should -BeExactly 'TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain '_TestProperty'
        }

        It 'Creates a class property definition string with a type and init' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty' -Type ([string]) -Init { 'Test' }
            $TestClass = New-Class -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.psobject.Properties.Name | Should -BeExactly 'TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain '_TestProperty'
            $TestClass.TestProperty | Should -BeExactly 'Test'
        }

        It 'Creates a class property definition string with a type and init and no prefix' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty' -Type ([string]) -Init { 'Test' } -ExcludePrefix
            $TestClass = New-Class -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.psobject.Properties.Name | Should -BeExactly 'TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Not -Contain '_TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain 'TestProperty'
            $TestClass.TestProperty | Should -BeExactly 'Test'
        }

        It 'Creates a class property definition string with only a name' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty'
            $TestClass = New-Class -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.psobject.Properties.Name | Should -BeExactly 'TestProperty'
            $TestClass.psobject.psobject.Properties.Name | Should -Contain '_TestProperty'
            $TestClass.TestProperty | Should -BeNullOrEmpty
        }

        It 'Creates a class property with a custom get and set' {
            $PropertyDefinition = New-ClassProperty -Name 'TestProperty' -Type ([string]) -Init { 'Test' } -Get { return, $this.psobject._TestProperty.ToUpper() } -Set {
                param($value)
                $this.psobject._TestProperty = $value
            }
            $TestClass = New-Class -ClassName 'Test' -PropertyInit $PropertyDefinition
            $TestClass.TestProperty | Should -BeExactly 'TEST'
            $TestClass.TestProperty = 'NewValue'
            $TestClass.TestProperty | Should -BeExactly 'NEWVALUE'
        }
    }
}

# New-ViewModelMethod is used in both New-Class and New-ViewModel. Tests other parameters not used above in New-ViewModel to ensure the method definition string is created correctly and can be used in both functions without issue.
Describe 'New-ViewModelMethod' {
    Context 'New-ViewModel' {
        It 'Creates a method definition string with no parameters' {
            $MethodDefinition = New-ViewModelMethod -Name 'TestMethod' -Body { return 'Test' }
            $TestClass = New-ViewModel -ClassName 'Test' -Methods $MethodDefinition
            $TestClass.psobject.TestMethod() | Should -BeExactly 'Test'
        }

        It 'Creates a method definition string with parameters in one line' {
            $MethodDefinition = New-ViewModelMethod -Name 'TestMethod' -Body { param($a, $b) return "$a $b" }
            $TestClass = New-ViewModel -ClassName 'Test' -Methods $MethodDefinition
            $TestClass.psobject.TestMethod('Hello', 'World') | Should -BeExactly 'Hello World'
        }

        It 'Creates a method definition string with parameters over multiple lines' {
            $MethodDefinition = New-ViewModelMethod -Name 'TestMethod' -Body { param($a, $b)
                $ModifiedA = $a.ToUpper()
                $ModifiedB = $b.ToUpper()
                return "$ModifiedA $ModifiedB" }
            $TestClass = New-ViewModel -ClassName 'Test' -Methods $MethodDefinition
            $TestClass.psobject.TestMethod('Hello', 'World') | Should -BeExactly 'HELLO WORLD'
        }

        It 'Creates a method definition without parameters' {
            $MethodDefinition = New-ViewModelMethod -Name 'TestMethod' -Body { return 'Test' }
            $TestClass = New-ViewModel -ClassName 'Test' -Methods $MethodDefinition
            $TestClass.psobject.TestMethod() | Should -BeExactly 'Test'
        }
    }

    Context 'New-Class' {
        It 'Creates a method definition string with no parameters' {
            $MethodDefinition = New-ViewModelMethod -Name 'TestMethod' -Body { return 'Test' }
            $TestClass = New-Class -ClassName 'Test' -Methods $MethodDefinition
            $TestClass.psobject.TestMethod() | Should -BeExactly 'Test'
        }

        It 'Creates a method definition string with parameters in one line' {
            $MethodDefinition = New-ViewModelMethod -Name 'TestMethod' -Body { param($a, $b) return "$a $b" }
            $TestClass = New-Class -ClassName 'Test' -Methods $MethodDefinition
            $TestClass.psobject.TestMethod('Hello', 'World') | Should -BeExactly 'Hello World'
        }

        It 'Creates a method definition string with parameters over multiple lines' {
            $MethodDefinition = New-ViewModelMethod -Name 'TestMethod' -Body { param($a, $b)
                $ModifiedA = $a.ToUpper()
                $ModifiedB = $b.ToUpper()
                return "$ModifiedA $ModifiedB" }
            $TestClass = New-Class -ClassName 'Test' -Methods $MethodDefinition
            $TestClass.psobject.TestMethod('Hello', 'World') | Should -BeExactly 'HELLO WORLD'
        }

        It 'Creates a method definition without parameters' {
            $MethodDefinition = New-ViewModelMethod -Name 'TestMethod' -Body { return 'Test' }
            $TestClass = New-Class -ClassName 'Test' -Methods $MethodDefinition
            $TestClass.psobject.TestMethod() | Should -BeExactly 'Test'
        }
    }
}
