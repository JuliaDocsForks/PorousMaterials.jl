"""All things crystal structures"""
module Crystal

export Framework, constructframework, replicate_to_xyz, correct_cssr_line, atom_error_check

global PATH_TO_STRUCTURE_FILES = homedir() * "/Dropbox/Code/PorousMaterials.jl/cssrFiles"

using Base.Test

"""
    framework = Framework(a, b, c, α, β, γ, N, atoms, f_coords, f_to_c, c_to_f)

Data structure for a 3D crystal structure.

# Arguments
- `a,b,c::Float64`: unit cell dimensions (units: Angstroms)
- `α,β,γ::Float64`: unit cell angles (units: radians)
- `n_atoms::Int64`: number of atoms in the unit cell
- `Ω::Float64`: volume of the unit cell (units: cubic Angtroms)
- `atoms::Array{String,1}`: list of (pseudo)atoms (e.g. elements) composing crystal unit cell, in strict order
- `f_coords::Array{Float64,2}`: a 2D array of fractional coordinates of the atoms, in strict order corresponding to `atoms`.
stored column-wise so that f_coords[:, 1] is first atom's fractional coordinates.
- `f_to_c::Array{Float64,2}`: a 3x3 matrix used to convert fractional coordinates to cartesian coordinates
- `c_to_f::Array{Float64,2}`: a 3x3 matrix used to convert cartesian coordinates to fractional coordinates
"""
struct Framework
    a::Float64
    b::Float64
    c::Float64

    α::Float64
    β::Float64
    γ::Float64

    Ω::Float64

    n_atoms::Int64
    atoms::Array{String, 1}
    f_coords::Array{Float64, 2}

    f_to_C::Array{Float64, 2}
    C_to_f::Array{Float64, 2}
end

"""
    framework = read_crystal_structure_file("filename.cssr")

Read a crystal structure file (.cif or .cssr) and construct a Framework object
"""
function read_crystal_structure_file(filename::String)
    # read file extension, ensure reader implemented.
    extension = split(filename, ".")[end]
    if ! (extension in ["cif", "cssr"])
        error("PorousMaterials.jl can only read .cif or .cssr crystal structure files.")
    end
    
    # read in crystal structure file
    if ! isfile(filename)
        error(@printf("Could not open crystal structure file %s\n", filename))
    end
    f = open(filename, "r")
    lines = readlines(f)
    close(f)
    # TODO This reader is a mishmash of a lot of things. This needs to be cleaned up!

    if extension == "cssr"
        # Initialize variables
        charges = Float64[]
        n_atoms = length(lines) - 5
        a, b, c, α, β, γ = Array{Float64}(6)
        x = Array{Float64}(n_atoms) # fractional
        y = similar(x)
        z = similar(x)
        atoms = Array{String}(n_atoms)

        # Make a boolean variable to fix discrepency with fractional and cartesian coordinates in cssr files
        corr = false
        for line in lines[6:6+16]
            str = split(line)
            for val in str[3:5]
                # Check if values are fractional or not. I only check 10 lines, which is probably enough.
                if parse(Float64,val)>1
                    corr = true
                    break
                end
            end
        end

        # Iterate through the lines of the cssr file.
        for (i,line) in enumerate(lines)
            str = split(line)
            # Unit cell dimension line
            if i == 1
                a, b, c = map(x->parse(Float64, x), str[end-2:end])
            # Unit cell angle line
            elseif i == 2
                temp = zeros(3)
                cnt = 1
                for val in str
                    try
                        temp[cnt] = parse(Float64,val)*π/180
                        cnt += 1
                    end
                end
                α, β, γ = temp[1:3]
            # Atom lines
            elseif i > 5
                try # Fix faulty cssr files where columns one and two merge for some reason
                    parse(Float64,str[1])
                catch
                    str = correct_cssr_line(str)
                end

                # Fix element column where some cssr files have a number concated to the end of the element tag (e.g. H3)
                tempch = ""
                for ch in str[2]
                    if !isdigit(ch)
                        tempch = string(tempch,ch)
                    end
                end
                atoms[i - 5] = tempch
                # Use the correction boolean to fix fractional/cartesian discrepency
                if corr
                    x[i - 5], y[i - 5], z[i - 5] = map(x->parse(Float64, x), str[3:5])./[a, b, c]
    				if i == 6
    					@printf("x = %f, y = %f, z = %f\n",x[i-5],y[i-5],z[i-5])
    				end
                else
                    x[i - 5], y[i - 5], z[i - 5] = map(x->parse(Float64, x), str[3:5])
                end
            end
        end
    end

    # Cif reader from Cory Simon
    if extension == "cif"
        data = Dict()
        charges = Float64[]
        x = Float64[]
        y = Float64[]
        z = Float64[]
        atoms = String[]

        loop_starts = -1
        for i = 1:length(lines)
            line = split(lines[i])
            if length(line) == 0
                continue
            end
            if line[1] == "_symmetry_space_group_name_H-M"
                if length(line) == 3
                    @assert(contains(line[2] * line[3], "P1") || contains(line[2] * line[3], "P 1"), ".cif must have P1 symmetry.\n")
                elseif length(line) == 2
                    @assert(contains(line[2], "P1") || contains(line[2], "P 1"), ".cif must have P1 symmetry\n")
                else
                    println(line)
                    error("Does this .cif have P1 symmetry?")
                end
            end

            for axis in ["a", "b", "c"]
                if line[1] == @sprintf("_cell_length_%s", axis)
                    data[axis] = parse(Float64, line[2])
                end
            end
            for angle in ["alpha", "beta", "gamma"]
                if line[1] == @sprintf("_cell_angle_%s", angle)
                    data[angle] = parse(Float64, line[2]) * pi / 180.0
                end
            end

            if (line[1] == "loop_")
                next_line = split(lines[i+1])
                if contains(next_line[1], "_atom_site")
                    loop_starts = i + 1
                    break
                end
            end
        end  # end loop over lines

        if loop_starts == -1
            error("Could not find _atom_site* after loop_ if .cif file\n")
        end

        # broke the loop. so loop_starts is line where "_loop" first starts
        # name_to_column is a dictionary that e.g. returns which column contains x fractional coord
        #   use example: name_to_column["_atom_site_fract_x"] gives 3
        atom_column_name = "_atom_site_type_symbol"  # this can be different for different .cifs...
        name_to_column = Dict{AbstractString, Int}()
        i = loop_starts
        while length(split(lines[i])) == 1
            if i == loop_starts
                atom_column_name = split(lines[i])[1]
            end
            name_to_column[split(lines[i])[1]] = i + 1 - loop_starts
            i += 1
        end

        # now extract fractional coords of atoms and their charges
        for i = loop_starts+length(name_to_column):length(lines)
            line = split(lines[i])
            if length(line) != length(name_to_column)
                break
            end
            push!(atoms, line[name_to_column[atom_column_name]])
            push!(x, mod(parse(Float64, line[name_to_column["_atom_site_fract_x"]]), 1.0))
            push!(y, mod(parse(Float64, line[name_to_column["_atom_site_fract_y"]]), 1.0))
            push!(z, mod(parse(Float64, line[name_to_column["_atom_site_fract_z"]]), 1.0))
            # if charges present, import them
            if haskey(name_to_column, "_atom_site_charge")
                push!(charges, parse(Float64, line[name_to_column["_atom_site_charge"]]))
            else
                push!(charges, 0.0)
            end
        end
        n_atoms = length(x)
        a = data["a"]
        b = data["b"]
        c = data["c"]
        α = data["alpha"]
        β = data["beta"]
        γ = data["gamma"]
    end

    Ω = a * b * c * sqrt(1 - cos(α) ^ 2 - cos(β) ^ 2 - cos(γ) ^ 2 + 2 * cos(α) * cos(β) * cos(γ))
    f_to_C = [[a, 0, 0] [b * cos(γ), b * sin(γ), 0] [c * cos(β), c * (cos(α) - cos(β) * cos(γ)) / sin(γ), Ω / (a * b * sin(γ))]]
    C_to_f = [[1/a, 0, 0] [-cos(γ) / (a * sin(γ)), 1 / (b * sin(γ)), 0] [b * c * (cos(α) * cos(γ) - cos(β)) / (Ω * sin(γ)), a * c * (cos(β) * cos(γ) - cos(α)) / (Ω * sin(γ)), a * b * sin(γ) / Ω]]

    @test f_to_C * C_to_f ≈ eye(3)
	fractional_coords = Array{Float64,2}(3,length(x))
	fractional_coords[1, :] = x[:]; fractional_coords[2, :] = y[:]; fractional_coords[3, :] = z[:]
    return Framework(a, b, c, α, β, γ, Ω, n_atoms, atoms, fractional_coords, f_to_C, C_to_f)
end # constructframework end

"""
    replicate_to_xyz(framework, xyzfilename, comment="", nx=0, ny=0, nz=0)

Write a .xyz file from a Framework object. Write an optional comment to the .xyz file if desired.
Extend the structure in the x-,y- or z-direction by changing nx, ny or nz respectively.
A value of 1 replicates the structure once in the desired direction
"""
function replicate_to_xyz(framework::Framework, xyzfilename::String; comment::String="", nx::Int=0, ny::Int=0, nz::Int=0)
    f = open(xyzfilename, "w")
    @printf(f, "%d\n%s\n", framework.n_atoms * (nx + 1) * (ny + 1) * (nz + 1), comment)

    for i = 0:nx, j = 0:ny, k = 0:nz
        f_coords = framework.f_coords .+ [i, j, k]
        c_coords = framework.f_to_C * f_coords
        for ii = 1:size(c_coords, 2)
            @printf(f, "%s\t%.4f\t%.4f\t%.4f\n", framework.atoms[ii], c_coords[1, ii], c_coords[2, ii], c_coords[3, ii])
        end
    end
    close(f)

    println("See ", xyzfilename)
    return
end # replicate_to_xyz end

"""
    corrected_line = correct_cssr_line(str)

Take an array of string values and correct an error from the openbabel python module.
The error merges two values together if the element abbreviation contains two letters,
such as Zn, Cl and so on.
"""
function correct_cssr_line(str)
    tempbool = Array{Bool}(length(str[1]),1)
    for (k,ch) in enumerate(str[1])
        tempbool[k] = isdigit(ch)
    end

    ind = findfirst(tempbool,false);
    unshift!(str,str[1][1:ind-1])
    str[2] = str[2][ind:end]

    for (k,ch) in enumerate(str[2])
        if isdigit(ch)
            str[2] = str[2][1:k-1]
            break
        end
    end
    return str
end #correct_cssr_line end

"""
    check_for_atom_overlap(framework; threshold_distance_for_overlap=0.1, verbose=false)

Check if any two atoms are lying on top of each other by calculating the 2-norm distance
between every pair of atoms and ensuring distance is greater than a threshold.
Throw error if atoms overlap and tell which atoms are culprit.
"""
function check_for_atom_overlap(framework::Framework; threshold_distance_for_overlap::Float64=0.1, verbose::Bool=false)
    for i = 1:framework.n_atoms
        xf_i = framework.f_coords[:, i]
        for j = i+1:framework.n_atoms
            xf_j = framework.f_coords[:, j]
            # vector pointing from atom j to atom i in carteisan coords
            dx = framework.f_to_C * (xf_i - xf_j)
            if (norm(dx) < threshold_distance_for_overlap)
                error(@printf("Atoms %d and %d are too close, distance %f Å) < %f Å threshold\n", i, j, norm(dx), threshold_distance_for_overlap))
            end
        end
    end
    if verbose
        @printf("No atoms are on top of each other!")
    end
    return
end

end # end module
