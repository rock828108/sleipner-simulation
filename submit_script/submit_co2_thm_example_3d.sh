#!/bin/bash
#SBATCH --job-name=co2_thm_3d
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4            # OpenMP threads for 3D THM; increase for production
#SBATCH --mem=150G                   # 3D 20^3 mesh with THM coupling
#SBATCH --time=30-00:00:00           # 30 days time limit
#SBATCH --output=thm_co2_example/logs/slurm-%j.out
#SBATCH --error=thm_co2_example/logs/slurm-%j.err
#SBATCH --partition=qdefault

# OpenMP: use SLURM_CPUS_PER_TASK; cap for MOOSE/LibMesh if needed
NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"
if [ -n "${MOOSE_N_THREADS}" ]; then
  :
else
  MOOSE_N_THREADS="${NUM_THREADS}"
  # [ "${MOOSE_N_THREADS}" -gt 4 ] 2>/dev/null && MOOSE_N_THREADS=4
fi
export OMP_NUM_THREADS="${MOOSE_N_THREADS}"

# Optional benchmark selectors (can also be used to label outputs)
BENCHMARK_STEPS="${BENCHMARK_STEPS:-}"
BENCHMARK_TAG="${BENCHMARK_TAG:-}"

# Setup MOOSE environment
module purge 2>/dev/null || true
source /etc/profile.d/modules.sh 2>/dev/null || true
module load OpenMPI/4.1.1-GCC-11.2.0 2>/dev/null || true
if [ -f "$HOME/miniforge3/etc/profile.d/conda.sh" ]; then
  source "$HOME/miniforge3/etc/profile.d/conda.sh"
  conda activate moose-py2 2>/dev/null || true
fi
MOOSE_PY2_LIB="${MOOSE_PY2_LIB:-$HOME/miniforge3/envs/moose-py2/lib}"
export LD_LIBRARY_PATH="$HOME/projects/moose/lib:$HOME/projects/moose/libmesh/lib:${CONDA_PREFIX}/lib:${MOOSE_PY2_LIB}:/usr/lib64:${LD_LIBRARY_PATH}"

# MOOSE executable path
MOOSE_EXE="${MOOSE_EXE:-$HOME/projects/moose/modules/porous_flow/porous_flow-opt}"

# Package root = directory containing thm_co2_example/ and submit_script/
# Run sbatch from package root: sbatch submit_script/submit_co2_thm_example_3d.sh
if [ -n "$SLURM_SUBMIT_DIR" ]; then
  if [ -d "$SLURM_SUBMIT_DIR/thm_co2_example-20260203T160116Z-3-001/submit_script" ]; then
    SCRIPT_DIR="$SLURM_SUBMIT_DIR/thm_co2_example-20260203T160116Z-3-001"
  elif [ -d "$SLURM_SUBMIT_DIR/submit_script" ]; then
    SCRIPT_DIR="$SLURM_SUBMIT_DIR"
  else
    SCRIPT_DIR="$(pwd)"
  fi
else
  SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fi

# Input file: co2_thm_example_3d.i
INPUT_BASENAME="${INPUT_BASENAME:-co2_thm_example_3d.i}"
INPUT_FILE="${SCRIPT_DIR}/thm_co2_example/${INPUT_BASENAME}"

# Verify input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file not found: $INPUT_FILE"
  echo "Script directory: $SCRIPT_DIR"
  echo "SLURM_SUBMIT_DIR: ${SLURM_SUBMIT_DIR:-not set}"
  echo "Current dir: $(pwd)"
  exit 1
fi

# Change to input file directory (thm_co2_example/)
cd "$(dirname "$INPUT_FILE")" || {
  echo "Error: Cannot cd to $(dirname "$INPUT_FILE")"
  exit 1
}

# ============================================================================
# Output/Checkpoint naming
# ============================================================================
# Base names from input file:
#   Outputs/file_base = co2_thm_example_3d_out
#   Outputs/checkpoint/file_base = co2_thm_example_3d_out_cp/cp
#
# If BENCHMARK_TAG is set, outputs become:
#   co2_thm_example_3d_out_${BENCHMARK_TAG}.e
#   co2_thm_example_3d_out_${BENCHMARK_TAG}_cp/cp_cp/
#
# If BENCHMARK_STEPS is set but BENCHMARK_TAG is empty, use:
#   BENCHMARK_TAG=omp${MOOSE_N_THREADS}
# ============================================================================
DEFAULT_OUTPUT_BASE="co2_thm_example_3d_out"
if [ -n "$BENCHMARK_TAG" ]; then
  RUN_LABEL="$BENCHMARK_TAG"
elif [ -n "$BENCHMARK_STEPS" ]; then
  RUN_LABEL="omp${MOOSE_N_THREADS}"
else
  RUN_LABEL=""
fi

if [ -n "$RUN_LABEL" ]; then
  OUTPUT_FILE_BASE="${DEFAULT_OUTPUT_BASE}_${RUN_LABEL}"
  CHECKPOINT_FILE_BASE="${OUTPUT_FILE_BASE}_cp/cp"
else
  OUTPUT_FILE_BASE="${DEFAULT_OUTPUT_BASE}"
  CHECKPOINT_FILE_BASE="${DEFAULT_OUTPUT_BASE}_cp/cp"
fi

OUTPUT_OVERRIDE_ARGS="Outputs/file_base=${OUTPUT_FILE_BASE} Outputs/checkpoint/file_base=${CHECKPOINT_FILE_BASE}"

# ============================================================================
# Checkpoint Recovery Configuration
# ============================================================================
# To continue from the previous run's latest checkpoint:
#
#   RESTART_FROM=latest sbatch submit_script/submit_co2_thm_example_3d.sh
#
# Other options:
#   RESTART_FROM=0050             # Restart from checkpoint number 50
#   RESTART_FROM=list             # List available checkpoints and exit
# ============================================================================
# CP_DIR defaults to the active checkpoint file_base + "_cp"
# (MOOSE maps ".../cp" -> ".../cp_cp/" directory)
CP_DIR="${CP_DIR:-${CHECKPOINT_FILE_BASE}_cp}"
RECOVER_ARG=""

# Function to find latest checkpoint
find_latest_checkpoint() {
  local cp_dir="$1"
  local latest_mesh=$(ls -d "${cp_dir}"/[0-9]*-mesh.cpa.gz 2>/dev/null | sort -V | tail -1)
  if [ -n "$latest_mesh" ]; then
    basename "$latest_mesh" -mesh.cpa.gz
  else
    local latest_cpr=$(ls -d "${cp_dir}"/[0-9]*-mesh.cpr 2>/dev/null | sort -V | tail -1)
    if [ -n "$latest_cpr" ]; then
      basename "$latest_cpr" -mesh.cpr
    fi
  fi
}

# Function to list available checkpoints
list_checkpoints() {
  local cp_dir="$1"
  echo "=========================================="
  echo "Available Checkpoints in: ${cp_dir}/"
  echo "=========================================="
  if [ ! -d "$cp_dir" ]; then
    echo "Checkpoint directory does not exist: $cp_dir"
    return 1
  fi
  local checkpoints=$(ls -d "${cp_dir}"/[0-9]*-mesh.cpa.gz 2>/dev/null | \
                      sed 's/.*\/\([0-9]*\)-mesh\.cpa\.gz/\1/' | sort -V)
  if [ -z "$checkpoints" ]; then
    echo "No checkpoints found."
    return 1
  fi
  echo "Checkpoint numbers:"
  for cp_num in $checkpoints; do
    local cp_base="${cp_dir}/${cp_num}"
    local files=""
    [ -e "${cp_base}-mesh.cpa.gz" ] && files="${files} mesh.cpa.gz"
    [ -e "${cp_base}-mesh.cpr" ] && files="${files} mesh.cpr"
    [ -e "${cp_base}.rd" ] && files="${files} .rd"
    [ -e "${cp_base}-restart-0.rd" ] && files="${files} -restart-0.rd"
    [ -n "$files" ] && echo "  $cp_num: $files"
  done
  local latest=$(find_latest_checkpoint "$cp_dir")
  [ -n "$latest" ] && echo "" && echo "Latest checkpoint: $latest"
  echo "=========================================="
}

# Function to validate checkpoint
validate_checkpoint() {
  local cp_dir="$1"
  local cp_num="$2"
  local cp_base="${cp_dir}/${cp_num}"
  if [ ! -e "${cp_base}-mesh.cpa.gz" ] && [ ! -e "${cp_base}-mesh.cpr" ]; then
    echo "Error: Checkpoint $cp_num is incomplete (missing mesh files)"
    return 1
  fi
  if [ ! -e "${cp_base}.rd" ] && [ ! -e "${cp_base}-restart-0.rd" ]; then
    echo "Warning: Checkpoint $cp_num may be incomplete (missing .rd file)"
  fi
  return 0
}

# Handle checkpoint recovery
if [ -n "${RESTART_FROM}" ]; then
  case "${RESTART_FROM}" in
    list|LIST)
      list_checkpoints "$CP_DIR"
      exit 0
      ;;
    latest|LATEST|auto|AUTO)
      echo "Auto-detecting latest checkpoint..."
      RESTART_FROM=$(find_latest_checkpoint "$CP_DIR")
      if [ -z "$RESTART_FROM" ]; then
        echo "Warning: No checkpoint found in ${CP_DIR}/"
        RECOVER_ARG=""
      else
        if validate_checkpoint "$CP_DIR" "$RESTART_FROM"; then
          RECOVER_ARG="--recover ${CP_DIR}/${RESTART_FROM}"
          echo "Restarting from latest checkpoint: $RESTART_FROM"
        else
          echo "Error: Latest checkpoint $RESTART_FROM is invalid"
          exit 1
        fi
      fi
      ;;
    *)
      if validate_checkpoint "$CP_DIR" "${RESTART_FROM}"; then
        RECOVER_ARG="--recover ${CP_DIR}/${RESTART_FROM}"
        echo "Restarting from checkpoint: $RESTART_FROM"
      else
        echo "Error: Checkpoint ${RESTART_FROM} is invalid or incomplete"
        list_checkpoints "$CP_DIR"
        exit 1
      fi
      ;;
  esac
else
  latest_cp=$(find_latest_checkpoint "$CP_DIR")
  if [ -n "$latest_cp" ]; then
    echo "=========================================="
    echo "Notice: Checkpoints found but RESTART_FROM not set"
    echo "Latest checkpoint: $latest_cp"
    echo "To restart: RESTART_FROM=latest sbatch submit_script/submit_co2_thm_example_3d.sh"
    echo "=========================================="
    echo "Starting fresh simulation..."
  fi
fi

if [ -n "$RECOVER_ARG" ]; then
  echo ""
  echo "Checkpoint Recovery: ${CP_DIR}/ ${RESTART_FROM}"
  echo ""
fi

# Optional benchmark mode
# Example:
#   BENCHMARK_STEPS=50 sbatch --cpus-per-task=8 submit_script/submit_co2_thm_example_3d.sh
# It will stop after 50 timesteps and append runtime summary to RUNTIME_LOG.
RUNTIME_LOG="${RUNTIME_LOG:-logs/openmp_runtime.tsv}"
BENCHMARK_ARG=""
if [ -n "$BENCHMARK_STEPS" ]; then
  BENCHMARK_ARG="Executioner/num_steps=${BENCHMARK_STEPS}"
fi

# Run MOOSE
echo "=========================================="
echo "Running MOOSE: co2_thm_example_3d.i (coupled THM 3D)"
echo "=========================================="
echo "Executable: $MOOSE_EXE"
echo "Input file: $(basename "$INPUT_FILE")"
echo "Working directory: $(pwd)"
echo "OpenMP threads: ${MOOSE_N_THREADS}"
echo "Output file_base: ${OUTPUT_FILE_BASE}"
echo "Checkpoint file_base: ${CHECKPOINT_FILE_BASE}"
if [ -n "$BENCHMARK_STEPS" ]; then
  echo "Benchmark mode: enabled (num_steps=${BENCHMARK_STEPS})"
fi
echo "=========================================="
echo ""

start_epoch=$(date +%s)
"$MOOSE_EXE" -i "$(basename "$INPUT_FILE")" --n-threads="${MOOSE_N_THREADS}" ${RECOVER_ARG} ${BENCHMARK_ARG} ${OUTPUT_OVERRIDE_ARGS}
run_exit_code=$?
end_epoch=$(date +%s)
elapsed_sec=$((end_epoch - start_epoch))

if [ ! -f "$RUNTIME_LOG" ]; then
  echo -e "date_utc\tjob_id\tthreads\tbenchmark_steps\trestart_from\telapsed_sec\texit_code\ttag\toutput_base\tcheckpoint_base" > "$RUNTIME_LOG"
fi
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  "${SLURM_JOB_ID:-na}" \
  "${MOOSE_N_THREADS}" \
  "${BENCHMARK_STEPS:-full}" \
  "${RESTART_FROM:-fresh}" \
  "${elapsed_sec}" \
  "${run_exit_code}" \
  "${RUN_LABEL}" \
  "${OUTPUT_FILE_BASE}" \
  "${CHECKPOINT_FILE_BASE}" >> "$RUNTIME_LOG"

echo ""
echo "Runtime summary:"
echo "  elapsed_sec = ${elapsed_sec}"
echo "  exit_code   = ${run_exit_code}"
echo "  log_file    = ${RUNTIME_LOG}"

exit "${run_exit_code}"
