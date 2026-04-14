#!/bin/bash
#SBATCH --job-name=co2_thm_60mpi
#SBATCH --account=hai_1214
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=40
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --partition=booster
# #SBATCH --gres=gpu:4

set -euo pipefail

SECONDS=0
TOTAL_TASKS=${SLURM_NTASKS}
PROJECT_ROOT="/p/scratch/hai_1214/$USER/sleipner/moose_input"
DEFAULT_INPUT_FILE="inputs/co2_thm_example_3d_v10_lu_turbo_fast_distributed_thm_pointinj_200x200x100_conservative.i"
INPUT_FILE="${INPUT_FILE:-$DEFAULT_INPUT_FILE}"
RUN_TAG="${RUN_TAG:-$(basename "${INPUT_FILE%.i}")}"
OUTPUT_ROOT="${OUTPUT_ROOT:-outputs/experiments}"
EXODUS_BASE="${EXODUS_BASE:-${OUTPUT_ROOT}/${RUN_TAG}/exodus/co2_thm_out}"
CSV_BASE="${CSV_BASE:-${OUTPUT_ROOT}/${RUN_TAG}/csv/co2_thm_out}"
# Optional: only effective if [Outputs]/[checkpoint] exists in input.
CHECKPOINT_BASE="${CHECKPOINT_BASE:-}"
MOOSE_EXE="$HOME/projects/moose/modules/porous_flow/porous_flow-opt"

echo "========================================================"
echo "Job: ${SLURM_JOB_NAME} (ID: ${SLURM_JOB_ID})"
echo "Nodes: ${SLURM_JOB_NUM_NODES} | Tasks: ${TOTAL_TASKS}"
echo "Input: ${INPUT_FILE}"
echo "Run tag: ${RUN_TAG}"
echo "Exodus base: ${EXODUS_BASE}"
echo "CSV base: ${CSV_BASE}"
if [ -n "${CHECKPOINT_BASE}" ]; then
  echo "Checkpoint base: ${CHECKPOINT_BASE}"
fi
echo "========================================================"

module --force purge
module load Stages/2025
module load NVHPC/24.9-CUDA-12 OpenMPI/5.0.5
source /p/home/jusers/${USER}/juwels/miniforge/etc/profile.d/conda.sh
conda deactivate
set +u
conda activate moose
set -u
export LD_LIBRARY_PATH="${CONDA_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
unset PETSC_OPTIONS

export OMPI_MCA_btl=tcp,self
export OMPI_MCA_rmaps_base_mapping_policy=slot

if [ -z "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH=/p/software/default/stages/2025/software/NVHPC/24.9-CUDA-12-NVHPC-24.9-CUDA-12/lib64
else
  export LD_LIBRARY_PATH=/p/software/default/stages/2025/software/NVHPC/24.9-CUDA-12-NVHPC-24.9-CUDA-12/lib64:${LD_LIBRARY_PATH}
fi

cd "${PROJECT_ROOT}" || exit 1
mkdir -p logs "$(dirname "${EXODUS_BASE}")" "$(dirname "${CSV_BASE}")"
if [ -n "${CHECKPOINT_BASE}" ]; then
  mkdir -p "$(dirname "${CHECKPOINT_BASE}")"
fi

# Support two common MOOSE output styles:
# 1) [Outputs] file_base = ... + exodus = true  -> use Outputs/file_base
# 2) [Outputs][exodus] file_base = ...          -> use Outputs/exodus/file_base
if grep -Eq "^[[:space:]]*\[exodus\][[:space:]]*$" "${INPUT_FILE}"; then
  EXODUS_ARG="Outputs/exodus/file_base=${EXODUS_BASE}"
else
  EXODUS_ARG="Outputs/file_base=${EXODUS_BASE}"
fi

# Only pass checkpoint override if an active (non-commented) [checkpoint] block exists.
if grep -Eq "^[[:space:]]*\[checkpoint\][[:space:]]*$" "${INPUT_FILE}"; then
  HAS_CHECKPOINT_BLOCK=1
else
  HAS_CHECKPOINT_BLOCK=0
fi

CMD=(
  "${MOOSE_EXE}"
  -i "${INPUT_FILE}"
  "${EXODUS_ARG}"
  "Outputs/csv/file_base=${CSV_BASE}"
)
if [ -n "${CHECKPOINT_BASE}" ]; then
  if [ "${HAS_CHECKPOINT_BLOCK}" -eq 1 ]; then
    CMD+=("Outputs/checkpoint/file_base=${CHECKPOINT_BASE}")
  else
    echo "Note: CHECKPOINT_BASE is set but [checkpoint] is commented/missing in ${INPUT_FILE}; skipping Outputs/checkpoint/file_base override."
  fi
fi

echo ">> ${CMD[*]}"
stdbuf -oL -eL srun -n "${TOTAL_TASKS}" "${CMD[@]}"
EXIT_CODE=$?

echo "========================================================"
echo "End time: $(date)"
echo "Elapsed (s): ${SECONDS}"
echo "Exit code: ${EXIT_CODE}"
echo "========================================================"
exit ${EXIT_CODE}
