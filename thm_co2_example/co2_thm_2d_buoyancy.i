# Two phase, isothermal system (T=323 K constant), with mechanics
# 2D x–深度 平面（无 y）：x 水平 0–5000 m，第二轴为深度 800–1300 m（上→下）
# MOOSE 2D 仅支持 (x,y)，此处 y 即深度；可视作 xz 剖面。Injection at bottom (y=1300).
# species=0 is water, species=1 is co2; phase=0 liquid, phase=1 gas.
[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 50
    ny = 50
    xmin = 0
    xmax = 2000   # 恢复为 2 km 以匹配 0050 截断点并确保连续性
    ymin = 800    # top (cap rock) — 深度上边界
    ymax = 1300   # bottom (injection) — 深度下边界
  []
  [corner]
    type = ExtraNodesetGenerator
    input = gen
    new_boundary = 'corner_anchor'
    coord = '0 800 0'
  []
[]

[GlobalParams]
  displacements = 'disp_x disp_y'  # 2D: x + 深度(y)
  PorousFlowDictator = dictator
  gravity = '0 9.81 0'    # 重力沿 +y（y=深度，y 增大 = 越深，压力越大）
  biot_coefficient = 1.0
[]

[Variables]
  [pwater]
    # Initial condition set via [ICs] block using hydrostatic pressure function
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
    initial_condition = 1 # all H20 in phase=0
  []
  [massfrac_ph1_sp0]
    initial_condition = 0 # no H2O in phase=1
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
  [stress_xy]
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
  [temp_fixed]
    type = Reaction
    variable = temp
    rate = 0
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
  [stress_xy]
    type = RankTwoAux
    rank_two_tensor = stress
    variable = stress_xy
    index_i = 0
    index_j = 1
  []
[]

[Functions]
  [hydrostatic_pressure]
    type = ParsedFunction
    # Hydrostatic: p(深度) = 1e5 + 9.810*y, y = depth [800,1300]
    expression = '1e5 + 970*9.810*y'
  []
[]

[UserObjects]
  [dictator]
    type = PorousFlowDictator
    porous_flow_vars = 'temp pwater sgas disp_x disp_y'
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
    # 采用官方渗透率数值，但保持各向同性以确保能发生垂直浮力(不破坏caprock的阻挡机制)
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
  # Thermal materials omitted for isothermal (T=323 K fixed)
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
    initial_stress = '0 0 0  0 0 0  0 0 0'
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
  # 选项 A: 全封闭边界 — left/right 无显式 pwater BC （即 natural Neumann 零通量）
  # CO2 无法水平逃逸，质量在域内真实积累，压力随注入持续上升
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
  # 右边界开放：固定水压和 CO2 饱和度 (允许流体流出域外)
  [outer_pressure_fixed]
    type = FunctionDirichletBC
    boundary = right
    function = hydrostatic_pressure
    variable = pwater
  []
  [outer_saturation_fixed]
    type = DirichletBC
    boundary = right
    value = 0.0
    variable = sgas
  []
  # sgas: no explicit BC at left — CO2 can flow laterally through the domain
  # Left sgas zero-flux
  [left_no_flow_sgas]
    type = PorousFlowSink
    boundary = left
    variable = sgas
    use_mobility = false
    use_relperm = false
    fluid_phase = 1
    flux_function = 0
  []
  [bottom_temp]
    type = DirichletBC
    boundary = bottom
    value = 323
    variable = temp
  []
  # Zero-flux for sgas at bottom (cap rock): CO2 cannot escape upward through cap
  [bottom_no_flow_sgas]
    type = PorousFlowSink
    boundary = bottom
    variable = sgas
    use_mobility = false
    use_relperm = false
    fluid_phase = 1
    flux_function = 0
  []
  # 底面 深度=1300 (MOOSE top): 注入侧 — 压力自由（由 DiracKernel 点源驱动），仅固定温度
  [top_temp]
    type = DirichletBC
    boundary = top
    value = 323
    variable = temp
  []
  # 位移: 左右固定 x，顶面(盖层)固定 y（深度方向）
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
  [fixed_bottom_y]
    type = DirichletBC
    variable = disp_y
    value = 0
    boundary = bottom
  []
[]

# Fix 2: 改用 DiracKernel 点源注入（PorousFlowSquarePulsePointSource），不再使用边界 flux BC
[DiracKernels]
  [co2_inject]
    type = PorousFlowSquarePulsePointSource
    start_time = 0
    end_time = 1.5768e8      # 5 years
    mass_flux = 10          # 10 kg/s injection (significantly reduced to prevent pressure spikes)
    point = '1000 1295 0'   # injection point at center (x=1000m) of 2km domain
    variable = sgas
  []
[]

[Postprocessors]
  [p_injection]
    type = PointValue
    variable = pwater
    point = '1000 1299 0'
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
    point = '1000 1290 0'
    execute_on = timestep_end
  []
  # 注入量监控：用于验证 CO2 是否真的注入（total_injected ≈ 10 * time）
  [dt]
    type = TimestepSize
    execute_on = 'initial timestep_end'
  []
  # DiracKernel: 10 kg/s × dt per step
  [injected_mass_this_step]
    type = ParsedPostprocessor
    expression = '10 * dt'
    pp_names = 'dt'
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
[]

[VectorPostprocessors]
  [vertical_profile]
    type = LineValueSampler
    use_displaced_mesh = false
    start_point = '1000 805.1 0'
    end_point = '1000 1300 0'
    sort_by = y
    num_points = 500
    outputs = csv
    variable = 'pwater temp sgas disp_x disp_y stress_xx stress_yy stress_xy'
  []
  [horizontal_profile]
    type = LineValueSampler
    use_displaced_mesh = false
    start_point = '0 1250 0'
    end_point = '2000 1250 0'
    sort_by = x
    num_points = 500
    outputs = csv
    variable = 'pwater temp sgas disp_x disp_y stress_xx stress_yy stress_xy'
  []
[]

[Preconditioning]
  active = 'smp'
  [smp]
    type = SMP
    full = true
    petsc_options_iname = '-ksp_type -pc_type -sub_pc_type -sub_pc_factor_shift_type -pc_asm_overlap -snes_atol -snes_rtol -snes_max_it -snes_linesearch_type'
    petsc_options_value = 'gmres      asm      lu           NONZERO                   2               1e-3     1e-5        500 basic'
  []
  [mumps]
    type = SMP
    full = true
    petsc_options = '-snes_converged_reason'
    petsc_options_iname = '-ksp_type -pc_type -pc_factor_mat_solver_package -pc_factor_shift_type -snes_rtol -snes_atol -snes_max_it'
    petsc_options_value = 'gmres      lu       mumps                         NONZERO               1e-5       1e-6      80'
  []
[]

[Executioner]
  type = Transient
  solve_type = NEWTON
  end_time = 1.5768e8
  dtmin = 1            # Abort if cutback would go below this (prevents infinite loop)
  [TimeStepper]
    type = IterationAdaptiveDT
    dt = 1
    growth_factor = 1.1
    cutback_factor = 0.75
    cutback_factor_at_failure = 0.5
  []
[]

[Outputs]
  file_base = co2_thm_2d_buoyancy_out
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
    file_base = co2_thm_2d_buoyancy_out_cp/cp
    num_files = 2
    time_step_interval = 50
    execute_on = 'TIMESTEP_END'
  []
[]
