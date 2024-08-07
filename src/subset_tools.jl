export add_subset_element!
export get_subset_space
export get_grid_subset
export get_subset_boundary_inds
export get_subset_boundary
export subset_do
export get_subset_centers
export project_prop_on_subset!
export deepcopy_subset
export get_prop_with_grid_subset_index

"""
    add_subset_element!(
        subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
        sn::Int,
        dim::Int,
        index::Int,
        in_subset=(x...) -> true;
        kwargs...,
    )

Adds a new element to gird_subset with properties space number (sn), dimension (dim),
and index (index). The element is added only if the function in_subset returns true.
"""
function add_subset_element!(
    subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    sn::Int,
    dim::Int,
    index::Int,
    in_subset=(x...) -> true;
    kwargs...,
)
    if in_subset(; kwargs...)
        dd_ind = length(subset.element) + 1
        resize!(subset.element, dd_ind)
        resize!(subset.element[dd_ind].object, 1)
        subset.element[dd_ind].object[1].space = sn
        subset.element[dd_ind].object[1].dimension = dim
        subset.element[dd_ind].object[1].index = index
    end
end

"""
    add_subset_element!(
        subset,
        sn,
        dim,
        index::Vector{Int},
        in_subset=(x...) -> true;
        kwargs...,
    )

Overloaded to work differently (faster) with list of indices to be added.
"""
function add_subset_element!(
    subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    sn::Int,
    dim::Int,
    index::Vector{Int},
    in_subset=(x...) -> true;
    kwargs...,
)
    if in_subset(; kwargs...)
        dd_start_ind = length(subset.element) + 1
        resize!(subset.element, length(subset.element) + length(index))
        dd_stop_ind = length(subset.element)
        for (ii, dd_ind) ∈ enumerate(dd_start_ind:dd_stop_ind)
            resize!(subset.element[dd_ind].object, 1)
            subset.element[dd_ind].object[1].space = sn
            subset.element[dd_ind].object[1].dimension = dim
            subset.element[dd_ind].object[1].index = index[ii]
        end
    end
end

"""
    get_subset_space(
        space::IMASdd.edge_profiles__grid_ggd___space,
        elements::AbstractVector{<:IMASdd.edge_profiles__grid_ggd___grid_subset___element}
    )

Returns an array of space object indices corresponding to the correct
objects_per_dimension (nodes, edges or cells) for the subset elements.
"""
function get_subset_space(
    space::IMASdd.edge_profiles__grid_ggd___space,
    elements::AbstractVector{<:IMASdd.edge_profiles__grid_ggd___grid_subset___element},
)
    nD = elements[1].object[1].dimension
    nD_objects = space.objects_per_dimension[nD].object
    return [nD_objects[ele.object[1].index] for ele ∈ elements]
end

"""
    get_grid_subset(
        grid_ggd::IMASdd.edge_profiles__grid_ggd,
        grid_subset_index::Int,
    )

Returns the grid_subset in a grid_ggd with the matching grid_subset_index
"""
function get_grid_subset(
    grid_ggd::IMASdd.edge_profiles__grid_ggd,
    grid_subset_index::Int,
)
    for subset ∈ grid_ggd.grid_subset
        if subset.identifier.index == grid_subset_index
            return subset
        end
    end

    return error("Subset ", grid_subset_index, " not found.")
end

"""
    get_grid_subset(
        grid_ggd::IMASdd.edge_profiles__grid_ggd,
        grid_subset_name::String,
    )

Returns the grid_subset in a grid_ggd with the matching grid_subset_name
"""
function get_grid_subset(
    grid_ggd::IMASdd.edge_profiles__grid_ggd,
    grid_subset_name::String,
)
    for subset ∈ grid_ggd.grid_subset
        if subset.identifier.name == grid_subset_name
            return subset
        end
    end

    return error("Subset ", grid_subset_name, " not found.")
end

"""
    get_subset_boundary_inds(
        space::IMASdd.edge_profiles__grid_ggd___space,
        subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    )

Returns an array of space object indices corresponding to the boundary of the subset.
That means, it returns indices of nodes that are at the end of open edge subset or
it returns the indices of edges that are the the boundary of a cell subset.
Returns an empty array if the subset is 1D (nodes).
"""
function get_subset_boundary_inds(
    space::IMASdd.edge_profiles__grid_ggd___space,
    subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
)
    nD = subset.element[1].object[1].dimension
    if nD > 1  # Only 2D (edges) and 3D (cells) subsets have boundaries
        nD_objects = space.objects_per_dimension[nD].object
        elements = [nD_objects[ele.object[1].index] for ele ∈ subset.element]
        boundary_inds = Int[]
        for ele ∈ elements
            symdiff!(boundary_inds, [bnd.index for bnd ∈ ele.boundary])
        end
        return boundary_inds
    end
    return [] # 1D (nodes) subsets have no boundary
end

"""
    get_subset_boundary(
        space::IMASdd.edge_profiles__grid_ggd___space,
        subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    )

Returns an array of elements of grid_subset generated from the boundary of the subset
provided. The dimension of these elments is reduced by 1.
"""
function get_subset_boundary(
    space::IMASdd.edge_profiles__grid_ggd___space,
    subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
)
    ret_subset = IMASdd.edge_profiles__grid_ggd___grid_subset()
    boundary_inds = get_subset_boundary_inds(space, subset)
    bnd_dim = subset.element[1].object[1].dimension - 1
    space_number = subset.element[1].object[1].space
    add_subset_element!(ret_subset, space_number, bnd_dim, boundary_inds)
    return ret_subset.element
end

"""
    subset_do(
        set_operator,
        itrs::Vararg{
            AbstractVector{<:IMASdd.edge_profiles__grid_ggd___grid_subset___element},
        };
        space::IMASdd.edge_profiles__grid_ggd___space=IMASdd.edge_profiles__grid_ggd___space(),
        use_nodes=false
    )

Function to perform any set operation (intersect, union, setdiff etc.) on
subset.element to generate a list of elements to go to subset object. If use_nodes is
true, the set operation will be applied on the set of nodes from subset.element, space
argument is required for this.
Note: that the arguments are subset.element (not the subset itself). Similarly, the
return object is a list of IMASdd.edge_profiles__grid_ggd___grid_subset___element.
"""
function subset_do(
    set_operator,
    itrs::Vararg{
        AbstractVector{<:IMASdd.edge_profiles__grid_ggd___grid_subset___element},
    };
    space::IMASdd.edge_profiles__grid_ggd___space=IMASdd.edge_profiles__grid_ggd___space(),
    use_nodes=false,
)
    if use_nodes
        ele_inds = set_operator(
            [
                union([
                        obj.nodes for obj ∈ get_subset_space(space, set_elements)
                    ]...
                ) for set_elements ∈ itrs
            ]...,
        )
        dim = 1
    else
        ele_inds = set_operator(
            [[ele.object[1].index for ele ∈ set_elements] for set_elements ∈ itrs]...,
        )
        dim = itrs[1][1].object[1].dimension
    end
    ret_subset = IMASdd.edge_profiles__grid_ggd___grid_subset()
    space_number = itrs[1][1].object[1].space
    add_subset_element!(ret_subset, space_number, dim, ele_inds)
    return ret_subset.element
end

"""
    get_subset_centers(
        space::IMASdd.edge_profiles__grid_ggd___space,
        subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    )

Returns an array of tuples corresponding to (r,z) coordinates of the center of
cells or the center of edges in the subset space.
"""
function get_subset_centers(
    space::IMASdd.edge_profiles__grid_ggd___space,
    subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
)
    subset_space = get_subset_space(space, subset.element)
    if subset.element[1].object[1].dimension == 1
        return [Tuple(obj.geometry) for obj ∈ subset_space]
    end
    grid_nodes = space.objects_per_dimension[1].object
    return [
        Tuple(mean(SVector{2}(grid_nodes[node].geometry) for node ∈ obj.nodes)) for
        obj ∈ subset_space
    ]
end

"""
    project_prop_on_subset!(
        prop_arr::AbstractVector{T},
        from_subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
        to_subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
        space::IMASdd.edge_profiles__grid_ggd___space,
        value_field::Symbol=:values;
        TPS_mats::Union{
            Nothing,
            Tuple{Matrix{U}, Matrix{U}, Matrix{U}, Vector{Tuple{U, U}}},
        }=nothing,
    ) where {T <: edge_profiles__prop_on_subset, U <: Real}

This function can be used to add another instance on a property vector representing the
value in a new subset that can be taken as a projection from an existing larger subset.

Input Arguments:

  - prop: A property like electrons.density that is a vector of objects with fields
    coefficients, grid_index, grid_subset_index, and values. The different instances
    in the vector correspond to different grid_subset for which the property is
    provided.
  - from_subset: grid_subset object which is already represented in the property instance.
    grid subset with index 5 is populated in electrons.density already if the
    values for all cells are present.
  - to_subset: grid_subset which is either a smaller part of from_subset (core, sol, idr,
    odr) but has same dimensions as from_subset
    OR
    is smaller in dimension that goes through the from_subset (core_boundary,
    separatix etc.)
  - space: (optional) space object in grid_ggd is required only when from_subset is
    higher dimensional than to_subset.

Returns:
NOTE: This function ends in ! which means it updates prop argument in place. But for
the additional utility, this function also returns a tuple
(to_subset_centers, to_prop_values) when from_subset dimension is greater than
to_subset dimension
OR
(to_subset_ele_obj_inds, to_prop_values) when from_subset dimension is same as
to_subset dimension)

Descriptions:
to_subset_centers: center of cells or center of edges of the to_subset where property
values are defined and stored
to_subset_ele_obj_inds: Indices of the elements of to_subset where property values are
defined and stored
to_prop_values: The projected values of the properties added to prop object in a new
instance
"""
function project_prop_on_subset!(
    prop_arr::AbstractVector{T},
    from_subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    to_subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    space::IMASdd.edge_profiles__grid_ggd___space,
    value_field::Symbol=:values;
    TPS_mats::Union{
        Nothing,
        Tuple{Matrix{U}, Matrix{U}, Matrix{U}, Vector{Tuple{U, U}}},
    }=nothing,
) where {T <: edge_profiles__prop_on_subset, U <: Real}
    if from_subset.element[1].object[1].dimension ==
       to_subset.element[1].object[1].dimension
        return project_prop_on_subset!(prop, from_subset, to_subset)
    elseif from_subset.element[1].object[1].dimension >
           to_subset.element[1].object[1].dimension
        if length(prop_arr) < 1
            error(
                "The property $(strip(repr(prop_arr))) is empty; ",
                "there are no data available for any subset.",
            )
        end
        from_prop =
            get_prop_with_grid_subset_index(prop_arr, from_subset.identifier.index)
        if isnothing(from_prop)
            error(
                "from_subset ($(from_subset.identifier.index)) not represented in the ",
                "property yet",
            )
        end
        to_subset_centers = get_subset_centers(space, to_subset)
        resize!(prop_arr, length(prop_arr) + 1)
        to_prop = prop_arr[end]
        to_prop.grid_index = from_prop.grid_index
        to_prop.grid_subset_index = to_subset.identifier.index
        to_prop_values = getfield(to_prop, value_field)
        from_prop_values = getfield(from_prop, value_field)
        resize!(to_prop_values, length(to_subset.element))
        if isnothing(TPS_mats)
            prop_interp = interp(prop_arr, space, from_subset)
        else
            prop_interp = interp(from_prop_values, TPS_mats)
        end
        to_prop_values = prop_interp.(to_subset_centers)
        setproperty!(to_prop, value_field, to_prop_values)
        return to_subset_centers, to_prop_values
    else
        error(
            "to_subset ($(to_subset.identifier.index)) is higher dimensional than ",
            "from_subset ($(from_subset.identifier.index))",
        )
    end
end

"""
    project_prop_on_subset!(
        prop_arr::AbstractVector{T},
        from_subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
        to_subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
        value_field::Symbol=:values,
    ) where {T <: edge_profiles__prop_on_subset}

If the dimensions of from_subset and to_subset are the same, this function can be used
to add another instance on a property vector representing the value in to_subset without
any interpolation or use of space object. The function returns a tuple of indices of
elements of to_subset and the values of the property in to_subset.
"""
function project_prop_on_subset!(
    prop_arr::AbstractVector{T},
    from_subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    to_subset::IMASdd.edge_profiles__grid_ggd___grid_subset,
    value_field::Symbol=:values,
) where {T <: edge_profiles__prop_on_subset}
    from_prop = get_prop_with_grid_subset_index(prop_arr, from_subset.identifier.index)
    if length(prop_arr) < 1
        error(
            "The property $(strip(repr(prop_arr))) is empty; ",
            "there are no data available for any subset.",
        )
    end
    if isnothing(from_prop)
        error(
            "from_subset ($(from_subset.identifier.index)) not represented in the property yet",
        )
    end
    if from_subset.element[1].object[1].dimension ==
       to_subset.element[1].object[1].dimension
        resize!(prop_arr, length(prop_arr) + 1)
        to_prop = prop_arr[end]
        to_prop.grid_index = from_prop.grid_index
        to_prop.grid_subset_index = to_subset.identifier.index
        to_prop_values = getfield(to_prop, value_field)
        from_prop_values = getfield(from_prop, value_field)
        from_subset_ele_obj_inds = [ele.object[1].index for ele ∈ from_subset.element]
        to_subset_ele_obj_inds = [ele.object[1].index for ele ∈ to_subset.element]
        if to_subset_ele_obj_inds ⊆ from_subset_ele_obj_inds
            from_ele_inds = []
            for to_ele_obj_ind ∈ to_subset_ele_obj_inds
                for (from_ele_ind, from_ele_obj_ind) ∈
                    enumerate(from_subset_ele_obj_inds)
                    if from_ele_obj_ind == to_ele_obj_ind
                        append!(from_ele_inds, from_ele_ind)
                    end
                end
            end
            filtered_values =
                [from_prop_values[from_ele_ind] for from_ele_ind ∈ from_ele_inds]
            resize!(to_prop_values, length(filtered_values))
            to_prop_values = filtered_values
            return to_subset_ele_obj_inds, to_prop_values
        else
            error(
                "to_subset ($(to_subset.identifier.index)) does not lie entirely inside ",
                "from_subset ($(from_subset.identifier.index)). Projection not possible.",
            )
        end
    else
        error(
            "Dimensions of from_subset ($(from_subset.identifier.index)) and to_subset ",
            "($(to_subset.identifier.index)) do not match. Provide keyword ",
            "argument space if you want to project to a smaller dimension as space ",
            "information is required for that. Use\n",
            "project_prop_on_subset!(prop, from_subset, to_subset; space=space)")
    end
end

"""
    deepcopy_subset(subset::IMASdd.edge_profiles__grid_ggd___grid_subset)

Faster deepcopy function for grid_subset object. This function is used to create a deep
copy of a grid_subset object bypassing several checks performed by IMASdd.
"""
function deepcopy_subset(subset::IMASdd.edge_profiles__grid_ggd___grid_subset)
    new_subset = IMASdd.edge_profiles__grid_ggd___grid_subset()

    base = getfield(subset, :base)
    new_base = getfield(new_subset, :base)
    resize!(new_base, length(base))
    for (ii, b) ∈ enumerate(base)
        if !IMASdd.ismissing(b, :jacobian)
            new_base[ii].jacobian = deepcopy(getfield(b, :jacobian))
        end
        if !IMASdd.ismissing(b, :tensor_contravariant)
            new_base[ii].tensor_contravariant =
                deepcopy(getfield(b, :tensor_contravariant))
        end
        if !IMASdd.ismissing(b, :tensor_covariant)
            new_base[ii].tensor_covariant = deepcopy(getfield(b, :tensor_covariant))
        end
    end

    if !IMASdd.ismissing(subset, :dimension)
        new_subset.dimension = deepcopy(getfield(subset, :dimension))
    end

    element = getfield(subset, :element)
    new_element = getfield(new_subset, :element)
    resize!(new_element, length(element))
    for (ii, ele) ∈ enumerate(element)
        object = getfield(ele, :object)
        new_object = getfield(new_element[ii], :object)
        resize!(new_object, length(object))
        for (jj, obj) ∈ enumerate(object)
            if !IMASdd.ismissing(obj, :dimension)
                new_object[jj].dimension = deepcopy(getfield(obj, :dimension))
            end
            if !IMASdd.ismissing(obj, :index)
                new_object[jj].index = deepcopy(getfield(obj, :index))
            end
            if !IMASdd.ismissing(obj, :space)
                new_object[jj].space = deepcopy(getfield(obj, :space))
            end
        end
    end

    identifier = getfield(subset, :identifier)
    new_identifier = getfield(new_subset, :identifier)
    if !IMASdd.ismissing(identifier, :index)
        new_identifier.index = deepcopy(getfield(identifier, :index))
    end
    if !IMASdd.ismissing(identifier, :name)
        new_identifier.name = deepcopy(getfield(identifier, :name))
    end
    if !IMASdd.ismissing(identifier, :description)
        new_identifier.description = deepcopy(getfield(identifier, :description))
    end

    metric = getfield(subset, :metric)
    new_metric = getfield(new_subset, :metric)
    if !IMASdd.ismissing(metric, :jacobian)
        new_metric.jacobian = deepcopy(getfield(metric, :jacobian))
    end
    if !IMASdd.ismissing(metric, :tensor_contravariant)
        new_metric.tensor_contravariant =
            deepcopy(getfield(metric, :tensor_contravariant))
    end
    if !IMASdd.ismissing(metric, :tensor_covariant)
        new_metric.tensor_covariant = deepcopy(getfield(metric, :tensor_covariant))
    end
    return new_subset
end

"""
    Base.:∈(
        point::Tuple{Real, Real},
        subset_of_space::Tuple{
            IMASdd.edge_profiles__grid_ggd___grid_subset,
            IMASdd.edge_profiles__grid_ggd___space,
        },
    )

Overloading ∈ operator to check if a point is inside a subset of space.

If the subset is 1-dimensional, all points are searched. If the subset is 2-dimensional,
it is checked if the point is within the enclosed area. It is assumed that a
2-dimensional subset used in such a context will form a closed area. If the subset is
3-dimensional, its boundary is calculated on the fly. If used multiple times, it is
recommended to calculate the boundary once and store it in a variable.

Example:

```julia
if (5.5, 0.0) ∈ (subset_sol, space)
    println("Point (5.5, 0.0) is inside the SOL subset.")
else
    println("Point (5.5, 0.0) is outside the SOL subset.")
end
```
"""
function Base.:∈(
    point::Tuple{Real, Real},
    subset_of_space::Tuple{
        IMASdd.edge_profiles__grid_ggd___grid_subset,
        IMASdd.edge_profiles__grid_ggd___space,
    },
)
    r, z = point
    subset, space = subset_of_space
    dim = getfield(getfield(getfield(subset, :element)[1], :object)[1], :dimension)
    opd = getfield(space, :objects_per_dimension)
    nodes = getfield(opd[1], :object)
    edges = getfield(opd[2], :object)
    if dim == 3
        subset_bnd = IMASdd.edge_profiles__grid_ggd___grid_subset()
        subset_bnd.element = get_subset_boundary(space, subset)
    elseif dim == 2
        subset_bnd = subset
    elseif dim == 1
        for ele ∈ getfield(subset, :element)
            node = nodes[getfield(getfield(ele, :object)[1], :index)]
            if node.geometry[1] == r && node.geometry[2] == z
                return true
            end
        end
        return false
    else
        error("Dimension ", dim, " is not supported yet.")
    end
    # Count number of times an upward going ray from (r,z) intersects the boundary
    count = 0
    for ele ∈ getfield(subset_bnd, :element)
        edge = edges[getfield(getfield(ele, :object)[1], :index)]
        edge_nodes_r = zeros(2)
        edge_nodes_z = zeros(2)
        for (ii, node) ∈ enumerate(getfield(edge, :nodes))
            edge_nodes_r[ii] = getfield(nodes[node], :geometry)[1]
            edge_nodes_z[ii] = getfield(nodes[node], :geometry)[2]
        end
        r_max = maximum(edge_nodes_r)
        r_min = minimum(edge_nodes_r)
        if r_min <= r < r_max
            z_max = maximum(edge_nodes_z)
            if z < z_max
                count += 1
            end
        end
    end
    # If it is even, the point is outside the boundary
    return count % 2 == 1
end

"""
    get_prop_with_grid_subset_index(
        prop::AbstractVector{T},
        grid_subset_index::Int,
    ) where {T <: edge_profiles__prop_on_subset}

Find the edge_profiles property instance in an array of properties that corresponds to
the grid_subset_index provided.
"""
function get_prop_with_grid_subset_index(
    prop::AbstractVector{T},
    grid_subset_index::Int,
) where {T <: edge_profiles__prop_on_subset}
    for p ∈ prop
        if p.grid_subset_index == grid_subset_index
            return p
        end
    end
    return nothing
end
