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

    It 'Creates a new class with an initialized string property' {
        $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                Name = 'ClassProperty'
                Type = ([string])
                Initialization = { 'Test' }
            })
        $TestClass.psobject.ClassProperty | Should -BeExactly 'Test'
        $TestClass.ClassProperty | Should -BeExactly 'Test'
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

    It 'Creates a new class with an initialized generic list property' {
        $Type = ([System.Collections.Generic.List[object]])
        $TestClass = New-ViewModel -ClassName 'Test' -PropertyInitialization ([pscustomobject]@{
                Name = 'ClassProperty'
                Type = ([System.Collections.Generic.List[object]])
                Initialization = { [System.Collections.Generic.List[object]]::new() }
            })
        $TestClass.psobject.ClassProperty.GetType().FullName | Should -Be $Type.FullName
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
