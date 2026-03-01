# 3D coupled THM (thermo-hydro-mechanical) CO2 example.
# Flow setup from co2_thm_3d_flow_only.i: 2 km x 2 km x 500 m (depth 800–1300 m),
# hydrostatic IC, open lateral BCs, point injection at center bottom.
# Adds: full thermal (energy equation) and mechanics (displacement, stress, poroelastic coupling).
# species=0 water, species=1 co2; phase=0 liquid, phase=1 gas.
[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 3
    nx = 20
    ny = 20
    nz = 20
    xmin = 0
    xmax = 2000
    ymin = 0
    ymax = 2000
    zmin = 800
    zmax = 1300
  []
[]

[GlobalParams]
  displacements = 'disp_x disp_y disp_z'
  PorousFlowDictator = dictator
  gravity = '0 0 9.81'
  biot_coefficient = 1.0
[]

[Variables]
  [pwater]
  []
  [sgas]
    initial_condition = 0.0
  []
  [temp]
    initial_condition = 323
  []
  [disp_x]
  []
  [disp_y]
  []
  [disp_z]
  []
[]

[ICs]
  [pwater_hydrostatic]
    type = FunctionIC
    variable = pwater
    function = hydrostatic_pressure
  []
[]

[AuxVariables]
  [massfrac_ph0_sp0]
    initial_condition = 1
  []
  [massfrac_ph1_sp0]
    initial_condition = 0
  []
  [pgas]
    family = MONOMIAL
    order = FIRST
  []
  [swater]
    family = MONOMIAL
    order = FIRST
  []
  [sgas_aux]
    family = MONOMIAL
    order = FIRST
  []
  [stress_xx]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_yy]
    order = CONSTANT
    family = MONOMIAL
  []
  [stress_zz]
    order = CONSTANT
    family = MONOMIAL
  []
[]

[Kernels]
  [mass_water_dot]
    type = PorousFlowMassTimeDerivative
    fluid_component = 0
    variable = pwater
  []
  [flux_water]
    type = PorousFlowAdvectiveFlux
    fluid_component = 0
    use_displaced_mesh = false
    variable = pwater
  []
  [mass_co2_dot]
    type = PorousFlowMassTimeDerivative
    fluid_component = 1
    variable = sgas
  []
  [flux_co2]
    type = PorousFlowAdvectiveFlux
    fluid_component = 1
    use_displaced_mesh = false
    variable = sgas
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
    value = 9.81
  []
[]

[AuxKernels]
  [pgas]
    type = PorousFlowPropertyAux
    property = pressure
    phase = 1
    variable = pgas
  []
  [swater]
    type = PorousFlowPropertyAux
    property = saturation
    phase = 0
    variable = swater
  []
  [sgas_aux]
    type = PorousFlowPropertyAux
    property = saturation
    phase = 1
    variable = sgas_aux
  []
  [stress_xx]
    type = RankTwoAux
    rank_two_tensor = stress
    variable = stress_xx
    index_i = 0
    index_j = 0
  []
  [stress_yy]
    type = RankTwoAux
    rank_two_tensor = stress
    variable = stress_yy
    index_i = 1
    index_j = 1
  []
  [stress_zz]
    type = RankTwoAux
    rank_two_tensor = stress
    variable = stress_zz
    index_i = 2
    index_j = 2
  []
[]

[Functions]
  [hydrostatic_pressure]
    type = ParsedFunction
    expression = '1e5 + 970*9.810*z'
  []
  [ini_stress_fn]
    type = ParsedFunction
    expression = '-(1e5 + 970*9.81*z)'
  []
[]

[UserObjects]
  [dictator]
    type = PorousFlowDictator
    porous_flow_vars = 'temp pwater sgas disp_x disp_y disp_z'
    number_fluid_phases = 2
    number_fluid_components = 2
  []
  [pc]
    type = PorousFlowCapillaryPressureConst
    pc = 0
  []
[]

[FluidProperties]
  [water]
    type = SimpleFluidProperties
    bulk_modulus = 2.27e9
    density0 = 970.0
    viscosity = 0.3394e-3
    cv = 4149.0
    cp = 4149.0
    porepressure_coefficient = 0.0
    thermal_expansion = 0
  []
  [co2]
    type = SimpleFluidProperties
    bulk_modulus = 2.27e8
    density0 = 516.48
    viscosity = 0.0393e-3
    cv = 2920.5
    cp = 2920.5
    porepressure_coefficient = 0.0
    thermal_expansion = 0
  []
[]

[Materials]
  [temperature]
    type = PorousFlowTemperature
    temperature = temp
  []
  [ppss]
    type = PorousFlow2PhasePS
    phase0_porepressure = pwater
    phase1_saturation = sgas
    capillary_pressure = pc
  []
  [massfrac]
    type = PorousFlowMassFraction
    mass_fraction_vars = 'massfrac_ph0_sp0 massfrac_ph1_sp0'
  []
  [water]
    type = PorousFlowSingleComponentFluid
    fp = water
    phase = 0
  []
  [gas]
    type = PorousFlowSingleComponentFluid
    fp = co2
    phase = 1
  []
  [porosity_reservoir]
    type = PorousFlowPorosityConst
    porosity = 0.2
  []
  [permeability_reservoir]
    type = PorousFlowPermeabilityConst
    permeability = '2e-12 0 0  0 2e-12 0  0 0 2e-12'
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
    initial_stress = 'ini_stress_fn 0 0  0 ini_stress_fn 0  0 0 ini_stress_fn'
    eigenstrain_name = ini_stress
  []
  [thermal_contribution]
    type = ComputeThermalExpansionEigenstrain
    temperature = temp
    stress_free_temperature = 323
    thermal_expansion_coeff = 5E-6
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
  [left_temp]
    type = DirichletBC
    boundary = left
    value = 323
    variable = temp
  []
  [right_temp]
    type = DirichletBC
    boundary = right
    value = 323
    variable = temp
  []
  [front_temp]
    type = DirichletBC
    boundary = front
    value = 323
    variable = temp
  []
  [back_temp]
    type = DirichletBC
    boundary = back
    value = 323
    variable = temp
  []
  [bottom_temp]
    type = DirichletBC
    boundary = bottom
    value = 323
    variable = temp
  []
  [top_temp]
    type = DirichletBC
    boundary = top
    value = 323
    variable = temp
  []
  [left_pressure_open]
    type = FunctionDirichletBC
    boundary = left
    function = hydrostatic_pressure
    variable = pwater
  []
  [right_pressure_open]
    type = FunctionDirichletBC
    boundary = right
    function = hydrostatic_pressure
    variable = pwater
  []
  [front_pressure_open]
    type = FunctionDirichletBC
    boundary = front
    function = hydrostatic_pressure
    variable = pwater
  []
  [back_pressure_open]
    type = FunctionDirichletBC
    boundary = back
    function = hydrostatic_pressure
    variable = pwater
  []
  [left_sgas_open]
    type = DirichletBC
    boundary = left
    value = 0.0
    variable = sgas
  []
  [right_sgas_open]
    type = DirichletBC
    boundary = right
    value = 0.0
    variable = sgas
  []
  [front_sgas_open]
    type = DirichletBC
    boundary = front
    value = 0.0
    variable = sgas
  []
  [back_sgas_open]
    type = DirichletBC
    boundary = back
    value = 0.0
    variable = sgas
  []
  [fixed_left_x]
    type = DirichletBC
    variable = disp_x
    value = 0
    boundary = left
  []
  [fixed_right_x]
    type = DirichletBC
    variable = disp_x
    value = 0
    boundary = right
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
[]

[DiracKernels]
  [co2_inject]
    type = PorousFlowPointSourceFromPostprocessor
    # Keep full THM coupling but smooth the source startup (ramp to 0.1 kg/s by t=10 s).
    mass_flux = injection_mass_flux
    point = '1000 1000 1290'
    variable = sgas
  []
[]

[Postprocessors]
  [p_injection]
    type = PointValue
    variable = pwater
    point = '1000 1000 1290'
    execute_on = timestep_end
    use_displaced_mesh = false
  []
  [max_sgas]
    type = ElementExtremeValue
    variable = sgas
    value_type = max
    execute_on = timestep_end
  []
  [sgas_at_well]
    type = PointValue
    variable = sgas
    point = '1000 1000 1290'
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
    type = ParsedPostprocessor
    use_t = true
    # Ramp to 10 kg/s by 1e4 s, then keep injection constant for the rest of the 5-year run.
    expression = 'if(t < 1e-3, 0, if(t < 1e4, 10 * (t - 1e-3) / (1e4 - 1e-3), 10))'
    execute_on = 'initial nonlinear timestep_end'
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
[]

[VectorPostprocessors]
  [vertical_profile]
    type = LineValueSampler
    use_displaced_mesh = false
    start_point = '1000 1000 805.1'
    end_point = '1000 1000 1300'
    sort_by = z
    num_points = 500
    outputs = csv
    variable = 'pwater temp sgas'
  []
  [horizontal_profile]
    type = LineValueSampler
    use_displaced_mesh = false
    start_point = '0 1000 1250'
    end_point = '2000 1000 1250'
    sort_by = x
    num_points = 500
    outputs = csv
    variable = 'pwater temp sgas'
  []
[]

# Stage 1 for robustness: run flow + thermal only.
# Keep mechanics kernels disabled for the full run, then re-enable in stages.
[Controls]
  [flow_only_early]
    type = TimePeriod
    start_time = 0
    end_time = 1e99
    disable_objects = 'Kernel::gravity_z'
    execute_on = 'timestep_begin'
  []
[]

[Preconditioning]
  active = 'mumps'
  [smp]
    type = SMP
    full = false
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_shift_type -ksp_rtol -ksp_max_it -snes_atol -snes_rtol -snes_max_it -snes_linesearch_type'
    petsc_options_value = 'gmres     ilu      NONZERO               1e-5      500         1e3       1e-4       200         bt'
  []
  [mumps]
    type = SMP
    full = true
    petsc_options = '-snes_converged_reason -snes_monitor'
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_mat_solver_package -pc_factor_shift_type -snes_rtol -snes_atol -snes_max_it -snes_linesearch_type'
    petsc_options_value = 'preonly   lu       mumps                         NONZERO               1e-6       1e-3       50           bt'
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  end_time = 1.5768e8
  dtmin = 1e-6
  [TimeStepper]
    type = IterationAdaptiveDT
    # Start from 1 s; source ramp keeps loading smooth while preserving full THM coupling.
    dt = 1
    growth_factor = 1.1
    cutback_factor = 0.5
    cutback_factor_at_failure = 0.1
    optimal_iterations = 8
    iteration_window = 2
    linear_iteration_ratio = 50
  []
[]

[Outputs]
  file_base = co2_thm_example_3d_out
  print_linear_residuals = false
  perf_graph = true
  exodus = true
  [console]
    type = Console
    show = 'p_injection total_injected_mass co2_mass max_sgas sgas_at_well'
  []
  [csv]
    type = CSV
    sync_only = true
  []
  [checkpoint]
    type = Checkpoint
    file_base = co2_thm_example_3d_out_cp/cp
    num_files = 2
    time_step_interval = 50
    execute_on = 'TIMESTEP_END'
  []
[]
