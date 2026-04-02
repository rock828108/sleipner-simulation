# 3D coupled THM CO2 - 32x32x16 distributed conservative screening version.
# Base: co2_thm_example_3d_v10_lu_turbo_fast_distributed_pointinj_32x32x16.i
# Changes: keep the 32x32x16 distributed THM + point-injection structure, but use the
#          conservative injection/time-step controls and BJACOBI-LU path that stabilized
#          the smaller distributed tests through the two-phase transition.
[Mesh]
  # Default to replicated for local/single-rank runs; submit-time override is supported via
  #   MESH_TYPE=distributed
  # in submit_co2_thm_example_3d_v10_lu_turbo_fast.sh, which passes Mesh/parallel_type=...
  parallel_type = replicated
  [gen]
    type = GeneratedMeshGenerator
    dim = 3
    # 8x fewer elements than the production 32x32x16 mesh: cheap enough for direction screening,
    # but still preserves the 3D THM coupling structure and the same physics blocks/BCs.
    nx = 32
    ny = 32
    nz = 16
    xmin = 900
    xmax = 1100
    ymin = 900
    ymax = 1100
    zmin = -840
    zmax = -800
  []
[]

[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
  PorousFlowDictator = dictator
  gravity = '0 0 -9.81'
  biot_coefficient = 1.0
[]

[Variables]
  [pgas]
    []
  [zi]
    initial_condition = 1e-12
    scaling = 1e2 # 或者尝试 1e3
  []
  [temp]
    scaling = 1e-3
  []
  [disp_x]
    scaling = 1e-6
  []
  [disp_y]
    scaling = 1e-6
  []
  [disp_z]
    scaling = 1e-6
  []
[]

[ICs]
  active = 'pgas_hydrostatic temp_geothermal'
  [pgas_hydrostatic]
    type = FunctionIC
    variable = pgas
    function = hydrostatic_pressure
  []
  [temp_geothermal]
    type = FunctionIC
    variable = temp
    function = geothermal_temp
  []
[]

[Debug]
  show_var_residual_norms = false
[]

[AuxVariables]
  [xnacl]
    initial_condition = 0.0
    outputs = 'none'
  []

  [saturation_gas]
    family = MONOMIAL
    order = FIRST
  []
  # Keep this nodal aux around in case we want to re-enable variable bounds later.
  [bounds_dummy]
    order = FIRST
    family = LAGRANGE
    outputs = 'none'
  []
  [stress_zz]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_xx]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_yy]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_xy]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_yz]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_xz]
    order = CONSTANT
    family = MONOMIAL
  []
  [vonmises]
    order = CONSTANT
    family = MONOMIAL
  []
[]


[Kernels]
  [mass_water_dot]
    type = PorousFlowMassTimeDerivative
    fluid_component = 0
    variable = pgas
  []
  [flux_water]
    type = PorousFlowAdvectiveFlux
    fluid_component = 0
    use_displaced_mesh = false
    variable = pgas
  []
  [mass_co2_dot]
    type = PorousFlowMassTimeDerivative
    fluid_component = 1
    variable = zi
  []
  [flux_co2]
    type = PorousFlowAdvectiveFlux
    fluid_component = 1
    use_displaced_mesh = false
    variable = zi
  []
  [energy_dot]
    type = PorousFlowEnergyTimeDerivative
    variable = temp
  []
  [heat_advection]
    type = PorousFlowHeatAdvection
    use_displaced_mesh = false
    variable = temp
  []
  [heat_conduction]
    type = PorousFlowHeatConduction
    use_displaced_mesh = false
    variable = temp
  []
  [grad_stress_x]
    type = StressDivergenceTensors
    temperature = temp
    eigenstrain_names = thermal_contribution
    variable = disp_x
    use_displaced_mesh = false
    component = 0
  []
  [grad_stress_y]
    type = StressDivergenceTensors
    temperature = temp
    eigenstrain_names = thermal_contribution
    variable = disp_y
    use_displaced_mesh = false
    component = 1
  []
  [grad_stress_z]
    type = StressDivergenceTensors
    temperature = temp
    eigenstrain_names = thermal_contribution
    variable = disp_z
    use_displaced_mesh = false
    component = 2
  []
  [poro_x]
    type = PorousFlowEffectiveStressCoupling
    variable = disp_x
    use_displaced_mesh = false
    component = 0
  []
  [poro_y]
    type = PorousFlowEffectiveStressCoupling
    variable = disp_y
    use_displaced_mesh = false
    component = 1
  []
  [poro_z]
    type = PorousFlowEffectiveStressCoupling
    variable = disp_z
    use_displaced_mesh = false
    component = 2
  []
  [gravity_z]
    type = Gravity
    variable = disp_z
    value = -9.81
  []
[]

[AuxKernels]
  [saturation_gas]
    type = PorousFlowPropertyAux
    property = saturation
    phase = 1
    variable = saturation_gas
    use_displaced_mesh = false
    execute_on = 'initial timestep_end'
  []
  [stress_zz_calc]
    type = RankTwoAux
    variable = stress_zz
    rank_two_tensor = stress # 对应 Materials 里的 stress
    index_i = 2 # 0=x, 1=y, 2=z
    index_j = 2
    execute_on = 'initial timestep_end'
  []
  [stress_xx_calc]
    type = RankTwoAux
    variable = stress_xx
    rank_two_tensor = stress
    index_i = 0
    index_j = 0
    execute_on = 'initial timestep_end'
  []
  [stress_yy_calc]
    type = RankTwoAux
    variable = stress_yy
    rank_two_tensor = stress
    index_i = 1
    index_j = 1
    execute_on = 'initial timestep_end'
  []
  [stress_xy_calc]
    type = RankTwoAux
    variable = stress_xy
    rank_two_tensor = stress
    index_i = 0
    index_j = 1
    execute_on = 'initial timestep_end'
  []
  [stress_yz_calc]
    type = RankTwoAux
    variable = stress_yz
    rank_two_tensor = stress
    index_i = 1
    index_j = 2
    execute_on = 'initial timestep_end'
  []
  [stress_xz_calc]
    type = RankTwoAux
    variable = stress_xz
    rank_two_tensor = stress
    index_i = 0
    index_j = 2
    execute_on = 'initial timestep_end'
  []
  [vonmises_calc]
    type = RankTwoScalarAux
    variable = vonmises
    rank_two_tensor = stress
    scalar_type = VonMisesStress
    execute_on = 'initial timestep_end'
  []
[]

[Dampers]
  [zi_max_increment]
    type = MaxIncrement
    variable = zi
    max_increment = 0.05
  []
  [pgas_min]
    type = BoundingValueNodalDamper
    variable = pgas
    min_value = 1e5
  []
  [pgas_max_inc]
    type = MaxIncrement
    variable = pgas
    max_increment = 5e5
  []
  [temp_max_inc]
    type = MaxIncrement
    variable = temp
    max_increment = 15.0
  []
  [temp_bounds]
    type = BoundingValueNodalDamper
    variable = temp
    min_value = 273.15
    max_value = 423.15
    # Do not let damping vanish when pushing against bounds (helps after failed linear solves)
    min_damping = 0.05
  []
[]

[Functions]
  [injection_rate]
    type = ParsedFunction
    # Smooth C1 ramp to reduce the hard nonlinear window near the end of startup.
    expression = 'if(t < 10, 0, if(t < 259200, 5*(((t-10)/259190)^2)*(3-2*((t-10)/259190)), 5))'
  []
  [Tin323]
    type = ParsedFunction
    expression = '323'
  []
  [geothermal_temp]
    type = ParsedFunction
    expression = '323 + 0.03*(-z - 800)'
  []
  [hydrostatic_pressure]
    type = ParsedFunction
    expression = '1e5 - 992*9.81*z'
  []
  [ini_stress_fn]
    type = ParsedFunction
    expression = '-0.7*2350*9.81*(-z)'
  []
  [ini_stress_v_fn]
    type = ParsedFunction
    expression = '-2350*9.81*(-z)'
  []
  [sigma_v_top]
    type = ParsedFunction
    expression = '2350*9.81*800'
  []
  [sigma_h_side]
    type = ParsedFunction
    expression = '0.7*2350*9.81*(-z)'
  []
[]

[UserObjects]
  [dictator]
    type = PorousFlowDictator
    porous_flow_vars = 'temp pgas zi disp_x disp_y disp_z'
    number_fluid_phases = 2
    number_fluid_components = 3
  []
  [pc]
    type = PorousFlowCapillaryPressureConst
    pc = 2e4
  []
  [fs]
    type = PorousFlowBrineCO2
    brine_fp = brine
    co2_fp = co2
    capillary_pressure = pc
  []
[]

[FluidProperties]
  [water_raw]
    type = Water97FluidProperties
  []
  [water]
    type = TabulatedBicubicFluidProperties
    fp = water_raw
    temperature_min = 275
    pressure_max = 1E8
    fluid_property_output_file = water97_tabulated_screen.csv
  []
  [brine]
    type = BrineFluidProperties
    water_fp = water
  []
  [co2_raw]
    type = CO2FluidProperties
  []
  [co2]
    type = TabulatedBicubicFluidProperties
    fp = co2_raw
    temperature_min = 275
    pressure_max = 1E8
    fluid_property_output_file = co2_tabulated_screen.csv
  []
[]

[Materials]
  [temperature]
    type = PorousFlowTemperature
    temperature = temp
  []
  [brineco2_state]
    type = PorousFlowFluidState
    gas_porepressure = pgas
    z = zi
    xnacl = xnacl
    temperature = temp
    temperature_unit = Kelvin
    capillary_pressure = pc
    fluid_state = fs
  []
  [porosity_reservoir]
    type = PorousFlowPorosityConst
    porosity = 0.2
  []
  [permeability_reservoir]
    type = PorousFlowPermeabilityConst
    permeability = '2e-13 0 0  0 2e-13 0  0 0 2e-13'
  []
  [relperm_liquid]
    type = PorousFlowRelativePermeabilityCorey
    # Slightly soften the liquid relperm curve to reduce the hardest two-phase transitions.
    n = 3
    phase = 0
    s_res = 0.200
    sum_s_res = 0.405
  []
  [relperm_gas]
    type = PorousFlowRelativePermeabilityBC
    phase = 1
    s_res = 0.205
    sum_s_res = 0.405
    nw_phase = true
    lambda = 2
  []
  [thermal_conductivity_reservoir]
    type = PorousFlowThermalConductivityIdeal
    dry_thermal_conductivity = '1.320 0 0  0 1.320 0  0 0 1.320'
    wet_thermal_conductivity = '3.083 0 0  0 3.083 0  0 0 3.083'
  []
  [internal_energy_reservoir]
    type = PorousFlowMatrixInternalEnergy
    specific_heat_capacity = 1100
    density = 2350.0
  []
  [density]
    type = GenericConstantMaterial
    prop_names = density
    prop_values = 2350.0
  []
  [elasticity_tensor]
    type = ComputeIsotropicElasticityTensor
    shear_modulus = 6.0E9
    poissons_ratio = 0.25
  []
  [strain]
    type = ComputeSmallStrain
    eigenstrain_names = 'thermal_contribution ini_stress'
  []
  [ini_strain]
    type = ComputeEigenstrainFromInitialStress
    initial_stress = 'ini_stress_fn 0 0  0 ini_stress_fn 0  0 0 ini_stress_v_fn'
    eigenstrain_name = ini_stress
  []
  [thermal_contribution]
    type = ComputeThermalExpansionEigenstrain
    temperature = temp
    stress_free_temperature = 323
    thermal_expansion_coeff = 1e-5
    eigenstrain_name = thermal_contribution
  []
  [stress]
    type = ComputeLinearElasticStress
  []
  [eff_fluid_pressure]
    type = PorousFlowEffectiveFluidPressure
  []
  [vol_strain]
    type = PorousFlowVolumetricStrain
  []
[]

[BCs]
  [lateral_p_farfield]
    type = FunctionDirichletBC
    variable = pgas
    boundary = 'left right front back'
    function = hydrostatic_pressure
  []
  [left_temp]
    type = FunctionDirichletBC
    boundary = left
    function = geothermal_temp
    variable = temp
  []
  [right_temp]
    type = FunctionDirichletBC
    boundary = right
    function = geothermal_temp
    variable = temp
  []
  [front_temp]
    type = FunctionDirichletBC
    boundary = front
    function = geothermal_temp
    variable = temp
  []
  [back_temp]
    type = FunctionDirichletBC
    boundary = back
    function = geothermal_temp
    variable = temp
  []
  [fixed_left_x]
    type = DirichletBC
    variable = disp_x
    value = 0
    boundary = left
  []
  [fixed_bottom_z]
    type = DirichletBC
    variable = disp_z
    value = 0
    boundary = bottom
  []
  [fixed_front_y]
    type = DirichletBC
    variable = disp_y
    value = 0
    boundary = front
  []
  [Pressure]
    [top_overburden]
      boundary = top
      function = sigma_v_top
      displacements = 'disp_x disp_y disp_z'
    []
    [right_confining]
      boundary = right
      function = sigma_h_side
      displacements = 'disp_x disp_y disp_z'
    []
    [back_confining]
      boundary = back
      function = sigma_h_side
      displacements = 'disp_x disp_y disp_z'
    []
  []
[]

[DiracKernels]
  [co2_point_injection]
    type = PorousFlowSquarePulsePointSource
    # Distributed-mesh-friendly trial: inject CO2 directly into the component variable
    # instead of constructing a parsed boundary patch.
    variable = zi
    point = '1000.1 1000.1 -838.75'
    mass_flux = 1
  []
[]

[Postprocessors]
  [p_injection]
    type = PointValue
    variable = pgas
    point = '1000.1 1000.1 -839.99'
    execute_on = timestep_end
    use_displaced_mesh = false
  []
  [temp_at_well]
    type = PointValue
    variable = temp
    point = '1000.1 1000.1 -839.99'
    execute_on = timestep_end
    use_displaced_mesh = false
  []
  [max_sgas]
    type = ElementExtremeValue
    variable = saturation_gas
    value_type = max
    execute_on = timestep_end
  []
  [sgas_top]
    type = PointValue
    variable = saturation_gas
    point = '1000.1 1000.1 -801'
    execute_on = timestep_end
  []
  [sgas_bottom]
    type = PointValue
    variable = saturation_gas
    point = '1000.1 1000.1 -839.99'
    execute_on = timestep_end
  []
  [z_top]
    type = PointValue
    variable = zi
    point = '1000.1 1000.1 -801'
    execute_on = timestep_end
  []
  [z_bottom]
    type = PointValue
    variable = zi
    point = '1000.1 1000.1 -839.99'
    execute_on = timestep_end
  []
  [dt]
    type = TimestepSize
    execute_on = 'initial timestep_end'
  []
  [injected_mass_this_step]
    type = ParsedPostprocessor
    expression = 'injection_mass_flux * dt'
    pp_names = 'injection_mass_flux dt'
    execute_on = timestep_end
    outputs = none
  []
  [injection_mass_flux]
    type = FunctionValuePostprocessor
    function = injection_rate
    execute_on = 'initial timestep_begin'
    outputs = none
  []
  [total_injected_mass]
    type = CumulativeValuePostprocessor
    postprocessor = injected_mass_this_step
    execute_on = timestep_end
  []
  [co2_mass]
    type = PorousFlowFluidMass
    fluid_component = 1
    execute_on = 'initial timestep_end'
  []
  [h2o_mass]
    type = PorousFlowFluidMass
    fluid_component = 0
    execute_on = 'initial timestep_end'
  []
  [total_fluid_mass]
    type = ParsedPostprocessor
    expression = 'h2o_mass + co2_mass'
    pp_names = 'h2o_mass co2_mass'
    execute_on = 'initial timestep_end'
  []
  [co2_mass_fraction]
    type = ParsedPostprocessor
    expression = 'co2_mass / max(1e-20, total_fluid_mass)'
    pp_names = 'co2_mass total_fluid_mass'
    execute_on = 'initial timestep_end'
  []
  [co2_out_mass_est]
    type = ParsedPostprocessor
    expression = 'max(0, total_injected_mass - co2_mass)'
    pp_names = 'total_injected_mass co2_mass'
    execute_on = timestep_end
  []
  [co2_out_frac_est]
    type = ParsedPostprocessor
    expression = 'co2_out_mass_est / max(1e-12, total_injected_mass)'
    pp_names = 'co2_out_mass_est total_injected_mass'
    execute_on = timestep_end
  []
[]

[VectorPostprocessors]
  [vertical_profile]
    type = LineValueSampler
    use_displaced_mesh = false
    start_point = '1000.1 1000.1 -838.75'
    end_point = '1000.1 1000.1 -801.25'
    sort_by = z
    num_points = 20
    outputs = csv
    variable = 'pgas temp zi saturation_gas stress_xx stress_yy stress_zz stress_xy stress_yz stress_xz vonmises'
    execute_on = 'initial timestep_end'
  []
  [horizontal_profile_bottom]
    type = LineValueSampler
    use_displaced_mesh = false
    start_point = '903.125 1000.1 -838.75'
    end_point = '1096.875 1000.1 -838.75'
    sort_by = x
    num_points = 20
    outputs = csv
    variable = 'pgas temp zi saturation_gas stress_xx stress_yy stress_zz stress_xy stress_yz stress_xz vonmises'
    execute_on = 'initial timestep_end'
  []
  [horizontal_profile_top]
    type = LineValueSampler
    use_displaced_mesh = false
    start_point = '903.125 1000.1 -801.25'
    end_point = '1096.875 1000.1 -801.25'
    sort_by = x
    num_points = 20
    outputs = csv
    variable = 'pgas temp zi saturation_gas stress_xx stress_yy stress_zz stress_xy stress_yz stress_xz vonmises'
    execute_on = 'initial timestep_end'
  []
[]

[Preconditioning]
  active = 'bjacobi_lu'
  [mumps_safe]
    type = SMP
    full = true
    # LU + NONZERO shift (helps near-singular J); mat_mumps_icntl_14=work memory
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_mat_solver_type -pc_factor_shift_type -ksp_rtol -ksp_max_it -snes_lag_jacobian -mat_mumps_icntl_14'
    petsc_options_value = 'preonly lu mumps NONZERO 1e-4 1500 1 400'
  []
  [ilu_fast]
    type = SMP
    full = false
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_levels -pc_factor_mat_ordering_type -pc_factor_shift_type -pc_factor_shift_amount -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian'
    petsc_options_value = 'gmres ilu 5 rcm NONZERO 1e-10 5e-4 3000 150 4'
  []
  [ilu_asm]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -pc_asm_overlap -sub_ksp_type -sub_pc_type -sub_pc_factor_shift_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -ksp_diagonal_scale -ksp_diagonal_scale_fix -ksp_gmres_modifiedgramschmidt'
    petsc_options_value = 'gmres asm 2 preonly lu NONZERO 2e-2 3000 200 10 true true true'
  []
  # Fast AMG path (can break down in hard windows; switch to mumps_safe when needed)
  [hypre_fast]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -pc_hypre_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -pc_hypre_boomeramg_strong_threshold'
    petsc_options_value = 'fgmres hypre boomeramg 1e-2 2000 150 4 0.25'
  []
  # Same as hypre_fgmres but looser -ksp_rtol (inexact Newton) when PC still hits DIVERGED_ITS at 1e-2
  [hypre_fgmres_loose]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -pc_hypre_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -pc_hypre_boomeramg_strong_threshold -pc_hypre_boomeramg_coarsen_type -pc_hypre_boomeramg_relax_type_all'
    petsc_options_value = 'fgmres hypre boomeramg 5e-2 1000 150 4 0.25 hmis jacobi'
  []
  # PETSc GAMG (different graph/coarsening than HYPRE — worth a try if hypre stalls)
  [gamg]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -pc_gamg_threshold'
    petsc_options_value = 'gmres gamg 5e-3 3000 150 4 0.05'
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  petsc_options_iname = '-snes_ksp_ew -snes_ksp_ew_version -snes_lag_jacobian_persists -snes_max_linear_solve_fail'
  petsc_options_value = 'true 2 true 10'
  line_search = 'bt'
  automatic_scaling = true
  compute_scaling_once = true
  nl_abs_tol = 1E-5
  nl_rel_tol = 1E-8
  nl_max_its = 50
  l_max_its = 100
  end_time = 3.1536e7
  dtmin = 1e-4
  dtmax = 21600
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 1
    growth_factor = 1.1
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.3
    optimal_iterations = 30
    iteration_window = 5
    # With ILU/ASM, earlier cutback is usually better than letting weak linear solves grind.
    linear_iteration_ratio = 100
  []
[]

[Outputs]
  file_base = exodus_output/co2_thm_example_3d_out
  print_linear_residuals = false
  perf_graph = true
  # Distributed-mesh trial: keep lightweight text outputs and avoid mesh-style outputs
  # that can warn about serialized meshes.
  exodus = false
  [console]
    type = Console
    show = 'p_injection temp_at_well total_injected_mass co2_mass h2o_mass total_fluid_mass co2_mass_fraction max_sgas sgas_top sgas_bottom z_top z_bottom'
  []
  [csv]
    type = CSV
    file_base = csv_outputs/co2_thm_example_3d_out_v10_turbo_fast
    sync_only = false
    execute_on = 'initial timestep_end final'
  []
[]
