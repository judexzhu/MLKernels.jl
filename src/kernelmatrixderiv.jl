#===================================================================================================
  Kernel Derivative Matrices
===================================================================================================#

#==========================================================================
  Generic Kernel Derivative Matrices
==========================================================================#

function kernelmatrix_dx{T<:FloatingPoint}(κ::StandardKernel{T}, X::Matrix{T}, Y::Matrix{T}, trans::Char = 'N')
    is_trans = trans == 'T'  # True if columns are observations
    n = size(X, is_trans ? 2 : 1)
    m = size(Y, is_trans ? 2 : 1)
    if (d = size(X, is_trans ? 1 : 2)) != size(Y, is_trans ? 1 : 2)
        throw(ArgumentError("X and Y do not have the same number of " * (is_trans ? "rows." : "columns.")))
    end
    K = Array(T, d, n, m)
    if trans == 'N'
        for j = 1:m 
            for i = 1:n
                K[:,i,j] = kernel_dx(κ, X[i,:], Y[j,:])
            end
        end
    else
        for j = 1:m 
            for i = 1:n
                K[:,i,j] = kernel_dx(κ, X[:,i], Y[:,j])
            end
        end
    end
    reshape(K, (d*n, m))
end

function kernelmatrix_dy{T<:FloatingPoint}(κ::StandardKernel{T}, X::Matrix{T}, Y::Matrix{T}, trans::Char = 'N')
    is_trans = trans == 'T'  # True if columns are observations
    n = size(X, is_trans ? 2 : 1)
    m = size(Y, is_trans ? 2 : 1)
    if (d = size(X, is_trans ? 1 : 2)) != size(Y, is_trans ? 1 : 2)
        throw(ArgumentError("X and Y do not have the same number of " * (is_trans ? "rows." : "columns.")))
    end
    K = Array(T, d, n, m)
    if trans == 'N'
        for j = 1:m 
            for i = 1:n
                K[:,i,j] = kernel_dy(κ, X[i,:], Y[j,:])
            end
        end
    else
        for j = 1:m 
            for i = 1:n
                K[:,i,j] = kernel_dy(κ, X[:,i], Y[:,j])
            end
        end
    end
    reshape(permutedims(K, [2,1,3]), (n, d*m))
end


#==========================================================================
  Optimized Kernel Derivative Matrices for Squared Distance Kernels
==========================================================================#


function kernel_dxdy!{T<:FloatingPoint}(κ::SquaredDistanceKernel{T}, d::Int, A::Array{T}, i::Int, j::Int, X::Array{T}, Y::Array{T})
    #(d = length(x)) == length(y) == size(A,1) == size(A,2) || throw(ArgumentError("dimensions do not match"))
    #ϵᵀϵ = sqdist(X[i,:], Y[j,:])
    c = zero(T)
    @inbounds @simd for n = 1:d
        v = X[i,n] - Y[j,n]
        c += v*v
    end
    ϵᵀϵ = c
    a = kappa_dz(κ, ϵᵀϵ)
    b = kappa_dz2(κ, ϵᵀϵ)
    @inbounds for m = 1:d
        for n = 1:d
            A[n,i,m,j] = -4b * (X[i,n] - Y[j,n]) * (X[i,m] - Y[j,m])
        end
        A[m,i,m,j] -= 2a
    end
    A
end


function kernelmatrix_d2k_dxdy{T<:FloatingPoint}(κ::StandardKernel{T}, X::Matrix{T}, Y::Matrix{T}, trans::Char = 'N')
    is_trans = trans == 'T'  # True if columns are observations
    n = size(X, is_trans ? 2 : 1)
    m = size(Y, is_trans ? 2 : 1)
    if (d = size(X, is_trans ? 1 : 2)) != size(Y, is_trans ? 1 : 2)
        throw(ArgumentError("X and Y do not have the same number of " * (is_trans ? "rows." : "columns.")))
    end
    K = Array(T, d, n, d, m)
    if trans == 'N'
        @inbounds for j = 1:m 
            for i = 1:n
                #K[:,:,i,j] = kernel_dxdy(κ, X[i,:], Y[j,:])
                kernel_dxdy!(κ, d, K, i, j, X, Y)
            end
        end
    else
        warn("Not implemented properly")
        @inbounds for j = 1:m 
            for i = 1:n
                #K[:,:,i,j] = kernel_dxdy(κ, X[:,i], Y[:,j])
                kernel_dxdy!(κ, K, i, j, X[:,i], Y[:,j])
            end
        end
    end
    reshape(K, (d*n, d*m))
end



function kernelmatrix_d2k_dxdy{T<:FloatingPoint}(κ::StandardKernel{T}, X::Vector{T}, Y::Vector{T})
    n = length(X)
    m = length(Y)
    K = Array(T, n, m)
    @inbounds for j = 1:m 
        for i = 1:n
            K[i,j] = kernel_dxdy(κ, X[i], Y[j])
        end
    end
    K
end



# WIP/Experimentation - trthatcher

function trace_submatrix{T<:FloatingPoint}(A::Array{T}, d::Integer, x_pos::Integer, y_pos::Integer)
    a = zero(T)
    @inbounds for i = 1:d
        a += A[i,i,x_pos,y_pos]
    end
    a
end

function applykernel_dxdy!{T<:FloatingPoint}(κ::SquaredDistanceKernel, E::Array{T}, d::Integer, x_pos::Integer, y_pos::Integer)
    ϵᵀϵ = trace_submatrix(E, d, x_pos, y_pos)  # trace(A[:,:,i,j]) = Z[i,j] = ϵᵀϵ (vector outer product)
    ∂κ∂z = kappa_dz(κ, ϵᵀϵ)
    ∂κ²∂z² = kappa_dz2(κ, ϵᵀϵ)
    @inbounds for j = 1:d
        for i = 1:d
            E[i,j,x_pos,y_pos] *= -4∂κ²∂z²
        end
        E[j,j,x_pos,y_pos] += 2∂κ∂z
    end
    E
end

function kernelmatrix_dxdy{T<:FloatingPoint}(κ::SquaredDistanceKernel, X::Matrix{T}, Y::Matrix{T}, trans::Char = 'N')
    is_trans = trans == 'T'  # True if columns are observations
    n = size(X, is_trans ? 2 : 1)
    m = size(Y, is_trans ? 2 : 1)
    if (d = size(X, is_trans ? 1 : 2)) != size(Y, is_trans ? 1 : 2)
        throw(ArgumentError("X and Y do not have the same number of " * (is_trans ? "rows." : "columns.")))
    end
    E = tensor_epsilons(X, Y, trans) # A := (∂z/∂x)(∂x/∂y)ᵀ/4
    @inbounds for j = 1:m
        for i = 1:n
            applykernel_dxdy!(κ, E, d, i, j)
        end
    end
    E
end
