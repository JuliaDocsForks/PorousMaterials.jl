<<<<<<< HEAD
# Calculates the properties of a real gas, such as the compressibility factor, fugacity,
#   and molar volume.
=======
using Polynomials
using DataFrames
using CSV
using Roots

"""
Calculates the properties of a real gas, such as the compressibility factor, fugacity,
and molar volume.
"""
>>>>>>> Done?

# Universal gas constant (R). units: m³-bar/(K-mol)
const R = 8.3144598e-5

# Data structure stating characteristics of a Peng-Robinson gas
struct PengRobinsonGas
<<<<<<< HEAD
    "Peng-Robinson Gas species. e.g. :CO2"
    gas::Symbol
    "Critical temperature (units: Kelvin)"
    Tc::Float64
    "Critical pressure (units: bar)"
    Pc::Float64
    "Acentric factor (units: unitless)"
    ω::Float64
end

=======
  "Peng-Robinson Gas species. e.g. :CO2"
  gas::Symbol
  "Critical temperature (units: Kelvin)"
  Tc::Float64
  "Critical pressure (units: bar)"
  Pc::Float64
  "Acentric factor (units: unitless)"
  ω::Float64
end


#Data structure stating characteristics of a Van der Waals gas
struct vdWMolecule
  #VDW constant a (units: m⁶bar/mol)
  a::Float64
  #VDW constant b (unites: m³/mol)
  b::Float64
  gas::Symbol
end


>>>>>>> Done?
# Parameters in the Peng-Robinson Equation of State
# T in Kelvin, P in bar
a(gas::PengRobinsonGas) = (0.457235 * R ^ 2 * gas.Tc ^ 2) / gas.Pc
b(gas::PengRobinsonGas) = (0.0777961 * R * gas.Tc) / gas.Pc
κ(gas::PengRobinsonGas) = 0.37464 + (1.54226 * gas.ω) - (0.26992 * gas.ω ^ 2)
α(κ::Float64, Tr::Float64) = (1 + κ * (1 - √Tr)) ^ 2
A(T::Float64, P::Float64, gas::PengRobinsonGas) = α(κ(gas), T / gas.Tc) * a(gas) * P / (R ^ 2 * T ^ 2)
B(T::Float64, P::Float64, gas::PengRobinsonGas) = b(gas) * P / (R * T)

# Calculates three outputs for compressibility factor using the polynomial form of
# the Peng-Robinson Equation of State. Filters for only real roots and returns the
# root closest to unity.
function compressibility_factor(gas::PengRobinsonGas, T::Float64, P::Float64)
    # construct cubic polynomial in z
    p = Poly([-(A(T, P, gas) * B(T, P, gas) - B(T, P, gas) ^ 2 - B(T, P, gas) ^ 3),
              A(T, P, gas) - 2 * B(T, P, gas) - 3 * B(T, P, gas) ^ 2,
              -(1.0 - B(T, P, gas)),
              1.0])
    # solve for the roots of the cubic polynomial
    z_roots = roots(p)
    # select real roots only.
    z_factor = z_roots[isreal.(z_roots)]
    # find the index of the root that is closest to unity
    id_closest_to_unity = argmin(abs.(z_factor .- 1.0))
    # return root closest to unity.
    return real(z_factor[id_closest_to_unity])
end

# Calculating for fugacity coefficient from an integration (bar).
function calculate_ϕ(gas::PengRobinsonGas, T::Float64, P::Float64)
    z = compressibility_factor(gas, T, P)
    log_ϕ = z - 1.0 - log(z - B(T, P, gas)) +
            - A(T, P, gas) / (√8 * B(T, P, gas)) * log(
            (z + (1 + √2) * B(T, P, gas)) / (z + (1 - √(2)) * B(T, P, gas)))
    return exp(log_ϕ)
end

"""
<<<<<<< HEAD
    props = calculate_properties(gas, T, P, verbose=true)
=======
    props = calculate_properties = (gas, T, P)
>>>>>>> Done?

Use equation of state to calculate density, fugacity, and molar volume of a real gas at a
given temperature and pressure.

# Arguments
<<<<<<< HEAD
- `gas::PengRobinsonGas`: Peng-Robinson gas data structure
- `T::Float64`: Temperature (units: Kelvin)
- `P::Float64`: Pressure (units: bar)
=======
- `gas::PengRobinsonGas`: Peng-Robinson gas structure
- `T::Float64`: Temperature given in Kelvin
- `P::Float64`: Pressure given in bar
>>>>>>> Done?
- `verbose::Bool`: print results

# Returns
- `prop_dict::Dict`: Dictionary of Peng-Robinson gas properties
"""
function calculate_properties(gas::PengRobinsonGas, T::Float64, P::Float64; verbose::Bool=true)
    # Compressbility factor (unitless)
    z = compressibility_factor(gas, T, P)
    # Density (mol/m^3)
    ρ = P / (z * R * T)
    # Molar volume (L/mol)
    Vm = 1.0 / ρ * 1000.0
    # Fugacity (bar)
    ϕ = calculate_ϕ(gas, T, P)
    f = ϕ * P
    # Prints a dictionary holding values for compressibility factor, molar volume, density, and fugacity.
    prop_dict = Dict("compressibility factor" => z, "molar volume (L/mol)"=> Vm ,
                     "density (mol/m³)" => ρ, "fugacity (bar)" => f,
                     "fugacity coefficient" => ϕ)
    if verbose
        @printf("%s properties at T = %f K, P = %f bar:\n", gas.gas, T, P)
        for (property, value) in prop_dict
            println("\t" * property * ": ", value)
        end
    end
    return prop_dict
end

function calculate_properties(gas::vdWMolecule, T::Float64, P::Float64)

    A = -P
    B = (P * gas.b + R * T)
    C = -gas.a
    D = gas.a * gas.b

    #Creates a polynomial for the vdw cubic function
    pol = Poly([A, B, C, D])
    #finds roots of that polynomial
    polroots = roots(pol)
    #assigns rho to be the real root and then makes it real to get rid of the 0im
    rho = real.(polroots[isreal.(polroots)])

    #specifies that molar volume is the reciprocal of the density
    # In units of L/mol
    vm = (1./ rho) * 1000
    #specifies the compressibility factor
    z = (P * (1./ rho))./ (R * T)

    #Finds fugacity using the derivation from the Van der Waals
    fug = P .* exp. (- log. (((1 ./ rho) - gas.b) * P./(R * T))+(gas.b ./ ((1 ./ rho)-gas.b) - 2*gas.a*rho/(R*T)))
    #defines the fugacity coefficient as fugacity over pressure
    ϕ = fug ./ P

    prop_dict = Dict("Density (mol/m³)" => rho, "Fugacity (bar)" => fug, "Molar Volume (L/mol)" => vm, "Fugacity Coefficient" => ϕ, "Compressibility Factor" => z )
end

"""
    gas = VDWGas(gas)

<<<<<<< HEAD
Reads in critical temperature, critical pressure, and acentric factor of the `gas::Symbol`
from the properties .csv file `joinpath(PorousMaterials.PATH_TO_DATA, "PengRobinsonGasProps.csv")`
and returns a complete `PengRobinsonGas` data structure.
**NOTE: Do not delete the last three comment lines in PengRobinsonGasProps.csv
=======
Reads in vdw constants a and b of the `gas::Symbol`
from the properties .csv file `PorousMaterials.PATH_TO_DATA * "vds_constants.csv"`
and returns a complete `VDWMolecule` data structure.
>>>>>>> Done?

# Returns
- `VDWMolecule::struct`: Data structure containing Peng-Robinson gas parameters.
"""
<<<<<<< HEAD
=======

function VDWGas(gas::Symbol)

    vdwfile = CSV.read(PATH_TO_DATA * "vdw_constants.csv")
    if ! (string(gas) in vdwfile[:molecule])
          error(@sprintf("Gas %s properties not found in %svdw_constants.csv", gas, PATH_TO_DATA))
    end
    gas = string(gas)
    A = vdwfile[vdwfile[:molecule].== gas, Symbol("a(m6bar/mol)")]
    B = vdwfile[vdwfile[:molecule].== gas, Symbol("b(m3/mol)")]
    return vdWMolecule(A[1], B[1], gas)

end

"""
    gas = PengRobinsonGas(gas)

Reads in critical temperature, critical pressure, and acentric factor of the `gas::Symbol`
from the properties .csv file `PorousMaterials.PATH_TO_DATA * "PengRobinsonGasProps.csv"`
and returns a complete `PengRobinsonGas` data structure.

# Returns
- `PengRobinsonGas::struct`: Data structure containing Peng-Robinson gas parameters.
"""

>>>>>>> Done?
function PengRobinsonGas(gas::Symbol)
    df = CSV.read(joinpath(PATH_TO_DATA, "PengRobinsonGasProps.csv"); footerskip=3)
    if ! (string(gas) in df[:gas])
        error(@sprintf("Gas %s properties not found in %sPengRobinsonGasProps.csv", gas, PATH_TO_DATA))
    end
    Tc = df[df[:gas].== string(gas), Symbol("Tc(K)")][1]
    Pc = df[df[:gas].== string(gas), Symbol("Pc(bar)")][1]
    ω = df[df[:gas].== string(gas), Symbol("acentric_factor")][1]
    return PengRobinsonGas(gas, Tc, Pc, ω)
end

# Prints resulting values for Peng-Robinson gas properties
function Base.show(io::IO, gas::PengRobinsonGas)
    println(io, "Gas species: ", gas.gas)
<<<<<<< HEAD
    println(io, "\tCritical temperature (K): ", gas.Tc)
    println(io, "\tCritical pressure (bar): ", gas.Pc)
    println(io, "\tAcenteric factor: ", gas.ω)
=======
    println(io, "Critical temperature (K): ", gas.Tc)
    println(io, "Critical pressure (bar): ", gas.Pc)
    println(io, "Acenteric factor: ", gas.ω)
end

# Prints resulting values for Van der Waals gas properties
function Base.show(io::IO, gas::vdWMolecule)
    println(io, "Gas species: ", gas.gas)
    println(io, "Van der Waals constant a (m⁶bar/mol): ", gas.a)
    println(io, "Van der Waals constant b (m³/mol): ", gas.b)
>>>>>>> Done?
end
