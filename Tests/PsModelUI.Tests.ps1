BeforeAll {
    Import-Module '.\PsModelUI'
}

Describe 'New-ViewModel' {
    It 'Creates a new class with mandatory fields' {
        $TestClass = New-ViewModel -ClassName 'Test'
        $TestClass.psobject.GetType().Name | Should -BeExactly 'Test'
    }

    It 'Creates a new class with a property by name' {
        $TestClass = New-ViewModel -ClassName 'Test' -PropertyDeclaration 'ClassProperty'
        $TestClass.psobject.psobject.Properties.Name | Should -Contain 'ClassProperty'
        $TestClass.psobject.Properties.Name | Should -BeExactly 'ClassProperty'
    }

    Context 'Type Int' {
        It 'Creates a new class with an initialized int property' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([int])
                    Initialization = { 0 }
                })
            $TestClass.psobject.ClassProperty | Should -BeExactly 0
            $TestClass.ClassProperty | Should -BeExactly 0
        }
    }

    Context 'Type String' {
        It 'Creates a new class with an initialized string property' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Initialization = { 'Test' }
                })
            $TestClass.psobject.ClassProperty | Should -BeExactly 'Test'
            $TestClass.ClassProperty | Should -BeExactly 'Test'
        }

        It 'Creates a new class with an initialized string property that contains single quote' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Initialization = { "Te'st" }
                })
            $TestClass.ClassProperty | Should -BeExactly "Te'st"
        }

        It 'Creates a new class with an initialized string property that contains many single quotes' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Initialization = { "'Te'st'" }
                })
            $TestClass.ClassProperty | Should -BeExactly "'Te'st'"
        }

        It 'Creates a new class with an initialized string property that contains many double quote' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Initialization = { '"Te"st"' }
                })
            $TestClass.ClassProperty | Should -BeExactly '"Te"st"'
        }

        It 'Creates a new class with an initialized string property that contains double quotes' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Initialization = { '"Te"st"' }
                })
            $TestClass.ClassProperty | Should -BeExactly '"Te"st"'
        }

        It 'Creates a new class with an initialized string property from single quote here string maintaining spacing' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Initialization = { 'Lorem

            ipsum
do"lor '}
                })
            $TestClass.ClassProperty | Should -BeExactly 'Lorem

            ipsum
do"lor '
            $TestClass.ClassProperty[-1] | Should -BeExactly ' '
        }

        It 'Creates a new class with an initialized string property from double quote here string maintaining spacing' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string])
                    Initialization = { "Lorem

            ipsum
do'lor "}
                })
            $TestClass.ClassProperty | Should -BeExactly "Lorem

            ipsum
do'lor "
            $TestClass.ClassProperty[-1] | Should -BeExactly ' '
        }

        It 'Creates a new class with an initialized array of strings property' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([string[]])
                    Initialization = { 'I', 'Can', 'Count', 'To', 'Four' }
                })
            foreach ($Expected in 'I', 'Can', 'Count', 'To', 'Four') {
                $TestClass.psobject.ClassProperty | Should -Contain $Expected
                $TestClass.ClassProperty | Should -Contain $Expected
            }
            $TestClass.ClassProperty.Count | Should -BeExactly 5
        }
    }

    Context 'Type Object' {
        It 'Creates a new class with an empty initialization property that exists' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Initialization = { }
                })
            $TestClass.psobject.ClassProperty | Should -Be $null
            $TestClass.psobject.Properties.Name | Should -Be 'ClassProperty'
        }

        It 'Creates a new class with a scriptblock of $null initialization property that exists' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Initialization = { $null }
                })
            $TestClass.psobject.ClassProperty | Should -Be $null
            $TestClass.psobject.Properties.Name | Should -Be 'ClassProperty'
        }

        It 'Creates a new class with a $null initialization property that exists' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([object])
                    Initialization = $null
                })
            $TestClass.psobject.ClassProperty | Should -Be $null
            $TestClass.psobject.Properties.Name | Should -Be 'ClassProperty'
        }

        It 'Creates a new class with an initialized generic list property' {
            $Type = ([System.Collections.Generic.List[object]])
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([System.Collections.Generic.List[object]])
                    Initialization = { [System.Collections.Generic.List[object]]::new() }
                })
            $TestClass.psobject.ClassProperty.GetType().FullName | Should -Be $Type.FullName
        }

        It 'Creates a new class with an initialized generic list property with 4 items' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([System.Collections.Generic.List[object]])
                    Initialization = { [System.Collections.Generic.List[object]]::new(@('1', 2, 'three', 'Four!')) }
                })
            $TestClass.ClassProperty.Count | Should -BeExactly 4
            foreach ($Expected in '1', 2, 'three', 'Four!') {
                $TestClass.ClassProperty | Should -Contain $Expected
            }
        }

        It 'Creates a new class with an initialized empty array' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([array])
                    Initialization = { @() }
                })
            $TestClass.psobject.ClassProperty.GetType().BaseType.Name | Should -Be @().GetType().BaseType.Name
            $TestClass.ClassProperty.Count | Should -BeExactly 0
        }

        It 'Creates a new class with an initialized array with one item' {
            $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                    Name = 'ClassProperty'
                    Type = ([array])
                    Initialization = { @('one') }
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
