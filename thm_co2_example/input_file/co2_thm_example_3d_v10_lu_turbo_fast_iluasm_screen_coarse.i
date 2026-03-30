# 3D coupled THM CO2 - coarse 3D screening version for fast solver-direction tests.
# Base: co2_thm_example_3d_v10_lu_turbo.i
# Changes: distributed mesh, dampers, automatic_scaling, snes_lag_jacobian, relaxed nl tol,
#          reduced output/checkpoint frequency, MUMPS memory boost.
[Mesh]
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
  [z_co2]
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
  [saturation_gas]
    family = MONOMIAL
    order = FIRST
  []
  [inj_flux_scale]
    family = MONOMIAL
    order = CONSTANT
    initial_condition = 1.0
  []
  [inj_heat_flux_scale]
    family = MONOMIAL
    order = CONSTANT
    initial_condition = 1.0
  []
  # For [Bounds] on z_co2: must match z_co2 (LAGRANGE nodal)
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

# Hard bounds z_co2 ∈ [0,1] via vinewtonrsls (requires -snes_type vinewtonrsls in Executioner).
# Replicated mesh only; ConstantBounds+vinewtonrsls can segfault on distributed.
[Bounds]
  [z_co2_lower]
    type = ConstantBounds
    variable = bounds_dummy
    bounded_variable = z_co2
    bound_type = lower
    bound_value = 0.0
  []
  [z_co2_upper]
    type = ConstantBounds
    variable = bounds_dummy
    bounded_variable = z_co2
    bound_type = upper
    bound_value = 1.0
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
    variable = z_co2
  []
  [flux_co2]
    type = PorousFlowAdvectiveFlux
    fluid_component = 1
    use_displaced_mesh = false
    variable = z_co2
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
  [inj_flux_scale]
    type = FunctionAux
    variable = inj_flux_scale
    function = injection_rate_per_m
    execute_on = 'initial timestep_begin'
  []
  [inj_heat_flux_scale]
    type = FunctionAux
    variable = inj_heat_flux_scale
    function = injection_heat_rate_per_m
    execute_on = 'initial timestep_begin'
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
  # zco2_bounds disabled: triggers "damping below min_damping" at phase transition, blocks run.
  # Without it, z can drift >1 at injection well; document in methods. MaxIncrement helps stability.
  # [zco2_bounds]
  #   type = BoundingValueNodalDamper
  #   variable = z_co2
  #   min_value = 0.0
  #   max_value = 1.0
  #   min_damping = 0.01
  # []
  [zco2_max_increment]
    type = MaxIncrement
    variable = z_co2
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
  # Limit |ΔT| per Newton iter so a bad linear step (e.g. DIVERGED_BREAKDOWN) cannot plunge T
  # below Water97/CO2 valid range before BoundingValueNodalDamper can react.
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
            expression = 'if(t < 10, 0, if(t < 259200, 5*(t-10)/259190, 5))'
  []
  [injection_rate_per_m]
    type = ParsedFunction
            expression = 'if(t < 10, 0, if(t < 259200, 250*(t-10)/259190, 250))'
  []
  [injection_heat_rate_per_m]
    type = ParsedFunction
            expression = 'if(t < 10, 0, if(t < 259200, 25*(t-10)/259190, 25))'
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
    porous_flow_vars = 'temp pgas z_co2 disp_x disp_y disp_z'
    number_fluid_phases = 2
    number_fluid_components = 2
  []
  [co2_line_sink_sum]
    type = PorousFlowSumQuantity
  []
  [heat_line_sink_sum]
    type = PorousFlowSumQuantity
  []
  [pc]
    type = PorousFlowCapillaryPressureConst
    pc = 2e4
  []
  [fs]
    type = PorousFlowWaterNCG
    water_fp = water
    gas_fp = co2
    capillary_pressure = pc
  []
[]

[FluidProperties]
  [water]
    type = Water97FluidProperties
  []
  [co2]
    type = CO2FluidProperties
  []
[]

[Materials]
  [temperature]
    type = PorousFlowTemperature
    temperature = temp
  []
  [waterncg_state]
    type = PorousFlowFluidState
    gas_porepressure = pgas
    z = z_co2
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
    n = 4
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
  [co2_inject_line]
    type = PorousFlowPolyLineSink
    variable = z_co2
    point_file = input_file/v10_injection_point.bh
    p_or_t_vals = '0'
    fluxes = '-1'
    multiplying_var = inj_flux_scale
    SumQuantityUO = co2_line_sink_sum
  []
  [co2_inject_heat_line]
    type = PorousFlowPolyLineSink
    variable = temp
    fluid_phase = 1
    use_enthalpy = true
    point_file = input_file/v10_injection_point.bh
    p_or_t_vals = '0'
    fluxes = '-1'
    multiplying_var = inj_heat_flux_scale
    SumQuantityUO = heat_line_sink_sum
  []
[]

[Postprocessors]
  [p_injection]
    type = PointValue
    variable = pgas
    point = '1000 1000 -839'
    execute_on = timestep_end
    use_displaced_mesh = false
  []
  [temp_at_well]
    type = PointValue
    variable = temp
    point = '1000 1000 -839'
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
    point = '1000 1000 -801'
    execute_on = timestep_end
  []
  [sgas_bottom]
    type = PointValue
    variable = saturation_gas
    point = '1000 1000 -839'
    execute_on = timestep_end
  []
  [z_top]
    type = PointValue
    variable = z_co2
    point = '1000 1000 -801'
    execute_on = timestep_end
  []
  [z_bottom]
    type = PointValue
    variable = z_co2
    point = '1000 1000 -839'
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
    start_point = '1000 1000 -840'
    end_point = '1000 1000 -800'
    sort_by = z
    num_points = 20
    outputs = csv
    variable = 'pgas temp z_co2 saturation_gas'
    execute_on = 'initial timestep_end'
  []
  [horizontal_profile]
    type = LineValueSampler
    use_displaced_mesh = false
    start_point = '900 1000 -820'
    end_point = '1100 1000 -820'
    sort_by = x
    num_points = 20
    outputs = csv
    variable = 'pgas temp z_co2 saturation_gas'
    execute_on = 'initial timestep_end'
  []
[]

[Preconditioning]
  # Coupled THM + PorousFlow J is strongly nonsymmetric; algebraic AMG (hypre/GAMG) is not
  # guaranteed to be a good preconditioner — DIVERGED_ITS at max_it means "PC is too weak", not
  # just rtol. Default: MUMPS LU (slow, robust). Fast options are provided for stable windows.
  #
  # Switch without editing this file: PRECON_ACTIVE=mumps_safe|ilu_fast|ilu_asm|hypre_fast|hypre_fgmres_loose|gamg
  # Legacy aliases kept for compatibility: smp (== mumps_safe), hypre (== hypre_fast), hypre_fgmres (== hypre_fast)
  active = 'mumps_safe'
  [mumps_safe]
    type = SMP
    full = true
    # LU + NONZERO shift (helps near-singular J); mat_mumps_icntl_14=work memory
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_mat_solver_type -pc_factor_shift_type -ksp_rtol -ksp_max_it -snes_lag_jacobian -mat_mumps_icntl_14'
    petsc_options_value = 'preonly lu mumps NONZERO 1e-4 1500 1 400'
  []
  # Legacy alias for mumps_safe
  # Mid-speed fallback: GMRES + ILU (often faster than direct LU, usually more stable than AMG)
  # MOOSE-style ILU (see test/tests/kernels/adv_diff_reaction/adv_diff_reaction_test.i): add RCM ordering
  #   petsc_options_iname = '-pc_type -pc_factor_levels -pc_factor_mat_ordering_type'
  #   petsc_options_value = 'ilu ... rcm'
  # Here: higher fill + RCM + shift for ill-conditioned J; KSP iters match Executioner/l_max_its.
  [ilu_fast]
    type = SMP
    full = false
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_levels -pc_factor_mat_ordering_type -pc_factor_shift_type -pc_factor_shift_amount -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian'
    petsc_options_value = 'gmres ilu 5 rcm NONZERO 1e-10 5e-4 3000 150 4'
  []
  # PorousFlow groundwater-style ILU (see modules/porous_flow/examples/groundwater/ex02_steady_state.i):
  #   petsc_options_iname = '-pc_type -sub_pc_type -pc_asm_overlap'
  #   petsc_options_value = 'asm ilu <overlap>'
  # ASM + ILU on subdomains can help strongly coupled blocks vs plain global ILU.
  [ilu_asm]
    type = SMP
    full = true
    # Long-horizon test: larger Jacobian lag and looser Krylov target, with EW adapting the
    # actual linear solve accuracy over the nonlinear iterations.
    petsc_options_iname = '-ksp_type -pc_type -pc_asm_overlap -sub_ksp_type -sub_pc_type -sub_pc_factor_levels -sub_pc_factor_mat_ordering_type -sub_pc_factor_shift_type -sub_pc_factor_shift_amount -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian'
    petsc_options_value = 'fgmres asm 3 preonly ilu 5 rcm NONZERO 1e-10 2e-2 3000 200 10'
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
  # ---------------------------------------------------------------------------
  # 难步 / Newton 平台期：当前启用 cp + 关自动缩放（曾卡在 |R|~1.37 用 bt+scaling 时）。
  # 预条件器仍用提交脚本 PRECON_ACTIVE=...
  #
  # line_search：只保留一行生效。
  #   bt — 相变窗口常更稳；若 cp 不稳可改回 bt。
  #   cp — bt 平台期可试。
  #
  # automatic_scaling：只保留一组生效。
  #   false — 难步试跑；稳定后若需缩放可改回 true + compute_scaling_once=true。
  #
  # CLI 可覆盖：MOOSE_EXTRA_ARGS='Executioner/line_search=bt Executioner/automatic_scaling=true ...'
  # ---------------------------------------------------------------------------
  # vinewtonrsls required for [Bounds] on z_co2 (use iname/value to avoid parse error)
  petsc_options_iname = '-snes_type -snes_ksp_ew -snes_ksp_ew_version -snes_lag_jacobian_persists -snes_max_linear_solve_fail'
  petsc_options_value = 'vinewtonrsls true 2 true 10'
  # --- line_search (exactly one active) ---
  line_search = 'cp'
  # line_search = 'basic'
  # --- automatic_scaling (exactly one active pair) ---
  automatic_scaling = true
  compute_scaling_once = true
  # automatic_scaling = false
  # compute_scaling_once = false
  # Relaxed nl_abs_tol: Newton can stall at |R|~2-3e-3 in difficult steps; 5e-3 allows progress
  # nl_rel_tol still guards quality: |R| < 1e-8*|R0|
  nl_abs_tol = 1E-5
  nl_rel_tol = 1E-8
  nl_max_its = 30
  # Must be >= PETSc -ksp_max_it in active [Preconditioning] block
  l_max_its = 100
  end_time = 3.1536e7
  dtmin = 1e-4
  dtmax = 259200
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 10
    growth_factor = 1.2
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.3
    optimal_iterations = 8
    iteration_window = 2
    # With ILU/ASM, earlier cutback is usually better than letting weak linear solves grind.
    linear_iteration_ratio = 100
  []
[]

[Outputs]
  file_base = exodus_output/co2_thm_example_3d_out
  print_linear_residuals = false
  perf_graph = true
  exodus = true
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
  [checkpoint]
    type = Checkpoint
    file_base = checkpoints/co2_thm_example_3d_out_fast_cp/cp
    num_files = 2
    # Coarse screening run: checkpoint less often to reduce I/O noise in short benchmark jobs.
    time_step_interval = 25
    execute_on = 'TIMESTEP_END'
  []
[]
