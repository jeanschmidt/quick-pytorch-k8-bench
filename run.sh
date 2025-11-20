#!/usr/bin/env bash

function pip_build_and_install() {
  local build_target=$1
  local wheel_dir=$2

  local found_whl=0
  for file in "${wheel_dir}"/*.whl
  do
    if [[ -f "${file}" ]]; then
      found_whl=1
      break
    fi
  done

  # Build the wheel if it doesn't exist
  if [ "${found_whl}" == "0" ]; then
    python3 -m pip wheel \
      --no-build-isolation \
      --no-deps \
      --no-use-pep517 \
      -w "${wheel_dir}" \
      "${build_target}"
  fi

  for file in "${wheel_dir}"/*.whl
  do
    pip_install_whl "${file}"
  done
}

function pip_install_whl() {
  # This is used to install PyTorch and other build artifacts wheel locally
  # without using any network connection

  # Convert the input arguments into an array
  local args=("$@")

  # Check if the first argument contains multiple paths separated by spaces
  if [[ "${args[0]}" == *" "* ]]; then
    # Split the string by spaces into an array
    IFS=' ' read -r -a paths <<< "${args[0]}"
    # Loop through each path and install individually
    for path in "${paths[@]}"; do
      echo "Installing $path"
      python3 -mpip install --no-index --no-deps "$path"
    done
  else
    # Loop through each argument and install individually
    for path in "${args[@]}"; do
      echo "Installing $path"
      python3 -mpip install --no-index --no-deps "$path"
    done
  fi
}

function install_torchao() {
  local commit
  commit=$(get_pinned_commit torchao)
  pip_build_and_install "git+https://github.com/pytorch/ao.git@${commit}" dist/ao
}

function get_pinned_commit() {
  cat .github/ci_commit_pins/"${1}".txt
}

echo "[INFO] Starting GPU script at $(date)"
nvidia-smi || echo "[WARN] nvidia-smi failed"
nvidia-smi --query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv || true

set -euox pipefail

pushd /scratch

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

git clone --depth 1 https://github.com/pytorch/pytorch.git
pushd pytorch

git submodule sync && git submodule update --init --recursive
pip3 install -r requirements.txt
source .ci/pytorch/common_utils.sh
source .ci/pytorch/common-build.sh

/usr/local/bin/aws s3 cp s3://gha-artifacts/pytorch/pytorch/19492723921/linux-jammy-cuda12.8-py3.10-gcc11-sm80/artifacts.zip artifacts.zip --region us-east-1
unzip artifacts.zip
ls -l dist/
python3 -m pip install dist/*.whl

install_torchao

mkdir -p /scratch/result
for i in $(seq 0 5); do
  python benchmarks/gpt_fast/benchmark.py --output "/scratch/result/gpt_fast_benchmark_$i.csv"
done

popd
pushd /scratch/result

NOW_REF=$(date +%s)
tar -czf "./gpt_fast_benchmarks_$NOW_REF.tar.gz" gpt_fast_benchmark_*.csv
aws s3 cp "./gpt_fast_benchmarks_$NOW_REF.tar.gz" s3://camyllhtest/jean-test/gpt_fast_benchmarks_$NOW_REF.tar.gz --region us-east-1

popd
popd
