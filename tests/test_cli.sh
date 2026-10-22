#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/pdtomsstats-cli.XXXXXX")
trap 'rm -rf "$test_root"' EXIT

bash -n "$repo_root/pdtomsstats"
version_output=$("$repo_root/pdtomsstats" version)
grep -q '^PDtoMSstats: 0.2.4$' <<< "$version_output"

project="$test_root/group-project"
"$repo_root/pdtomsstats" init \
  --project "$project" \
  --modules main,timecourse \
  --request group-project \
  --label "Group project"
project=$(cd "$project" && pwd -L)

for directory in config data logs results tmp .pdtomsstats; do
  test -d "$project/$directory"
done
for directory in main figures supporting timecourse; do
  test -d "$project/results/$directory"
done
for file in \
  config/group-project-main.yml \
  config/group-project-timecourse.yml \
  config/group-project-contrasts.tsv \
  .pdtomsstats/project.yml; do
  test -f "$project/$file"
done

grep -q 'request: "group-project"' "$project/config/group-project-main.yml"
grep -q 'report_label: "Group project"' "$project/config/group-project-main.yml"
grep -q "output_dir: \"$project/results\"" "$project/config/group-project-main.yml"
grep -q 'modules: "main,timecourse"' "$project/.pdtomsstats/project.yml"

printf '\n# keep-me\n' >> "$project/config/group-project-main.yml"
"$repo_root/pdtomsstats" init \
  --project "$project" --modules main,timecourse --request group-project
grep -q '# keep-me' "$project/config/group-project-main.yml"

"$repo_root/pdtomsstats" init \
  --project "$project" --modules main,timecourse --request group-project --force
if grep -q '# keep-me' "$project/config/group-project-main.yml"; then
  echo "--force did not replace the generated template" >&2
  exit 1
fi

# Exercise command construction without requiring Apptainer in CI.
fake_runtime="$test_root/fake-apptainer"
fake_image="$test_root/pdtomsstats.sif"
fake_profile="$test_root/test-profile.yml"
runtime_args="$test_root/runtime-args.txt"
touch "$fake_image"
{
  printf '#!/usr/bin/env bash\n'
  printf 'printf "APPTAINERENV_HOME=%%s\\n" "${APPTAINERENV_HOME-unset}" > "$PDT_TEST_ARGS"\n'
  printf 'printf "SINGULARITYENV_HOME=%%s\\n" "${SINGULARITYENV_HOME-unset}" >> "$PDT_TEST_ARGS"\n'
  printf 'printf "APPTAINER_TMPDIR=%%s\\n" "${APPTAINER_TMPDIR-unset}" >> "$PDT_TEST_ARGS"\n'
  printf 'printf "SINGULARITY_TMPDIR=%%s\\n" "${SINGULARITY_TMPDIR-unset}" >> "$PDT_TEST_ARGS"\n'
  printf 'printf "%%s\\n" "$@" >> "$PDT_TEST_ARGS"\n'
} > "$fake_runtime"
chmod +x "$fake_runtime"
{
  printf 'runtime: "%s"\n' "$fake_runtime"
  printf 'module: null\n'
  printf 'image: "%s"\n' "$fake_image"
  printf 'group: null\ndefault_mode: slurm\ncontainall: true\ncleanenv: true\n'
} > "$fake_profile"
fake_profile=$(cd "$(dirname "$fake_profile")" && pwd -P)/$(basename "$fake_profile")

"$repo_root/pdtomsstats" init \
  --project "$project" --profile "$fake_profile" --modules main,timecourse \
  --request group-project >/dev/null
"$repo_root/pdtomsstats" init --project "$project" >/dev/null
grep -Fq "profile: \"$fake_profile\"" "$project/.pdtomsstats/project.yml"
grep -q 'modules: "main,timecourse"' "$project/.pdtomsstats/project.yml"

export PDT_TEST_ARGS="$runtime_args"
export APPTAINERENV_HOME=/host/home
export SINGULARITYENV_HOME=/host/home
export SINGULARITY_TMPDIR=/legacy/tmp
"$repo_root/pdtomsstats" run \
  --project "$project" --profile "$fake_profile" \
  --mode local \
  --job-tmp "$project/tmp" \
  --config "$project/config/group-project-main.yml" --outputs html
unset APPTAINERENV_HOME SINGULARITYENV_HOME SINGULARITY_TMPDIR

grep -q '^APPTAINERENV_HOME=unset$' "$runtime_args"
grep -q '^SINGULARITYENV_HOME=unset$' "$runtime_args"
grep -Fq "APPTAINER_TMPDIR=$project/tmp" "$runtime_args"
grep -q '^SINGULARITY_TMPDIR=unset$' "$runtime_args"
grep -q '^--containall$' "$runtime_args"
grep -q '^--cleanenv$' "$runtime_args"
grep -Fq "$repo_root:/opt/PDtoMSstats:ro" "$runtime_args"
grep -Fq "$project:$project" "$runtime_args"
grep -q '^PDTOMSSTATS_WORKFLOW_VERSION=0.2.4$' "$runtime_args"
grep -Fq "PDTOMSSTATS_CONTAINER_IMAGE=$fake_image" "$runtime_args"
grep -Fq "PDTOMSSTATS_EXECUTION_PROFILE=$fake_profile" "$runtime_args"
grep -q '^PDTOMSSTATS_EXECUTION_MODE=local$' "$runtime_args"
if grep -Eq '(^|,)HOME=' "$runtime_args"; then
  echo "Apptainer invocation must not override HOME" >&2
  exit 1
fi

fake_bin="$test_root/bin"
mkdir -p "$fake_bin"
{
  printf '#!/usr/bin/env bash\n'
  printf 'if [[ -n "${PDT_TEST_SBATCH_COUNTER:-}" ]]; then\n'
  printf '  count=$(cat "$PDT_TEST_SBATCH_COUNTER" 2>/dev/null || printf 5000)\n'
  printf '  count=$((count + 1))\n'
  printf '  printf "%%s\\n" "$count" > "$PDT_TEST_SBATCH_COUNTER"\n'
  printf '  printf "Submitted batch job %%s\\n" "$count"\n'
  printf 'else\n'
  printf '  printf "Submitted batch job 4242\\n"\n'
  printf 'fi\n'
} > "$fake_bin/sbatch"
chmod +x "$fake_bin/sbatch"
PATH="$fake_bin:$PATH" "$repo_root/pdtomsstats" run \
  --project "$project" --profile "$fake_profile" \
  --config "$project/config/group-project-main.yml" --outputs html \
  --cpus 4 --memory 80G --walltime 06:00:00 >/dev/null
test "$(cat "$project/.pdtomsstats/last-job-id")" = 4242
job_script=$(cat "$project/.pdtomsstats/last-job-script")
test -f "$job_script"
grep -q '^#SBATCH --cpus-per-task=4$' "$job_script"
grep -q '^#SBATCH --mem=80G$' "$job_script"
grep -q '^#SBATCH --time=06:00:00$' "$job_script"
grep -Fq -- 'run --mode local' "$job_script"
grep -q '^export PDTOMSSTATS_EXECUTION_MODE=slurm$' "$job_script"
grep -Fq -- '--outputs html' "$job_script"

PATH="$fake_bin:$PATH" "$repo_root/pdtomsstats" run --mode slurm \
  --project "$project" --profile "$fake_profile" \
  --config "$project/config/group-project-main.yml" --outputs html >/dev/null

# Convention-based batches validate all inputs first, then submit one Slurm
# job per PSM/protein pair and retain a combined job registry.
touch "$project/data/annotation.xlsx"
touch "$project/data/bma-il10__PSM.TXT"
touch "$project/data/bma-il10__Proteins.XLSX"
touch "$project/data/tmes-il13__psm.xlsx"
touch "$project/data/tmes-il13__protein.xlsx"
touch "$project/config/bma-il10__contrasts.tsv"
sbatch_counter="$test_root/sbatch-counter.txt"
export PDT_TEST_SBATCH_COUNTER="$sbatch_counter"
PATH="$fake_bin:$PATH" "$repo_root/pdtomsstats" run \
  --project "$project" --profile "$fake_profile" \
  --batch --outputs html,excel >/dev/null
unset PDT_TEST_SBATCH_COUNTER
test "$(cat "$sbatch_counter")" = 5002
batch_file=$(cat "$project/.pdtomsstats/last-batch")
test -f "$batch_file"
test "$(wc -l < "$batch_file" | tr -d ' ')" = 3
grep -q $'^bma-il10\tslurm\t500[12]\t' "$batch_file"
grep -q $'^tmes-il13\tslurm\t500[12]\t' "$batch_file"
test "$(cut -f3 "$batch_file" | tail -n +2 | sort | paste -sd, -)" = "5001,5002"
test "$(cut -f4 "$batch_file" | tail -n +2 | sort -u | wc -l | tr -d ' ')" = 2
bma_job_script=$(awk -F '\t' '$1 == "bma-il10" {print $4}' "$batch_file")
grep -Fq -- "--contrast-file $project/config/bma-il10__contrasts.tsv" \
  "$bma_job_script"
batch_status=$(
  PATH="$fake_bin:$PATH" "$repo_root/pdtomsstats" status \
    --project "$project" --batch
)
grep -Eq 'bma-il10.*job=500[12]' <<< "$batch_status"
grep -Eq 'tmes-il13.*job=500[12]' <<< "$batch_status"

missing_pair_project="$test_root/missing-pair-project"
"$repo_root/pdtomsstats" init \
  --project "$missing_pair_project" --profile "$fake_profile" \
  --modules main --request missing-pair >/dev/null
touch "$missing_pair_project/data/annotation.xlsx"
touch "$missing_pair_project/data/unpaired__psm.csv"
if PATH="$fake_bin:$PATH" "$repo_root/pdtomsstats" run \
  --project "$missing_pair_project" --batch --outputs html,excel \
  >"$test_root/missing-pair.out" 2>&1; then
  echo "Batch submission accepted an Excel analysis without a protein workbook" >&2
  exit 1
fi
grep -q 'Excel output requires one matching' "$test_root/missing-pair.out"

ambiguous_pair_project="$test_root/ambiguous-pair-project"
"$repo_root/pdtomsstats" init \
  --project "$ambiguous_pair_project" --profile "$fake_profile" \
  --modules main --request ambiguous-pair >/dev/null
touch "$ambiguous_pair_project/data/annotation.xlsx"
touch "$ambiguous_pair_project/data/mixed__PSM.xlsx"
touch "$ambiguous_pair_project/data/mixed__protein.xlsx"
touch "$ambiguous_pair_project/data/mixed__PROTEINS.XLSX"
if PATH="$fake_bin:$PATH" "$repo_root/pdtomsstats" run \
  --project "$ambiguous_pair_project" --batch --outputs html,excel \
  >"$test_root/ambiguous-pair.out" 2>&1; then
  echo "Batch submission accepted ambiguous protein workbooks" >&2
  exit 1
fi
grep -q 'multiple protein workbooks match analysis mixed' \
  "$test_root/ambiguous-pair.out"

# A logical data path and its resolved physical path must both be available
# inside Apptainer. This models the Biowulf /data -> /vf/users mapping without
# creating any symlink in the user's project or home directory.
alias_physical_root="$test_root/vf-users/Proteomics_IDSS"
alias_logical_root="$test_root/data/Proteomics_IDSS"
mkdir -p "$alias_physical_root" "$(dirname "$alias_logical_root")"
ln -s "$alias_physical_root" "$alias_logical_root"
alias_logical_root=$(cd "$alias_logical_root" && pwd -L)
alias_project="$alias_logical_root/alias-project"
"$repo_root/pdtomsstats" init \
  --project "$alias_project" --modules main --request alias-project >/dev/null
grep -Fq "output_dir: \"$alias_project/results\"" \
  "$alias_project/config/alias-project-main.yml"

alias_project_physical=$(cd "$alias_project" && pwd -P)
alias_profile="$test_root/alias-profile.yml"
{
  printf 'runtime: "%s"\n' "$fake_runtime"
  printf 'module: null\n'
  printf 'image: "%s"\n' "$fake_image"
  printf 'group: null\ndefault_mode: local\ncontainall: true\ncleanenv: true\n'
  printf 'path_alias_root: "%s"\n' "$alias_logical_root"
} > "$alias_profile"

"$repo_root/pdtomsstats" run \
  --project "$alias_project_physical" --profile "$alias_profile" \
  --mode local --job-tmp "$alias_project_physical/tmp" \
  --config "$alias_project/config/alias-project-main.yml" --outputs html
grep -Fq "$alias_project_physical:$alias_project_physical" "$runtime_args"
grep -Fq "$alias_project_physical:$alias_project" "$runtime_args"
grep -Fq "$alias_project/config/alias-project-main.yml" "$runtime_args"

echo "Standardized command launcher: PASS"
