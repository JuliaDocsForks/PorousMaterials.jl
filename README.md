# PorousMaterials.jl

A software package in [Julia](https://julialang.org/) for classical molecular modeling in porous crystals.

For Julia to find the PorousMaterials.jl package, add the directory where the source code 
is found to the `LOAD_PATH` variable in Julia, for example:

```julia
push!(LOAD_PATH, homedir() * "/Dropbox/PorousMaterials.jl/src/")
```

Example use:

```julia
using PorousMaterials

# load abstract data structure containg crystal structure info
framework = read_crystal_structure_file("JAVTAC_clean.cif")

# replicate framework to .xyz for visualization
replicate_to_xyz(framework, "replicated_framework.xyz", repfactors=(2,3,1))

# load abstract data structure Lennard Jones force field (UFF)
forcefield = read_forcefield_file("UFF.csv") 

```

All input files are stored in `PorousMaterials.PATH_TO_DATA`, which by default is 
`pwd() * "/data/"`. The user can change this by editing `PorousMaterials.jl`.

## Crystal

Crystal structure files are stored in `PorousMaterials.PATH_TO_DATA * "crystals/"`. Crystals 
in .cif format must be in P1 symmetry. If your .cif is not in P1 symmetry, our function
`convert_cif_to_P1_symmetry()` calls the Atomic Simulation Environment (ASE) in Python to 
write the .cif in P1 symmetry.

For example:

```
# crystal structure files in `PATH_TO_DATA/crystals`.
convert_cif_to_P1_symmetry("myMOF_notP1.cif", "myMOF_P1.cif")
```

## Forcefield

Forcefield input files are stored in `PorousMaterials.PATH_TO_DATA * "forcefields/"`.

## Molecule/Adsorbate

Molecule input files are stored in `PorousMaterials.PATH_TO_DATA * "molecules/"`.

## Energetics

## TODO
-- `UFF.csv` epsilon units should be in Kelvin. Also the functional form for LJ potential is different for UFF so the sigmas should be modified. This can be done in DataFrames
-- Make a new `struct UnitCell` that stores attributes of unit cell, \alpha, \beta, \gamma, a, b, c, \Omega, f_to_c, c_to_f. This will be easier to pass around in downstream functions that only require the box instead of the entire framework.
-- Some requirements file?
-- (Cory can do) use PyCall to call ASE when unit cell does not exhibit P1 symmetry.
-- remove the .cssr reader support for now, but keep it in your Box? Seems that everyone works with .cif.
-- (Cory can do) put in function to write energy array to .cube file. Arni: might be faster to write to cube directly instead of store in gigantic matrix. Could cause computer to crash.
