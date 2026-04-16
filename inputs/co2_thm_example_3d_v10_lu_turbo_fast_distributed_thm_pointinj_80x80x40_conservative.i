# 3D coupled THM CO2 - 32x32x16 conservative screening version.
# Base: co2_thm_example_3d_v10_lu_turbo_fast_distributed_pointinj_bjacobi_32x32x16.i
# Changes: keep the 32x32x16 THM + point-injection structure, but use the
#          conservative injection/time-step controls and safer Jacobian options.
[Mesh]
  parallel_type = distributed
  # final_generator = well_block
  final_generator = gen
  [gen]
    type = GeneratedMeshGenerator
    dim = 3
    nx = 80
    ny = 80
    nz = 40
    xmin = 900
    xmax = 1100
    ymin = 900
    ymax = 1100
    zmin = -840
    zmax = -800
  []

  # [well_block]
  #   type = SubdomainBoundingBoxGenerator
  #   input = gen
  #   block_id = 10
  #   block_name = wellbore
  #   bottom_left = '997.5 997.5 -840.0'
  #   top_right   = '1002.5 1002.5 -836.0'
  #   show_info = false
  # []
[]

[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
  PorousFlowDictator = dictator
  gravity = '0 0 -9.81'
  biot_coefficient = 1.0
[]

[Variables]
  [pgas]
    scaling = 1e-6
    []
  [zi]
    initial_condition = 1e-12
    scaling = 1e3 # 或者尝试 1e3
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
  show_var_residual_norms = true
  show_top_residuals = 0
[]

[AuxVariables]
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
  [xnacl]
    initial_condition = 0.0
    outputs = 'none'
  []

  [saturation_gas]
    family = MONOMIAL
    order = CONSTANT
  []
  # Keep this nodal aux around in case we want to re-enable variable bounds later.
  # [bounds_dummy]
  #  order = FIRST
  # family = LAGRANGE
  # outputs = 'none'
  # []
  # [stress_zz]
  #   order = CONSTANT
  #   family = MONOMIAL
  # []
  # [stress_xx]
  #   order = CONSTANT
  #   family = MONOMIAL
  # []
  # [stress_yy]
  #   order = CONSTANT
  #   family = MONOMIAL
  # []
  # [stress_xy]
  #   order = CONSTANT
  #   family = MONOMIAL
  # []
  # [stress_yz]
  #   order = CONSTANT
  #   family = MONOMIAL
  # []
  # [stress_xz]
  #   order = CONSTANT
  #   family = MONOMIAL
  # []
  # [vonmises]
  #   order = CONSTANT
  #   family = MONOMIAL
  # []
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
  # [co2_well_source]
  #   type = BodyForce
  #   variable = zi
  #   block = wellbore
  #   function = co2_source_density
  # []
  # [co2_enthalpy_source]
  #   type = BodyForce
  #   variable = temp
  #   block = wellbore
  #   function = co2_enthalpy_source_fn
  # []
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
  # [stress_zz_calc]
  #   type = RankTwoAux
  #   variable = stress_zz
  #   rank_two_tensor = stress # 对应 Materials 里的 stress
  #   index_i = 2 # 0=x, 1=y, 2=z
  #   index_j = 2
  #   execute_on = 'initial timestep_end'
  # []
  # [stress_xx_calc]
  #   type = RankTwoAux
  #   variable = stress_xx
  #   rank_two_tensor = stress
  #   index_i = 0
  #   index_j = 0
  #   execute_on = 'initial timestep_end'
  # []
  # [stress_yy_calc]
  #   type = RankTwoAux
  #   variable = stress_yy
  #   rank_two_tensor = stress
  #   index_i = 1
  #   index_j = 1
  #   execute_on = 'initial timestep_end'
  # []
  # [stress_xy_calc]
  #   type = RankTwoAux
  #   variable = stress_xy
  #   rank_two_tensor = stress
  #   index_i = 0
  #   index_j = 1
  #   execute_on = 'initial timestep_end'
  # []
  # [stress_yz_calc]
  #   type = RankTwoAux
  #   variable = stress_yz
  #   rank_two_tensor = stress
  #   index_i = 1
  #   index_j = 2
  #   execute_on = 'initial timestep_end'
  # []
  # [stress_xz_calc]
  #   type = RankTwoAux
  #   variable = stress_xz
  #   rank_two_tensor = stress
  #   index_i = 0
  #   index_j = 2
  #   execute_on = 'initial timestep_end'
  # []
  # [vonmises_calc]
  #   type = RankTwoScalarAux
  #   variable = vonmises
  #   rank_two_tensor = stress
  #   scalar_type = VonMisesStress
  #   execute_on = 'initial timestep_end'
  # []
[]

[DiracKernels]
  [co2_inject_line]
    type = PorousFlowPolyLineSink
    variable = zi
    point_file = inputs/co2_injection_well_centerline_80x80x40.bh
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
    point_file = inputs/co2_injection_well_centerline_80x80x40.bh
    p_or_t_vals = '0'
    fluxes = '-1'
    multiplying_var = inj_heat_flux_scale
    SumQuantityUO = heat_line_sink_sum
  []
[]

[Dampers]
  [zi_max_increment]
    type = MaxIncrement
    variable = zi
    max_increment = 0.1  # was 0.05: less restrictive during ramp-up
  []
  [pgas_min]
    type = BoundingValueNodalDamper
    variable = pgas
    min_value = 1e5
  []
  [pgas_max_inc]
    type = MaxIncrement
    variable = pgas
    max_increment = 5e5  # was 5e5: 0.5 MPa cap forced many NL iterations; 2 MPa is still safe
  []
  [temp_max_inc]
    type = MaxIncrement
    variable = temp
    max_increment = 5.0
  []
  [temp_bounds]
    type = BoundingValueNodalDamper
    variable = temp
    min_value = 287.0    # was 274.15: must stay above CO2/brine flash lower limit 285.15 K;
                         # when KSP fails and returns a garbage direction, the l2 line search
                         # evaluates residuals BEFORE dampers apply — if temp reaches 250 K
                         # the PorousFlowBrineCO2 flash aborts. 287 K gives 2 K margin.
    max_value = 490.0    # was 423.15: keep below water table upper limit of 500 K;
                         # temperature reaching 503 K (seen in log) caused tabulation abort.
    min_damping = 0.02   # re-added at smaller value (was 0.05, then removed);
                         # without min_damping, Newton stalls at 0 damping when already
                         # at a bound, causing DIVERGED_MAX_IT without making progress.
  []
[]

[Functions]
  [dt_cap_fn]
    type = PiecewiseLinear
    x = '0 5.8e4 6.2e4 6.40e4 6.44e4 6.48e4 6.55e4 6.8e4 7.2e4 3.1536e7'
    y = '1800 900 300 100 50 50 100 300 900 5400'
  []
  # [injection_heat_scale]
  #   type = ParsedFunction
  #   expression = 'if(t < 10, 0, if(t < 259200, ((t-10)/259190)^2, 1))'
  # []
  [injection_rate]
    type = ParsedFunction
    expression = 'if(t < 10, 0, if(t < 259200, 2*(((t-10)/259190)^2)*(3-2*((t-10)/259190)), 2))'
  []
  # [injection_rate_per_m]
  #   type = ParsedFunction
  #   expression = 'if(t < 10, 0, if(t < 259200, 2*(((t-10)/259190)^2)*(3-2*((t-10)/259190)), 2))'
  # []
  [injection_rate_per_m]
    type = ParsedFunction
    expression = 'qtot / 10.0'
    symbol_names = 'qtot'
    symbol_values = 'injection_rate'
  []
  [injection_heat_rate_per_m]
    type = ParsedFunction
    expression = 'qtot / 10.0'
    symbol_names = 'qtot'
    symbol_values = 'injection_rate'
  []
  # [injection_heat_rate_per_m]
  #   type = ParsedFunction
  #   expression = 'if(t < 10, 0, if(t < 259200, 2*(((t-10)/259190)^2)*(3-2*((t-10)/259190)), 2))'
  # []
  # [co2_source_density]
  #   type = ParsedFunction
  #   expression = '(if(t < 10, 0, if(t < 259200, 2*(((t-10)/259190)^2)*(3-2*((t-10)/259190)), 2)))/100'
  # []
  # [co2_enthalpy_source_fn]
  #   type = ParsedFunction
  #   expression = 'co2_src * heat_scale * 3.40e5'
  #   symbol_names = 'co2_src heat_scale'
  #   symbol_values = 'co2_source_density injection_heat_scale'
  # []
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
  [co2_line_sink_sum]
    type = PorousFlowSumQuantity
  []

  [heat_line_sink_sum]
    type = PorousFlowSumQuantity
  []
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
    input_fp = water_raw
    temperature_min = 275
    pressure_max = 1E8
    fluid_property_output_file = /p/scratch/hai_1214/xu28/sleipner/moose_input/tables/water97_tabulated_screen.csv
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
    input_fp = co2_raw
    temperature_min = 275
    pressure_max = 1E8
    fluid_property_output_file = /p/scratch/hai_1214/xu28/sleipner/moose_input/tables/co2_tabulated_screen.csv
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
    block = 0
    porosity = 0.2
  []
  # [porosity_wellbore]
  #   type = PorousFlowPorosityConst
  #   block = wellbore
  #   porosity = 0.35
  # []
  [permeability_reservoir]
    type = PorousFlowPermeabilityConst
    block = 0
    permeability = '2e-13 0 0  0 2e-13 0  0 0 2e-13'
  []
  # [permeability_wellbore]
  #   type = PorousFlowPermeabilityConst
  #   block = wellbore
  #   permeability = '1e-11 0 0  0 1e-11 0  0 0 1e-11'
  # []
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



[Postprocessors]
  [dt_cap_pp]
    type = FunctionValuePostprocessor
    function = dt_cap_fn
    execute_on = 'initial timestep_begin'
    outputs = none
  []
  [p_injection]
    type = PointValue
    variable = pgas
    point = '1000 1000 -838'
    execute_on = timestep_end
    use_displaced_mesh = false
  []
  [temp_at_well]
    type = PointValue
    variable = temp
    point = '1000 1000 -838'
    execute_on = timestep_end
    use_displaced_mesh = false
  []
  [dt]
    type = TimestepSize
    execute_on = 'initial timestep_end'
  []
  # [injected_mass_this_step]
  #   type = ParsedPostprocessor
  #   expression = 'source_density_pp * 100 * dt'
  #   pp_names = 'source_density_pp dt'
  #   execute_on = timestep_end
  #   outputs = none
  # []
  # [source_density_pp]
  #   type = FunctionValuePostprocessor
  #   function = co2_source_density
  #   execute_on = 'initial timestep_begin'
  #   outputs = none
  # []
  [injection_mass_flux]
    type = FunctionValuePostprocessor
    function = injection_rate_per_m
    execute_on = 'initial timestep_begin'
    outputs = none
  []
  [injected_mass_this_step]
    type = ParsedPostprocessor
    expression = 'injection_mass_flux * dt'
    pp_names = 'injection_mass_flux dt'
    execute_on = timestep_end
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
[]


[Preconditioning]
  active = 'hypre_fast'
  [mumps_safe]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_mat_solver_type -pc_factor_shift_type -ksp_rtol -ksp_max_it -snes_lag_jacobian -mat_mumps_icntl_14 -pc_factor_nonzeros_along_diagonal'
    petsc_options_value = 'preonly lu mumps NONZERO 1e-4 1500 2 400 1e-10'
  []
  [ilu_fast]
    type = SMP
    full = false
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_levels -pc_factor_mat_ordering_type -pc_factor_shift_type -pc_factor_shift_amount -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -pc_factor_nonzeros_along_diagonal'
    petsc_options_value = 'gmres ilu 5 rcm NONZERO 1e-10 5e-4 3000 150 1 1e-10'
  []
  [ilu_asm]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -pc_asm_overlap -sub_ksp_type -sub_pc_type -sub_pc_factor_shift_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -ksp_diagonal_scale -ksp_diagonal_scale_fix -ksp_gmres_modifiedgramschmidt -sub_pc_factor_nonzeros_along_diagonal'
    petsc_options_value = 'gmres asm 2 preonly lu NONZERO 2e-2 3000 200 1 true true true 1e-10'
  []
  [bjacobi_lu]
    type = SMP
    full = true
    petsc_options_iname = '-pc_type -sub_pc_type -sub_pc_factor_shift_type'
    petsc_options_value = 'bjacobi lu NONZERO'
  []

  [hypre_fast]
    type = SMP
    full = true
    coupled_groups = 'pgas,zi,temp disp_x,disp_y,disp_z'
    petsc_options_iname = '-ksp_type -pc_type -pc_hypre_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -pc_hypre_boomeramg_strong_threshold'
    petsc_options_value = 'fgmres hypre boomeramg 1e-8 500 200 0.5'
  []
  # [hypre_fast]
  #   type = SMP
  #   full = false
  #   trust_my_coupling = true
  #   coupled_groups = 'pgas,zi,temp temp,disp_x,disp_y,disp_z pgas,disp_x,disp_y,disp_z'
  #   petsc_options_iname = '-ksp_type -pc_type -pc_hypre_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -pc_hypre_boomeramg_strong_threshold -pc_hypre_boomeramg_coarsen_type -pc_hypre_boomeramg_interp_type -pc_hypre_boomeramg_agg_nl -pc_hypre_boomeramg_P_max -pc_hypre_boomeramg_truncfactor'
  #   petsc_options_value = 'fgmres hypre boomeramg 1e-2 400 60 1 0.7 HMIS ext+i 2 2 0.3'
  # []
  [hypre_fgmres_loose]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -pc_hypre_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -pc_hypre_boomeramg_strong_threshold -pc_hypre_boomeramg_coarsen_type -pc_hypre_boomeramg_relax_type_all'
    petsc_options_value = 'fgmres hypre boomeramg 5e-2 1000 150 1 0.25 hmis jacobi'
  []
  [gamg]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -ksp_rtol -ksp_max_it -ksp_gmres_restart -snes_lag_jacobian -pc_gamg_threshold'
    petsc_options_value = 'gmres gamg 5e-3 3000 150 1 0.05'
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  # petsc_options_iname = '-snes_max_linear_solve_fail'
  # petsc_options_value = '20'
  petsc_options_iname = '-snes_ksp_ew -snes_ksp_ew_version -snes_lag_jacobian_persists -snes_max_linear_solve_fail'
  petsc_options_value = 'true 2 true 10'
  line_search = none   # was l2: l2 evaluates residual at a trial point using a quadratic model;
                     # if that trial point has out-of-range temperature (after KSP fails),
                     # it aborts. bt (backtracking) halves the step and retries, which can
                     # avoid the out-of-range region without aborting.
  automatic_scaling = true
  compute_scaling_once = true
  nl_abs_tol = 1E-4
  nl_rel_tol = 1E-8
  nl_max_its = 25   # was 20: extra headroom prevents premature DIVERGED_MAX_IT
  l_max_its = 300   # was 200: more Krylov budget for hard steps
  end_time = 3.1536e7
  dtmin = 1e-3
  dtmax = 10800   # was 21600 (6h); cap at 1.5h during injection ramp to prevent the
                 # preconditioner breakdown that occurs when dt grows to ~8800 s near
                 # the two-phase front at t≈59000 s. Post-injection larger dt is
                 # acceptable but this single cap keeps the run safe throughout.
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 3
    growth_factor = 1.1
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.5
    optimal_iterations = 20
    iteration_window = 5
    linear_iteration_ratio = 150
    timestep_limiting_postprocessor = 'dt_cap_pp'
    reject_large_step = true
    reject_large_step_threshold = 0.8
  []
[]

[Outputs]
  print_linear_residuals = true
  perf_graph = true

  #[nemesis] \
  #  type = Nemesis \
  #  file_base = exodus_output/co2_thm_example_3d_out \
  #  time_step_interval = 500 \
  #  use_displaced = false \
  #  write_hdf5 = true   # 如果你环境支持并想进一步优化并行 I/O，可测试开启 \
  #[]

  [exodus]
    type = Exodus
    file_base = exodus_output/co2_th_only_out
    time_step_interval = 20
    execute_on = 'final'
  []
  # [exodus]
  #   type = Nemesis
  #   file_base = exodus_output/co2_th_only_out
  #   time_step_interval = 20
  #   execute_on = 'timestep_end final'
  #   use_displaced = false
  # []

  [console]
    type = Console
    show = 'p_injection temp_at_well total_injected_mass co2_mass h2o_mass total_fluid_mass'
    execute_on = 'timestep_end'
    time_step_interval = 10
  []

  [csv]
    type = CSV
    file_base = csv_outputs/co2_thm_example_3d_out_v10_turbo_fast
    execute_on = 'final'
  []

  [checkpoint]
    type = Checkpoint
    file_base = outputs/experiments/co2_thm_80x80x40_cons/checkpoints/cp
    num_files = 2
    time_step_interval = 20
    execute_on = 'TIMESTEP_END'
  []
[]