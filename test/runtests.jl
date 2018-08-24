using JsonBuilder
using Test

@testset "basic" begin
    @test "{\"a\":2}" == @json "{a:2}"
    @test "{\"a\":2}" == @json "{a:$(2)}"
    @test "{\"a\":\"foo\"}" == @json "{a:$("foo")}"
end

@testset "complex types" begin
    @test "{\"a\":{\"a\":3}}" == @json "{a:$((a=3,))}"
    @test "{\"a\":{\"a\":[3,4]}}" == @json "{a:$((a=(3,4),))}"
    @test "{\"a\":[{\"a\":3},{\"b\":4}]}" == @json "{a:$([(a=3,), (b=4,)])}"
end

@testset "mixin" begin
    @test "{\"a\":3,\"b\":4}" == @json "{$(pairs((a=3, b=4)))...}"
    @test "[3,4]" == @json "[$((3,4))...]"
end
