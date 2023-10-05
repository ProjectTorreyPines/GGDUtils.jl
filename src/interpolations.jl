import NearestNeighbors: KDTree, knn
import StaticArrays: SVector
import Statistics: mean
import Interpolations: linear_interpolation

function get_kdtree(space::OMAS.edge_profiles__grid_ggd___space)
    grid_nodes = space.objects_per_dimension[1].object
    grid_faces = space.objects_per_dimension[3].object
    grid_faces = [cell for cell ∈ grid_faces if length(cell.nodes) == 4]
    grid_centers = [
        SVector{2}(mean([grid_nodes[node].geometry for node ∈ cell.nodes])) for
        cell ∈ grid_faces
    ]
    return KDTree(grid_centers; leafsize=10)
end

function get_kdtree(
    space::OMAS.edge_profiles__grid_ggd___space,
    subset::OMAS.edge_profiles__grid_ggd___grid_subset,
)
    subset_centers = get_subset_centers(space, subset)
    return KDTree([SVector{2}(sc) for sc ∈ subset_centers]; leafsize=10)
end

"""
    interp(
    prop_values::Vector{T},
    kdtree::KDTree;
    use_nearest_n=4,

) where {T <: Real}

Lowest level interpolation function. It takes a vector of property values and a KDTree
defined over a 2D space with the same number of nodes as the property values. It returns
a function that can be used to interpolate the property values at any point in the
space.
"""
function interp(
    prop_values::Vector{T},
    kdtree::KDTree;
    use_nearest_n::Int=4,
) where {T <: Real}
    function get_interp_val(x::Real, y::Real)
        nearest_indices, distances = knn(kdtree, Array([x, y]), use_nearest_n)
        values = [prop_values[ii] for ii ∈ nearest_indices]
        weights = 1 ./ distances
        if any(isinf.(weights))
            return values[distances.==0][1]
        end
        return sum(weights .* values) / sum(weights)
    end
    get_interp_val(xy::Tuple{Real, Real}) = get_interp_val(xy...)
    return get_interp_val
end

"""
    interp(
    prop_values::Vector{T},
    space::OMAS.edge_profiles__grid_ggd___space;
    use_nearest_n::Int=4,

) where {T <: Real}

If the whole space is provided instead of a kdtree, calculate the kdtree for whole
space. Again, here it is assumed that the property values are porvided for each node
of the space.
"""
function interp(
    prop_values::Vector{T},
    space::OMAS.edge_profiles__grid_ggd___space;
    use_nearest_n::Int=4,
) where {T <: Real}
    return interp(prop, get_kdtree(space); use_nearest_n)
end

"""
    interp(
    prop_values::Vector{Real},
    space::OMAS.edge_profiles__grid_ggd___space,
    subset::OMAS.edge_profiles__grid_ggd___grid_subset;
    use_nearest_n::Int=4,

)

If a subset of the space is provided, calculate the kdtree for the subset. In this case
it is assumed that the property values are provided for each element of the subset.
"""
function interp(
    prop_values::Vector{T},
    space::OMAS.edge_profiles__grid_ggd___space,
    subset::OMAS.edge_profiles__grid_ggd___grid_subset;
    use_nearest_n::Int=4,
) where {T <: Real}
    return interp(prop_values, get_kdtree(space, subset); use_nearest_n)
end

"""
    interp(
    prop::edge_profiles__prop_on_subset,
    grid_ggd::OMAS.edge_profiles__grid_ggd,
    value_field::Symbol=:values;
    use_nearest_n::Int=4,

)

Example:
grid_ggd = dd.edge_profiles.grid_ggd[1]
get_electron_density = interp(dd.edge_profiles.ggd[1].electrons.density[1], grid_ggd)
get_e_field_par = interp(dd.edge_profiles.ggd[1].e_field[1], grid_ggd, :parallel)
"""
function interp(
    prop::edge_profiles__prop_on_subset,
    grid_ggd::OMAS.edge_profiles__grid_ggd,
    value_field::Symbol=:values;
    use_nearest_n::Int=4,
)
    subset = get_grid_subset_with_index(grid_ggd, prop.grid_subset_index)
    space = grid_ggd.space[subset.element[1].object[1].space]
    return interp(getfield(prop, value_field), space, subset; use_nearest_n)
end

"""
    interp(
    prop_arr::Vector{T},
    space::OMAS.edge_profiles__grid_ggd___space,
    subset::OMAS.edge_profiles__grid_ggd___grid_subset,
    value_field::Symbol=:values;
    use_nearest_n::Int=4,

) where {T <: edge_profiles__prop_on_subset}

Example:
sol = get_grid_subset_with_index(dd.edge_profiles.grid_ggd[1], 23)
get_electron_density = interp(dd.edge_profiles.ggd[1].electrons.density, space, sol)
"""
function interp(
    prop_arr::Vector{T},
    space::OMAS.edge_profiles__grid_ggd___space,
    subset::OMAS.edge_profiles__grid_ggd___grid_subset,
    value_field::Symbol=:values;
    use_nearest_n::Int=4,
) where {T <: edge_profiles__prop_on_subset}
    prop = get_prop_with_grid_subset_index(prop_arr, subset.identifier.index)
    return interp(getfield(prop, value_field), space, subset; use_nearest_n)
end

"""
    interp(
    prop_arr::Vector{T},
    grid_ggd::OMAS.edge_profiles__grid_ggd,
    grid_subset_index::Int,
    value_field::Symbol=:values;
    use_nearest_n::Int=4,

) where {T <: edge_profiles__prop_on_subset}

Example:
get_n_e_sep = interp(dd.edge_profiles.ggd[1].electrons.density, grid_ggd, 16)
"""
function interp(
    prop_arr::Vector{T},
    grid_ggd::OMAS.edge_profiles__grid_ggd,
    grid_subset_index::Int,
    value_field::Symbol=:values;
    use_nearest_n::Int=4,
) where {T <: edge_profiles__prop_on_subset}
    prop = get_prop_with_grid_subset_index(prop_arr, grid_subset_index)
    subset = get_grid_subset_with_index(grid_ggd, grid_subset_index)
    space = grid_ggd.space[subset.element[1].object[1].space]
    return interp(getfield(prop, value_field), space, subset; use_nearest_n)
end

const RHO_EXT_POS = [1.0001, 1.1, 5]
const RHO_EXT_NEG = [-5, -0.0001] # I guess this would be at a PF coil or something?

"""
    interp(eqt::OMAS.equilibrium__time_slice)

For a given equilibrium time slice, return a function that can be used to interpolate
from (r, z) space to rho (normalized toroidal flux coordinate)space.

Example:
rz2rho = interp(dd.equilibrium.time_slice[1])
rho = rz2rho.([(r, z) for r in 3:0.01:9, for z in -5:0.01:5])
"""
function interp(eqt::OMAS.equilibrium__time_slice)
    p1 = eqt.profiles_1d
    p2 = eqt.profiles_2d[1]
    gq = eqt.global_quantities
    psi_a = gq.psi_axis
    psi_b = gq.psi_boundary
    rhon_eq = p1.rho_tor_norm
    psi_eq = p1.psi
    psin_eq = (psi_eq .- psi_a) ./ (psi_b - psi_a)
    psirz = p2.psi
    psinrz = (psirz .- psi_a) ./ (psi_b - psi_a)
    r_eq = p2.grid.dim1
    z_eq = p2.grid.dim2
    # rho_N isn't defined on open flux surfaces, so it is extended by copying psi_N
    psin_eq_ext = copy(psin_eq)
    append!(psin_eq_ext, RHO_EXT_POS)
    rhon_eq_ext = copy(rhon_eq)
    append!(rhon_eq_ext, RHO_EXT_POS)
    prepend!(psin_eq_ext, RHO_EXT_NEG)
    prepend!(rhon_eq_ext, RHO_EXT_NEG)
    rz2psin = linear_interpolation((r_eq, z_eq), psinrz)
    psin2rhon = linear_interpolation(psin_eq_ext, rhon_eq_ext)
    get_interp_val(r::Real, z::Real) = psin2rhon(rz2psin(r, z))
    get_interp_val(rz::Tuple{Real, Real}) = get_interp_val(rz...)
    return get_interp_val
end

"""
    interp(
    prop::Vector{T},
    prof::OMAS.core_profiles__profiles_1d,

) where {T <: Real}

Returns an inteprolation function for the core profile property values defined on
normalized toroidal flux coordinate rho.

Example:
core_profile_n_e = dd.core_profiles.profiles_1d[1].electrons.density
get_n_e = interp(core_profile_n_e, dd.core_profiles.profiles_1d[1])
get_n_e(1) # Returns electron density at rho = 1 (separatix)
"""
function interp(
    prop::Vector{T},
    prof::OMAS.core_profiles__profiles_1d,
) where {T <: Real}
    rho_prof = copy(prof.grid.rho_tor_norm)
    length(prop) == length(rho_prof) ||
        error("Property muast have same length as rho_tor_norm in core_profile")
    prepend!(rho_prof, RHO_EXT_NEG)
    append!(rho_prof, RHO_EXT_POS)
    p = copy(prop)
    prepend!(p, zeros(size(RHO_EXT_NEG)))
    append!(p, zeros(size(RHO_EXT_POS)))
    return linear_interpolation(rho_prof, p)
end

"""
    interp(
    prop::Vector{T},
    prof::OMAS.core_profiles__profiles_1d,
    rz2rho::Function,

)

Returns an inteprolation function in (R, Z) domain for the core profile property values
defined on normalized toroidal flux coordinate rho and with a provided function to
convert (R,Z) to rho.

Example:

rz2rho = interp(dd.equilibrium.time_slice[1])
core_profile_n_e = dd.core_profiles.profiles_1d[1].electrons.density
get_n_e = interp(core_profile_n_e, dd.core_profiles.profiles_1d[1], rz2rho)
get_n_e(5.0, 3.5) # Returns electron density at (R, Z) = (5.0, 3.5)
"""
function interp(
    prop::Vector{T},
    prof::OMAS.core_profiles__profiles_1d,
    rz2rho::Function,
) where {T <: Real}
    itp = interp(prop, prof)
    get_interp_val(r::Real, z::Real) = itp.(rz2rho(r, z))
    get_interp_val(rz::Tuple{Real, Real}) = get_interp_val(rz...)
    return get_interp_val
end

"""
    interp(
    prop::Vector{T},
    prof::OMAS.core_profiles__profiles_1d,
    eqt::OMAS.equilibrium__time_slice,

) where {T <: Real}

Returns an inteprolation function in (R, Z) domain for the core profile property values
defined on normalized toroidal flux coordinate rho and with a provided equilibrium time
slice to get (R, Z) to rho conversion.

Example:

eqt = dd.equilibrium.time_slice[1]
core_profile_n_e = dd.core_profiles.profiles_1d[1].electrons.density
get_n_e = interp(core_profile_n_e, dd.core_profiles.profiles_1d[1], eqt)
get_n_e(5.0, 3.5) # Returns electron density at (R, Z) = (5.0, 3.5)
"""
function interp(
    prop::Vector{T},
    prof::OMAS.core_profiles__profiles_1d,
    eqt::OMAS.equilibrium__time_slice,
) where {T <: Real}
    rz2rho = interp(eqt)
    return interp(prop, prof, rz2rho)
end
