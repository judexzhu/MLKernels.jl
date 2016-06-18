#===================================================================================================
  Composition Classes: Valid kernel transformations
===================================================================================================#

abstract CompositionClass{T<:AbstractFloat}

@inline eltype{T}(::CompositionClass{T}) = T 

@inline iscomposable(::CompositionClass, ::RealFunction) = false

@inline ismercer(::CompositionClass) = false
@inline isnegdef(::CompositionClass) = false
@inline ismetric(::CompositionClass) = false
@inline isinnerprod(::CompositionClass) = false

@inline attainszero(::CompositionClass)     = true
@inline attainspositive(::CompositionClass) = true
@inline attainsnegative(::CompositionClass) = true

function description_string(g::CompositionClass, showtype::Bool = true)
    class = typeof(g)
    fields = fieldnames(class)
    class_str = string(class.name.name) * (showtype ? string("{", eltype(g), "}") : "")
    *(class_str, "(", join(["$field=$(getfield(g,field).value)" for field in fields], ","), ")")
end

function show(io::IO, g::CompositionClass)
    print(io, description_string(g))
end

function convert{T<:AbstractFloat,K<:CompositionClass}(::Type{CompositionClass{T}}, g::K)
    convert(K.name.primary{T}, g)
end

function =={T<:CompositionClass}(g1::T, g2::T)
    all([getfield(g1,field) == getfield(g2,field) for field in fieldnames(T)])
end

#== Positive Mercer Classes ==#

abstract PositiveMercerClass{T<:AbstractFloat} <: CompositionClass{T}
@inline ismercer(::PositiveMercerClass) = true
@inline attainsnegative(::PositiveMercerClass) = false
@inline attainszero(::PositiveMercerClass) = false

doc"GammaExponentialClass(f;α,γ) = exp(-α⋅fᵞ)"
immutable GammaExponentialClass{T<:AbstractFloat} <: PositiveMercerClass{T}
    alpha::HyperParameter{T}
    gamma::HyperParameter{T}
    GammaExponentialClass(α::Variable{T}, γ::Variable{T}) = new(
        HyperParameter(α, leftbounded(zero(T), :open)),
        HyperParameter(γ, Interval(Bound(zero(T), :open), Bound(one(T), :closed)))
    )
end
@outer_constructor(GammaExponentialClass, (1,0.5))
@inline iscomposable(::GammaExponentialClass, f::RealFunction) = isnegdef(f) && isnonnegative(f)
@inline composition{T<:AbstractFloat}(g::GammaExponentialClass{T}, z::T) = exp(-g.alpha * z^g.gamma)


doc"ExponentialClass(f;α) = exp(-α⋅f²)"
immutable ExponentialClass{T<:AbstractFloat} <: PositiveMercerClass{T}
    alpha::HyperParameter{T}
    ExponentialClass(α::Variable{T}) = new(
        HyperParameter(α, leftbounded(zero(T), :open))
    )
end
@outer_constructor(ExponentialClass, (1,))
@inline iscomposable(::ExponentialClass, f::RealFunction) = isnegdef(f) && isnonnegative(f)
@inline composition{T<:AbstractFloat}(g::ExponentialClass{T}, z::T) = exp(-g.alpha * z)


doc"GammaRationalClass(f;α,β,γ) = (1 + α⋅fᵞ)⁻ᵝ"
immutable GammaRationalClass{T<:AbstractFloat} <: PositiveMercerClass{T}
    alpha::HyperParameter{T}
    beta::HyperParameter{T}
    gamma::HyperParameter{T}
    GammaRationalClass(α::Variable{T}, β::Variable{T}, γ::Variable{T}) = new(
        HyperParameter(α, leftbounded(zero(T), :open)),
        HyperParameter(β, leftbounded(zero(T), :open)),
        HyperParameter(γ, Interval(Bound(zero(T), :open), Bound(one(T), :closed)))
    )
end
@outer_constructor(GammaRationalClass, (1,1,0.5))
@inline iscomposable(::GammaRationalClass, f::RealFunction) = isnegdef(f) && isnonnegative(f)
@inline composition{T<:AbstractFloat}(g::GammaRationalClass{T}, z::T) = (1 + g.alpha*z^g.gamma)^(-g.beta)


doc"RationalClass(f;α,β,γ) = (1 + α⋅f)⁻ᵝ"
immutable RationalClass{T<:AbstractFloat} <: PositiveMercerClass{T}
    alpha::HyperParameter{T}
    beta::HyperParameter{T}
    RationalClass(α::Variable{T}, β::Variable{T}) = new(
        HyperParameter(α, leftbounded(zero(T), :open)),
        HyperParameter(β, leftbounded(zero(T), :open))
    )
end
@outer_constructor(RationalClass, (1,1))
@inline iscomposable(::RationalClass, f::RealFunction) = isnegdef(f) && isnonnegative(f)
@inline composition{T<:AbstractFloat}(g::RationalClass{T}, z::T) = (1 + g.alpha*z)^(-g.beta)


doc"MatérnClass(f;ν,ρ) = 2ᵛ⁻¹(√(2ν)f/ρ)ᵛKᵥ(√(2ν)f/ρ)/Γ(ν)"
immutable MaternClass{T<:AbstractFloat} <: PositiveMercerClass{T}
    nu::HyperParameter{T}
    rho::HyperParameter{T}
    MaternClass(ν::Variable{T}, ρ::Variable{T}) = new(
        HyperParameter(ν, leftbounded(zero(T), :open)),
        HyperParameter(ρ, leftbounded(zero(T), :open))
    )
end
@outer_constructor(MaternClass, (1,1))
@inline iscomposable(::MaternClass, f::RealFunction) = isnegdef(f) && isnonnegative(f)
@inline function composition{T<:AbstractFloat}(g::MaternClass{T}, z::T)
    v1 = sqrt(2g.nu) * z / g.rho
    v1 = v1 < eps(T) ? eps(T) : v1  # Overflow risk, z -> Inf
    2 * (v1/2)^(g.nu) * besselk(g.nu, v1) / gamma(g.nu)
end


doc"ExponentiatedClass(f;α) = exp(a⋅f + c)"
immutable ExponentiatedClass{T<:AbstractFloat} <: PositiveMercerClass{T}
    a::HyperParameter{T}
    c::HyperParameter{T}
    ExponentiatedClass(a::Variable{T}, c::Variable{T}) = new(
        HyperParameter(a, leftbounded(zero(T), :open)),
        HyperParameter(c, leftbounded(zero(T), :closed))
    )
end
@outer_constructor(ExponentiatedClass, (1,0))
@inline iscomposable(::ExponentiatedClass, f::RealFunction) = ismercer(f)
@inline composition{T<:AbstractFloat}(g::ExponentiatedClass{T}, z::T) = exp(g.a*z + g.c)


#== Other Mercer Classes ==#

doc"PolynomialClass(f;a,c,d) = (a⋅f + c)ᵈ"
immutable PolynomialClass{T<:AbstractFloat,U<:Integer} <: CompositionClass{T}
    a::HyperParameter{T}
    c::HyperParameter{T}
    d::HyperParameter{U}
    PolynomialClass(a::Variable{T}, c::Variable{T}, d::Variable{U}) = new(
        HyperParameter(a, leftbounded(zero(T), :open)),
        HyperParameter(c, leftbounded(zero(T), :closed)),
        HyperParameter(d, leftbounded(one(U),  :closed))
    )
end
@outer_constructor(PolynomialClass, (1,0,3))
@inline iscomposable(::PolynomialClass, f::RealFunction) = ismercer(f)
@inline composition{T<:AbstractFloat}(g::PolynomialClass{T}, z::T) = (g.a*z + g.c)^g.d
@inline ismercer(::PolynomialClass) = true


#== Non-Negative Negative Definite Kernel Classes ==#

abstract NonNegNegDefClass{T<:AbstractFloat} <: CompositionClass{T}
@inline isnegdef(::NonNegNegDefClass) = true
@inline attainsnegative(::NonNegNegDefClass) = false

doc"PowerClass(z;a,c,γ) = (az + c)ᵞ"
immutable PowerClass{T<:AbstractFloat} <: NonNegNegDefClass{T}
    a::HyperParameter{T}
    c::HyperParameter{T}
    gamma::HyperParameter{T}
    PowerClass(a::Variable{T}, c::Variable{T}, γ::Variable{T}) = new(
        HyperParameter(a, leftbounded(zero(T), :open)),
        HyperParameter(c, leftbounded(zero(T), :closed)),
        HyperParameter(γ, Interval(Bound(zero(T), :open), Bound(one(T), :closed)))
    )
end
@outer_constructor(PowerClass, (1,0,0.5))
@inline iscomposable(::PowerClass, f::RealFunction) = isnegdef(f) && isnonnegative(f)
@inline composition{T<:AbstractFloat}(g::PowerClass{T}, z::T) = (g.a*z + g.c)^(g.gamma)


doc"GammmaLogClass(z;α,γ) = log(1 + α⋅zᵞ)"
immutable GammaLogClass{T<:AbstractFloat} <: NonNegNegDefClass{T}
    alpha::HyperParameter{T}
    gamma::HyperParameter{T}
    GammaLogClass(α::Variable{T}, γ::Variable{T}) = new(
        HyperParameter(α, leftbounded(zero(T), :open)),
        HyperParameter(γ, Interval(Bound(zero(T), :open), Bound(one(T), :closed)))
    )
end
@outer_constructor(GammaLogClass, (1,0.5))
@inline iscomposable(::GammaLogClass, f::RealFunction) = isnegdef(f) && isnonnegative(f)
@inline composition{T<:AbstractFloat}(g::GammaLogClass{T}, z::T) = log(g.alpha*z^(g.gamma) + 1)


doc"LogClass(z;α) = log(1 + α⋅z)"
immutable LogClass{T<:AbstractFloat} <: NonNegNegDefClass{T}
    alpha::HyperParameter{T}
    LogClass(α::Variable{T}) = new(
        HyperParameter(α, leftbounded(zero(T), :open))
    )
end
@outer_constructor(LogClass, (1,))
@inline iscomposable(::LogClass, f::RealFunction) = isnegdef(f) && isnonnegative(f)
@inline composition{T<:AbstractFloat}(g::LogClass{T}, z::T) = log(g.alpha*z + 1)


#== Non-Mercer, Non-Negative Definite Classes ==#

doc"SigmoidClass(f;α,c) = tanh(a⋅f + c)"
immutable SigmoidClass{T<:AbstractFloat} <: CompositionClass{T}
    a::HyperParameter{T}
    c::HyperParameter{T}
    SigmoidClass(a::Variable{T}, c::Variable{T}) = new(
        HyperParameter(a, leftbounded(zero(T), :open)),
        HyperParameter(c, leftbounded(zero(T), :closed))   
    )
end
@outer_constructor(SigmoidClass, (1,0))
@inline iscomposable(::SigmoidClass, f::RealFunction) = ismercer(f)
@inline composition{T<:AbstractFloat}(g::SigmoidClass{T}, z::T) = tanh(g.a*z + g.c)


#===================================================================================================
  Kernel Composition ψ = g(f(x,y))
===================================================================================================#

doc"CompositeRealFunction(g,f) = g∘f"
immutable CompositeRealFunction{T<:AbstractFloat} <: RealFunction{T}
    g::CompositionClass{T}
    f::PairwiseRealFunction{T}
    function CompositeRealFunction(g::CompositionClass{T}, f::PairwiseRealFunction{T})
        iscomposable(g, f) || error("Kernel is not composable.")
        new(g, f)
    end
end
function CompositeRealFunction{T<:AbstractFloat}(g::CompositionClass{T}, f::PairwiseRealFunction{T})
    CompositeRealFunction{T}(g, f)
end

∘(g::CompositionClass, f::PairwiseRealFunction) = CompositeRealFunction(g, f)

function convert{T<:AbstractFloat}(::Type{CompositeRealFunction{T}}, f::CompositeRealFunction)
    CompositeRealFunction(convert(CompositionClass{T}, f.g), convert(Kernel{T}, f.f))
end

function description_string(f::CompositeRealFunction, showtype::Bool = true)
    obj_str = string("CompositeRealFunction", showtype ? string("{", eltype(f), "}") : "")
    class_str = description_string(f.g, false)
    kernel_str = description_string(f.f, false)
    string(obj_str, "(g=", class_str, ",f=", kernel_str, ")")
end

==(ψ1::CompositeRealFunction, ψ2::CompositeRealFunction) = (ψ1.g == ψ2.g) && (ψ1.f == ψ2.f)

ismercer(f::CompositeRealFunction) = ismercer(f.g)
isnegdef(f::CompositeRealFunction) = isnegdef(f.g)

attainszero(f::CompositeRealFunction)     = attainszero(f.g)
attainspositive(f::CompositeRealFunction) = attainspositive(f.g)
attainsnegative(f::CompositeRealFunction) = attainsnegative(f.g)


#== Composition Kernels ==#

doc"GaussianKernel(α) = exp(-α⋅‖x-y‖²)"
function GaussianKernel{T<:AbstractFloat}(α::Argument{T} = 1.0)
    CompositeRealFunction(ExponentialClass(α), SquaredEuclidean{T}())
end
SquaredExponentialKernel = GaussianKernel
RadialBasisKernel = GaussianKernel

doc"LaplacianKernel(α) = exp(α⋅‖x-y‖)"
function LaplacianKernel{T<:AbstractFloat}(α::Argument{T} = 1.0)
    CompositeRealFunction(GammaExponentialClass(α, convert(T, 0.5)), SquaredEuclidean{T}())
end

doc"PeriodicKernel(α,p) = exp(-α⋅Σⱼsin²(p(xⱼ-yⱼ)))"
function PeriodicKernel{T<:AbstractFloat}(α::Argument{T} = 1.0, p::Argument{T} = convert(T, π))
    CompositeRealFunction(ExponentialClass(α), SineSquaredKernel(p))
end

doc"RationalQuadraticKernel(α,β) = (1 + α⋅‖x-y‖²)⁻ᵝ"
function RationalQuadraticKernel{T<:AbstractFloat}(α::Argument{T} = 1.0, β::Argument{T} = one(T))
    CompositeRealFunction(RationalClass(α, β), SquaredEuclidean{T}())
end

doc"MatérnKernel(ν,θ) = 2ᵛ⁻¹(√(2ν)‖x-y‖²/θ)ᵛKᵥ(√(2ν)‖x-y‖²/θ)/Γ(ν)"
function MaternKernel{T<:AbstractFloat}(ν::Argument{T} = 1.0, θ::Argument{T} = one(T))
    CompositeRealFunction(MaternClass(ν, θ), SquaredEuclidean{T}())
end
MatérnKernel = MaternKernel

doc"PolynomialKernel(a,c,d) = (a⋅xᵀy + c)ᵈ"
function PolynomialKernel{T<:AbstractFloat,U<:Integer}(
        a::Argument{T} = 1.0,
        c::Argument{T} = one(T),
        d::Argument{U} = 3
    )
    CompositeRealFunction(PolynomialClass(a, c, d), ScalarProduct{T}())
end

doc"LinearKernel(α,c,d) = a⋅xᵀy + c"
function LinearKernel{T<:AbstractFloat}(a::Argument{T} = 1.0, c::Argument{T} = one(T))
    CompositeRealFunction(PolynomialClass(a, c, 1), ScalarProduct{T}())
end

doc"SigmoidKernel(α,c) = tanh(a⋅xᵀy + c)"
function SigmoidKernel{T<:Real}(a::Argument{T} = 1.0, c::Argument{T} = one(T))
    CompositeRealFunction(SigmoidClass(a, c), ScalarProduct{T}())
end


#== Special Compositions ==#

function ^{T<:AbstractFloat}(f::PairwiseRealFunction{T}, d::Integer)
    CompositeRealFunction(PolynomialClass(one(T), zero(T), d), f)
end

function ^{T<:AbstractFloat}(f::PairwiseRealFunction{T}, γ::T)
    CompositeRealFunction(PowerClass(one(T), zero(T), γ), f)
end

function exp{T<:AbstractFloat}(f::PairwiseRealFunction{T})
    CompositeRealFunction(ExponentiatedClass(one(T), zero(T)), f)
end

function tanh{T<:AbstractFloat}(f::PairwiseRealFunction{T})
    CompositeRealFunction(SigmoidClass(one(T), zero(T)), f)
end