# Contributing

Contributions that improve portability, input validation, documentation, or
scientific reporting are welcome.

## Before opening a pull request

1. Do not commit project data, sample identifiers, rendered reports, or RDS
   files. The only tracked analysis input is the reviewed synthetic-ID example.
2. Keep experiment-specific values in YAML configuration files, not in the
   generalized report.
3. Run the repository check:

   ```bash
   Rscript tests/test_structure.R
   Rscript tests/test_example_data.R
   Rscript tests/test_wrapper_functions.R
   bash tests/test_cli.sh
   ```

4. Run the bundled example through the container when analysis or dependency
   code changes.
5. Describe any change that could affect numerical results or comparison
   direction.

Keep HPC runtime, bind, scheduler, and group defaults in
`config/profiles/`. Keep project scaffolding in `config/templates/`. Do not
put site-specific execution policy into the R analysis or Quarto report code.

## Reporting a problem

Include:

- R and Quarto versions.
- The failing command.
- The complete error message.
- Workbook column names and worksheet names.
- A minimal de-identified example if one can be shared safely.
