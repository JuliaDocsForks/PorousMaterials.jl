using PorousMaterials
using Base.Test
using BenchmarkTools, Compat
framework = read_crystal_structure_file("NU-1000_Greg.cif")

 # kreps = (11, 11, 9)
 # α = 0.265058
sr_cutoff_r = 12.5
rep_factors = replication_factors(framework, sr_cutoff_r)
sim_box = replicate(framework.box, rep_factors)
framework = replicate(framework, rep_factors)
eparams, kvecs, eikar, eikbr, eikcr = setup_Ewald_sum(sr_cutoff_r, sim_box, verbose=false, ϵ=1e-6)

q_test = 0.8096

@testset "Ewald summation Tests" begin
    # ensure getting right Ewald settings
    #  note there are differnet method to choose
    #  these params for a givne precision so if you changed
    #  `determine_ewald_params` that may be ok if you still get the
    #  right electrostatic potential...
    @test eparams.kreps == (9, 9, 9)
    @test isapprox(eparams.α, 0.2471, atol=0.05)
    # construct box so recip. lattice is dimension (2, 10, 5)
    box = construct_box(0.5*2*π, 0.1*2*π, 0.2*2*π, π/2, π/2, π/2)
    @test PorousMaterials.required_kreps(box, 2.1^2) == (1, 0, 0)
    @test PorousMaterials.required_kreps(box, 5.1^2) == (2, 0, 1)
    @test PorousMaterials.required_kreps(box, 10.1^2) == (5, 1, 2)

    x = [9.535619863743, 20.685576379935, 0.127344239990]
    pc = PointCharge(q_test, x)
    m = Molecule(:pt_charge, LennardJonesSphere[], [pc], x)
    ϕ = electrostatic_potential_energy(framework, m, eparams, kvecs, eikar, eikbr, eikcr)
    @test isapprox(ϕ, 111373.38, atol=2.5)

    x = [4.269654927228, 23.137319129548, 28.352847101096]
    pc = PointCharge(q_test, x)
    m = Molecule(:pt_charge, LennardJonesSphere[], [pc], x)
    ϕ = electrostatic_potential_energy(framework, m, eparams, kvecs, eikar, eikbr, eikcr)
    @test isapprox(ϕ, -531.0, atol=0.5)

    x = [-0.047382031804, 7.209555961450, 5.158180463556]
    pc = PointCharge(q_test, x)
    m = Molecule(:pt_charge, LennardJonesSphere[], [pc], x)
    ϕ = electrostatic_potential_energy(framework, m, eparams, kvecs, eikar, eikbr, eikcr)
    @test isapprox(ϕ, -2676.8230141, atol=0.5)
end

# timing
x = [4.269654927228, 23.137319129548, 28.352847101096]
pc = PointCharge(q_test, x)
m = Molecule(:pt_charge, LennardJonesSphere[], [pc], x)
ϕ = electrostatic_potential_energy(framework, m, eparams, kvecs, eikar, eikbr, eikcr)
@btime electrostatic_potential_energy(framework, m, eparams, kvecs, eikar, eikbr, eikcr)
@profile electrostatic_potential_energy(framework, m, eparams, kvecs, eikar, eikbr, eikcr)
Profile.print()

 # ϕ = ϕ_sr(framework, x, rep_factors, sr_cutoff, α)
 # @btime ϕ_sr(framework, x, rep_factors, sr_cutoff, α)
 # 
 # ϕ = ϕ_lr(framework, x, sim_box, rep_factors, kvectors, α)
 # @btime ϕ_lr(framework, x, sim_box, rep_factors, kvectors, α)