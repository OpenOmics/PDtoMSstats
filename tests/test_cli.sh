#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
test_root=$(mktemp -d "${TMPDIR:-/tmp}/pdtomsstats-cli.XXXXXX")
trap 'rm -rf "$test_root"' EXIT

bash -n "$repo_root/pdtomsstats"
version_output=$("$repo_root/pdtomsstats" version)
grep -q '^PDtoMSstats: 0.2.1$' <<< "$version_output"

project="$test_root/group-project"
"$repo_root/pdtomsstats" init \
  --project "$project" \
  --modules main,timecourse \
  --request group-project \
  --label "Group project"
project=$(cd "$project" && pwd -P)

for directory in config data logs results tmp .pdtomsstats; do
  test -d "$project/$directory"
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
grep -q '^PDTOMSSTATS_WORKFLOW_VERSION=0.2.1$' "$runtime_args"
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
  printf 'printf "Submitted batch job 4242\\n"\n'
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

echo "Standardized command launcher: PASS"
