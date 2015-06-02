#===================================================================================================
  Vector Operations
===================================================================================================#

function init_gramian{T<:FloatingPoint}(X::Matrix{T}, is_trans::Bool = false)
    n = size(X, is_trans ? 2 : 1)
    Array(T,n,n)
end

function init_gramian{T<:FloatingPoint}(X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    n, m = is_trans ? (size(X,2), size(Y,2)) : (size(X,1), size(Y,1))
    Array(T,n,m)
end

#==========================================================================
  Scalar Product Function (unweighted)
==========================================================================#

# Scalar product of vectors x and y
function scprod{T<:FloatingPoint}(x::Array{T}, y::Array{T})
    (n = length(x)) == length(y) || throw(ArgumentError("Dimensions do not conform."))
    z = zero(T)
    @inbounds @simd for i = 1:n
        z += x[i]*y[i]
    end
    z
end
scprod{T<:FloatingPoint}(x::T, y::T) =x*y

# In-place scalar product calculation
function scprod{T<:FloatingPoint}(d::Int64, X::Array{T}, x_pos::Int64, Y::Array{T}, y_pos::Int64, is_trans::Bool)
    z = zero(T)
    @transpose_access is_trans (X,Y) @inbounds for i = 1:d
        z += X[x_pos,i] * Y[y_pos,i]
    end
    z
end

# Partial derivative of the scalar product of vectors x and y
scprod_dx{T<:FloatingPoint}(x::Array{T}, y::Array{T}) = copy(y)
scprod_dy{T<:FloatingPoint}(x::Array{T}, y::Array{T}) = copy(x)

# Calculate the scalar product matrix (matrix of scalar products)
#    trans == 'N' -> Z = XXᵀ (X is a design matrix)
#             'T' -> Z = XᵀX (X is a transposed design matrix)
function scprodmatrix!{T<:FloatingPoint}(Z::Matrix{T}, X::Matrix{T}, is_trans::Bool = false, is_upper::Bool = true, sym::Bool = true)
    BLAS.syrk!(is_upper ? 'U' : 'L', is_trans ? 'T' : 'N', one(T), X, zero(T), Z)
    sym ? (is_upper ? syml!(Z) : symu!(Z)) : Z
end

function scprodmatrix{T<:FloatingPoint}(X::Matrix{T}, is_trans::Bool = false, is_upper::Bool = true, sym::Bool = true)
    scprodmatrix!(init_gramian(X, is_trans), X, is_trans, is_upper, sym)    
end

# Returns the upper right corner of the scalar product matrix of [Xᵀ Yᵀ]ᵀ or [X Y]
#   trans == 'N' -> Z = XYᵀ (X and Y are design matrices)
#            'T' -> Z = XᵀY (X and Y are transposed design matrices)
function scprodmatrix!{T<:FloatingPoint}(Z::Matrix{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    is_trans ? BLAS.gemm!('N', 'T', one(T), X, Y, zero(T), Z) : BLAS.gemm!('T', 'N', one(T), X, Y, zero(T), Z)
end

function scprodmatrix{T<:FloatingPoint}(X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    scprodmatrix!(init_gramian(X, Y, is_trans), X, Y, is_trans)
end


#==========================================================================
  Scalar Product Function (weighted)
==========================================================================#

# Weighted scalar product of x and y
function scprod{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    z = zero(T)
    @inbounds @simd for i = 1:n
        z += x[i] * y[i] * w[i]^2
    end
    z
end
scprod{T<:FloatingPoint}(x::T, y::T, w::T) = x*y*w^2

# In-place weighted scalar product calculation
function scprod{T<:FloatingPoint}(d::Int64, X::Array{T}, x_pos::Int64, Y::Array{T}, y_pos::Int64, w::Array{T}, is_trans::Bool)
    z = zero(T)
    @transpose_access is_trans (X,Y) @inbounds for i = 1:d
        z += X[x_pos,i] * Y[y_pos,i] * w[i]^2
    end
    z
end

function scprod_dx!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    @inbounds @simd for i = 1:n
        x[i] = y[i]*w[i]^2
    end
    x
end

function scprod_dw!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    @inbounds @simd for i = 1:n
        w[i] = 2x[i]*y[i]*w[i]
    end
    w
end


scprod_dy!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dx!(y, x, w)

scprod_dx{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dx!(similar(x), y, w)
scprod_dy{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dy!(x, similar(y), w)
scprod_dw{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = scprod_dw!(x, y, copy(w))

# Calculate the weighted scalar product matrix 
#    trans == 'N' -> Z = XDXᵀ (X is a design matrix and D = diag(w))
#             'T' -> Z = XᵀDX (X is a transposed design matrix and D = diag(w))
function scprodmatrix!{T<:FloatingPoint}(Z::Matrix{T}, X::Matrix{T}, w::Vector{T}, is_trans::Bool = false, is_upper::Bool = true, sym::Bool = true)
    scprodmatrix!(Z, is_trans ? scale(w, X) : scale(X, w), is_trans, is_upper, sym)
end

function scprodmatrix{T<:FloatingPoint}(X::Matrix{T}, w::Vector{T}, is_trans::Bool = false, is_upper::Bool = true, sym::Bool = true)
    scprodmatrix!(init_gramian(X, is_trans), X, w, is_trans, is_upper, sym)
end

# Returns the upper right corner of the scalar product matrix of [Xᵀ Yᵀ]ᵀ or [X Y]
#   trans == 'N' -> Z = XDYᵀ (X and Y are design matrices)
#            'T' -> Z = XᵀYD (X and Y are transposed design matrices)
function scprodmatrix!{T<:FloatingPoint}(Z::Matrix{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, is_trans::Bool = false)
    scprodmatrix!(Z, X, is_trans ? scale(Y, w.^2) : scale(w.^2, Y), is_trans)
end

function scprodmatrix{T<:FloatingPoint}(X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, is_trans::Bool = false)
    scprodmatrix!(init_gramian(X, Y, is_trans), X, Y, w, is_trans)
end


#==========================================================================
  Squared Distance Function (unweighted)
==========================================================================#
 
# Squared distance between vectors x and y
function sqdist{T<:FloatingPoint}(x::Array{T}, y::Array{T})
    (n = length(x)) == length(y) || throw(ArgumentError("Dimensions do not conform."))
    z = zero(T)
    @inbounds @simd for i = 1:n
        v = x[i] - y[i]
        z += v*v
    end
    z
end
function sqdist{T<:FloatingPoint}(x::T, y::T)
    v = x - y
    v*v
end

# In-place squared distance calculation
function sqdist{T<:FloatingPoint}(d::Int64, X::Array{T}, x_pos::Int64, Y::Array{T}, y_pos::Int64, is_trans::Bool)
    z = zero(T)
    @transpose_access is_trans (X,Y) @inbounds for i = 1:d
        v = X[x_pos,i] - Y[y_pos,i]
        z += v*v
    end
    z
end

sqdist_dx{T<:FloatingPoint}(x::Array{T}, y::Array{T}) = scale!(2, x - y)
sqdist_dy{T<:FloatingPoint}(x::Array{T}, y::Array{T}) = scale!(2, y - x)

# Calculates Z such that Zij is the dot product of the difference of row i and j of matrix X
#    trans == 'N' -> X is a design matrix
#             'T' -> X is a transposed design matrix
function sqdistmatrix!{T<:FloatingPoint}(Z::Matrix{T}, X::Matrix{T}, is_trans::Bool = false, is_upper::Bool = true, sym::Bool = true)
    scprodmatrix!(Z, X, is_trans, is_upper, false)  # Don't symmetrize yet
    n = size(X, is_trans ? 1 : 2)
    xᵀx = diag(Z)
    @inbounds for j = 1:n
        for i = is_upper ? (1:j) : (j:n)
            Z[i,j] = xᵀx[i] - 2Z[i,j] + xᵀx[j]
        end
    end
    sym ? (is_upper ? syml!(Z) : symu!(Z)) : Z
end

function sqdistmatrix{T<:FloatingPoint}(X::Matrix{T}, is_trans::Bool = false, is_upper::Bool = true, sym::Bool = true)
    sqdistmatrix!(init_gramian(X, is_trans), X, is_trans, is_upper, sym)
end


# Calculates the upper right corner, Z, of the squared distance matrix of matrix [Xᵀ Yᵀ]ᵀ
#   trans == 'N' -> X and Y are design matrices
#            'T' -> X and Y are transposed design matrices
function sqdistmatrix!{T<:FloatingPoint}(Z::Matrix{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = true)
    n = size(X, is_trans ? 2 : 1)
    m = size(Y, is_trans ? 2 : 1)
    xᵀx = is_trans ? dot_columns(X) : dot_rows(X)
    yᵀy = is_trans ? dot_columns(Y) : dot_rows(Y)
    scprodmatrix!(Z, X, Y, is_trans)
    @inbounds for j = 1:m
        for i = 1:n
            Z[i,j] = xᵀx[i] - 2Z[i,j] + yᵀy[j]
        end
    end
    Z
end

function sqdistmatrix{T<:FloatingPoint}(X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    sqdistmatrix!(init_gramian(X, Y, is_trans), X, Y, is_trans)
end


#==========================================================================
  Squared Distance Function (weighted)
==========================================================================#

# Weighted squared distance function between vectors x and y
function sqdist{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    z = zero(T)
    @inbounds @simd for i = 1:n
        v = (x[i] - y[i]) * w[i]
        z += v*v
    end
    z
end
function sqdist{T<:FloatingPoint}(x::T, y::T, w::T)
    v = w*(x - y)
    v*v
end

# In-place weighted squared distance calculation
function sqdist{T<:FloatingPoint}(d::Int64, X::Array{T}, x_pos::Int64, Y::Array{T}, y_pos::Int64, w::Array{T}, is_trans::Bool)
    z = zero(T)
    @transpose_access is_trans (X,Y) @inbounds for i = 1:d
        v = (X[x_pos,i] - Y[y_pos,i]) * w[i]
        z += v*v
    end
    z
end

function sqdist_dx!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    @inbounds @simd for i = 1:n
        x[i] = 2(x[i] - y[i]) * w[i]^2
    end
    x
end

sqdist_dy!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = sqdist_dx!(y, x, w)

function sqdist_dw!{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T})
    (n = length(x)) == length(y) == length(w) || throw(ArgumentError("Dimensions do not conform."))
    @inbounds @simd for i = 1:n
        w[i] = 2(x[i] - y[i])^2 * w[i]
    end
    w
end

sqdist_dx{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = sqdist_dx!(copy(x), y, w)
sqdist_dy{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = sqdist_dy!(x, copy(y), w)
sqdist_dw{T<:FloatingPoint}(x::Array{T}, y::Array{T}, w::Array{T}) = sqdist_dw!(x, y, copy(w))

# Calculates Z such that Zij is the dot product of the difference of row i and j of matrix X
#    trans == 'N' -> X is a design matrix
#             'T' -> X is a transposed design matrix
function sqdistmatrix!{T<:FloatingPoint}(Z::Matrix{T}, X::Matrix{T}, w::Vector{T}, is_trans::Bool = false, is_upper::Bool = true, sym::Bool = true)
    scprodmatrix!(Z, X, w, is_trans, is_upper, false)
    n = size(X, is_trans ? 2 : 1)
    xᵀDx = diag(Z)
    @inbounds for j = 1:n
        for i = is_upper ? (1:j) : (j:n)
            Z[i,j] = xᵀDx[i] - 2Z[i,j] + xᵀDx[j]
        end
    end
    sym ? (is_upper ? syml!(Z) : symu!(Z)) : Z
end

function sqdistmatrix{T<:FloatingPoint}(X::Matrix{T}, w::Vector{T}, is_trans::Bool = false, is_upper::Bool = true, sym::Bool = true)
    sqdistmatrix!(init_gramian(X, is_trans), X, w, is_trans, is_upper, sym)
end

# Calculates the upper right corner, Z, of the squared distance matrix of matrix [Xᵀ Yᵀ]ᵀ
#   trans == 'N' -> X and Y are design matrices
#            'T' -> X and Y are transposed design matrices
function sqdistmatrix!{T<:FloatingPoint}(Z::Matrix{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, is_trans::Bool = false)
    n = size(X, is_trans ? 2 : 1)
    m = size(Y, is_trans ? 2 : 1)
    w² = vec(w.^2)
    xᵀDx = is_trans ? dot_columns(X, w²) : dot_rows(X, w²)
    yᵀDy = is_trans ? dot_columns(Y, w²) : dot_rows(Y, w²)
    scprodmatrix!(Z, X, !is_trans ? scale(w², Y) : scale(Y, w²), is_trans)
    @inbounds for j = 1:m
        for i = 1:n
            Z[i,j] = xᵀDx[i] - 2Z[i,j] + yᵀDy[j]
        end
    end
    Z
end

function sqdistmatrix{T<:FloatingPoint}(X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, is_trans::Bool = false)
    sqdistmatrix!(init_gramian(X, Y, is_trans), X, Y, w, is_trans)
end
