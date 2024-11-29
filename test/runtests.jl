using Test
using DocstringChef
using Aqua
using JET

@testset "Aqua" begin
	Aqua.test_all(DocstringChef)
end

@testset "JET" begin
	JET.report_package(DocstringChef, target_defined_modules=true)
end
