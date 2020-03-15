using RoundingEmulation

import Base.Rounding
using Printf
using Test

special_value_list(T::Type) = [
    zero(T), -zero(T), 
    one(T), -one(T),
    nextfloat(zero(T)), prevfloat(zero(T)),
    eps(T), -eps(T),
    floatmin(T), -floatmin(T),
    floatmax(T), -floatmax(T),
    typemax(T), typemin(T),
    T(NaN)
]

function check_op(op, updown, ai, bi, calc, raw)
    if isequal(calc, raw)
        true
    else
        @info("Erorr", op, updown)
        @info(@sprintf("a = %0.18e, bit rep : %s", ai, bitstring(ai)))
        @info(@sprintf("b = %0.18e, bit rep : %s", bi, bitstring(bi)))

        @info(@sprintf("calc = %0.18e, bit rep : %s", calc, bitstring(calc)))
        @info(@sprintf("raw = %0.18e, bit rep : %s", raw, bitstring(raw)))
        false
    end
end

function check_op_sqrt(op, updown, ai, calc, raw)
    if isequal(calc, raw)
        true
    else
        @info("Erorr", op, updown)
        @info(@sprintf("a = %0.18e, bit rep : %s", ai, bitstring(ai)))

        @info(@sprintf("calc = %0.18e, bit rep : %s", calc, bitstring(calc)))
        @info(@sprintf("raw = %0.18e, bit rep : %s", raw, bitstring(raw)))
        false
    end
end

function rounding_check(a, b)
    elt = eltype(a)
    for (op, base_op) in zip(("add", "sub", "mul", "div"), (:+, :-, :*, :/))
        @eval begin
            Rounding.setrounding_raw($elt, Rounding.to_fenv(RoundNearest))
            $(Symbol(op, "_up_calc")) = $(Symbol(op, "_up")).($a, $b)
            $(Symbol(op, "_down_calc")) = $(Symbol(op, "_down")).($a, $b)

            Rounding.setrounding_raw($elt, Rounding.to_fenv(RoundUp))
            $(Symbol(op, "_up_raw")) = broadcast($base_op, $a, $b)

            Rounding.setrounding_raw($elt, Rounding.to_fenv(RoundDown))
            $(Symbol(op, "_down_raw")) = broadcast($base_op, $a, $b)

            # Compare
            for (ai, bi, up_calc, up_raw) in zip($a, $b, $(Symbol(op, "_up_calc")), $(Symbol(op, "_up_raw")))
                @test check_op($op, "up", ai, bi, up_calc, up_raw)
            end

            for (ai, bi, down_calc, down_raw) in zip($a, $b, $(Symbol(op, "_down_calc")), $(Symbol(op, "_down_raw")))
                @test check_op($op, "down", ai, bi, down_calc, down_raw)
            end
        end
    end

    Rounding.setrounding_raw(elt, Rounding.to_fenv(RoundNearest))
    # Sqrt
    abs_a = abs.(a)
    up_calc = sqrt_up.(abs_a)
    down_calc = sqrt_down.(abs_a)

    Rounding.setrounding_raw(elt, Rounding.to_fenv(RoundUp))
    up_raw = sqrt.(abs_a)

    Rounding.setrounding_raw(elt, Rounding.to_fenv(RoundDown))
    down_raw = sqrt.(abs_a)

    # Compare
    for (ai, up_calc, up_raw) in zip(abs_a, up_calc, up_raw)
        @test check_op_sqrt("sqrt", "up", ai, up_calc, up_raw)
    end

    for (ai, down_calc, down_raw) in zip(abs_a, down_calc, down_raw)
        @test check_op_sqrt("sqrt", "down", ai, down_calc, down_raw)
    end
end

for T in (Float64, Float32)
    @testset "$(T), Special Cases" begin
        special_values = special_value_list(T)
        len = Base.length(special_values)
        a = repeat(special_values, len)
        b = sort(a)
        rounding_check(a, b)
    end
end

@testset "Overflow, Underflow" begin
    # TODO
    # Add counterexamples for Float32

    ces = [3.5630624444874539e+307  -1.7976931348623157e+308;   # twosum overflow, http://verifiedby.me/adiary/09
           6.929001713869936e+236   2.5944475251952003e+71;     # twoprod overflow, http://verifiedby.me/adiary/09
           -2.1634867667116802e-200 1.6930929484402486e-119;    # mul_up
           6.640350825165134e-116   -1.1053488936824272e-202;   # mul_down
           2.1963398713704127e-308  5.082385199753506e-149;     # div_up
           -2.592045137385347e-308  -0.024378802704431428;      # div_down
    ]
    a = ces[:, 1]
    b = ces[:, 2]
    rounding_check(a, b)
    rounding_check(b, a)
end

for n in 3:6
    for T in (Float64, Float32)
        @testset "$(T), Random Sampling, 10^$(n)" begin
            N = 10^n
            rand_a = reinterpret.(T, rand(Base.uinttype(T), N))
            rand_b = reinterpret.(T, rand(Base.uinttype(T), N))
            rounding_check(rand_a, rand_b)
            rounding_check(rand_b, rand_a)
        end
    end
end