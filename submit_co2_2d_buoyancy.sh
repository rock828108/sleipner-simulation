#!/bin/bash
#SBATCH --job-name=co2_2d_buoyancy
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1            # 1 thread for debugging; increase for production
#SBATCH --mem=150G              # Request 150GB memory for 100x100 mesh with THM coupling
#SBATCH --time=30-00:00:00       # 30 days time limit
#SBATCH --output=slurm-%j.out
#SBATCH --error=slurm-%j.err
#SBATCH --partition=qdefault

# OpenMP: default 1 thread for debugging (DIVERGED_LINE_SEARCH); use MOOSE_N_THREADS=4 for production
NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"
if [ -n "${MOOSE_N_THREADS}" ]; then
  :
else
  MOOSE_N_THREADS="${NUM_THREADS}"
  [ "${MOOSE_N_THREADS}" -gt 4 ] 2>/dev/null && MOOSE_N_THREADS=4
fi
export OMP_NUM_THREADS="${MOOSE_N_THREADS}"

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

# Get script directory - handle SLURM execution
# Script is in thm_co2_example-20260203T160116Z-3-001/, input file is in thm_co2_example/ subdirectory
# When running under SLURM, $0 points to temp directory, so use SLURM_SUBMIT_DIR
if [ -n "$SLURM_SUBMIT_DIR" ]; then
  # SLURM_SUBMIT_DIR is where sbatch was executed from
  # If submitted from sleipner/, it's sleipner/; if from thm_co2_example-20260203T160116Z-3-001/, it's that directory
  if [ -f "$SLURM_SUBMIT_DIR/thm_co2_example-20260203T160116Z-3-001/submit_co2_2d_buoyancy.sh" ]; then
    # Submitted from sleipner/ directory
    SCRIPT_DIR="$SLURM_SUBMIT_DIR/thm_co2_example-20260203T160116Z-3-001"
  elif [ -f "$SLURM_SUBMIT_DIR/submit_co2_2d_buoyancy.sh" ]; then
    # Submitted from thm_co2_example-20260203T160116Z-3-001/ directory
    SCRIPT_DIR="$SLURM_SUBMIT_DIR"
  else
    # Fallback: try to find from current working directory
    SCRIPT_DIR="$(pwd)"
  fi
else
  # Not running under SLURM, use $0
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

# Input file path (directly specified relative to script directory)
INPUT_FILE="${SCRIPT_DIR}/thm_co2_example/co2_thm_2d_buoyancy.i"

# Verify input file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file not found: $INPUT_FILE"
  echo "Script directory: $SCRIPT_DIR"
  echo "SLURM_SUBMIT_DIR: ${SLURM_SUBMIT_DIR:-not set}"
  echo "Current dir: $(pwd)"
  exit 1
fi

# Change to input file directory
cd "$(dirname "$INPUT_FILE")" || {
  echo "Error: Cannot cd to $(dirname "$INPUT_FILE")"
  exit 1
}

# ============================================================================
# Checkpoint Recovery Configuration
# ============================================================================
# By default this script starts fresh (Restart mode: NO). To continue from
# the previous run's latest checkpoint, submit with:
#
#   RESTART_FROM=latest sbatch submit_co2_2d_buoyancy.sh
#
# Other options:
#   RESTART_FROM=100             # Restart from checkpoint number 100
#   RESTART_FROM=list            # List available checkpoints and exit
# ============================================================================
# Checkpoint path: must match [Outputs] checkpoint file_base in the input file.
# file_base = co2_thm_2d_buoyancy_out_cp/cp -> MOOSE writes to .../cp_cp/ (subdir).
CP_DIR="co2_thm_2d_buoyancy_out_cp/cp_cp"
RECOVER_ARG=""

# Function to find latest checkpoint
find_latest_checkpoint() {
  local cp_dir="$1"
  # MOOSE checkpoints: <number>-mesh.cpa.gz, <number>-mesh.cpr, <number>-mesh.xdr
  # We look for mesh.cpa.gz files as they're the most reliable indicator
  local latest_mesh=$(ls -d "${cp_dir}"/[0-9]*-mesh.cpa.gz 2>/dev/null | sort -V | tail -1)
  if [ -n "$latest_mesh" ]; then
    basename "$latest_mesh" -mesh.cpa.gz
  else
    # Fallback: try .cpr files
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
  
  # Find all checkpoint numbers
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
    [ -e "${cp_base}-mesh.xdr" ] && files="${files} mesh.xdr"
    [ -e "${cp_base}.rd" ] && files="${files} .rd"
    [ -e "${cp_base}-restart-0.rd" ] && files="${files} -restart-0.rd"
    
    if [ -n "$files" ]; then
      echo "  $cp_num: $files"
    fi
  done
  
  local latest=$(find_latest_checkpoint "$cp_dir")
  if [ -n "$latest" ]; then
    echo ""
    echo "Latest checkpoint: $latest"
  fi
  echo "=========================================="
}

# Function to validate checkpoint
# Note: MOOSE may write -mesh.cpa.gz and -restart-0.rd as dirs or files; use -e (exists)
validate_checkpoint() {
  local cp_dir="$1"
  local cp_num="$2"
  local cp_base="${cp_dir}/${cp_num}"
  
  # Check if essential mesh checkpoint exists (file or directory)
  if [ ! -e "${cp_base}-mesh.cpa.gz" ] && [ ! -e "${cp_base}-mesh.cpr" ]; then
    echo "Error: Checkpoint $cp_num is incomplete (missing mesh files)"
    return 1
  fi
  
  if [ ! -e "${cp_base}.rd" ] && [ ! -e "${cp_base}-restart-0.rd" ]; then
    echo "Warning: Checkpoint $cp_num may be incomplete (missing .rd file)"
    echo "         Continuing anyway, but restart may fail..."
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
        echo "         Starting simulation from beginning"
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
      # User specified checkpoint number
      if validate_checkpoint "$CP_DIR" "${RESTART_FROM}"; then
        RECOVER_ARG="--recover ${CP_DIR}/${RESTART_FROM}"
        echo "Restarting from checkpoint: $RESTART_FROM"
      else
        echo "Error: Checkpoint ${RESTART_FROM} is invalid or incomplete"
        echo ""
        echo "Available checkpoints:"
        list_checkpoints "$CP_DIR"
        exit 1
      fi
      ;;
  esac
else
  # Check if checkpoints exist and warn user
  latest_cp=$(find_latest_checkpoint "$CP_DIR")
  if [ -n "$latest_cp" ]; then
    echo "=========================================="
    echo "Notice: Checkpoints found but RESTART_FROM not set"
    echo "Latest checkpoint: $latest_cp"
    echo ""
    echo "To restart from checkpoint, set:"
    echo "  export RESTART_FROM=latest    # Use latest"
    echo "  export RESTART_FROM=$latest_cp  # Use specific checkpoint"
    echo "  export RESTART_FROM=list      # List all checkpoints"
    echo "=========================================="
    echo "Starting fresh simulation..."
  fi
fi

# Display checkpoint information if restarting
if [ -n "$RECOVER_ARG" ]; then
  echo ""
  echo "Checkpoint Recovery Information:"
  echo "  Checkpoint directory: ${CP_DIR}/"
  echo "  Checkpoint number: ${RESTART_FROM}"
  echo "  Recovery argument: ${RECOVER_ARG}"
  echo ""
fi

# Run MOOSE simulation
echo "=========================================="
echo "Running MOOSE Simulation"
echo "=========================================="
echo "Executable: $MOOSE_EXE"
echo "Input file: $(basename "$INPUT_FILE")"
echo "Working directory: $(pwd)"
echo "OpenMP threads: ${MOOSE_N_THREADS} (OMP_NUM_THREADS=${OMP_NUM_THREADS}, --n-threads=${MOOSE_N_THREADS})"
if [ -n "$RECOVER_ARG" ]; then
  echo "Restart mode: YES (${RECOVER_ARG})"
else
  echo "Restart mode: NO (fresh start)"
fi
echo "=========================================="
echo ""

# Run MOOSE with --n-threads parameter for OpenMP parallelization
# CRITICAL: MOOSE requires --n-threads flag in addition to OMP_NUM_THREADS environment variable
# Use --n-threads=N format; thread count capped above to avoid LibMeshInit abort on some builds.
"$MOOSE_EXE" -i "$(basename "$INPUT_FILE")" --n-threads="${MOOSE_N_THREADS}" ${RECOVER_ARG}
