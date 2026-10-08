# Installation

## Recommended: Docker

Docker is the supported cross-platform environment. It pins:

| Component | Version |
|---|---:|
| R | 4.5.2 |
| Bioconductor | 3.21 |
| Quarto | 1.8.26 |

Follow [docker.md](docker.md) to build the image and run the environment check.

## Native installation

Native use is helpful during development but may expose operating-system
differences. Install R 4.5, Quarto 1.8, and compilation tools before running:

```bash
Rscript scripts/install_dependencies.R
Rscript scripts/check_environment.R
```

The dependency installer covers the main report, Excel exporter, maSigPro, and
Mfuzz. Use the non-installing check in automation:

```bash
Rscript scripts/install_dependencies.R --check-only
```

### Windows

- Install the Rtools release matching R.
- Ensure both `Rscript` and `quarto` are on `PATH`.
- Use PowerShell, Command Prompt, Git Bash, or an R-aware IDE.

### macOS

- Install Xcode Command Line Tools if packages must be compiled.
- A native Mfuzz installation may load Tcl/Tk and can require XQuartz. The
  Docker image uses Linux libraries and does not require XQuartz.

### Linux

- Install a C/C++/Fortran toolchain and the development libraries represented
  in the Dockerfile.
- Distribution package names vary; the Dockerfile is the authoritative Ubuntu
  dependency list.

## Additional organism packages

Human GO annotation is installed by default. For another organism, install its
Bioconductor `OrgDb` package and set `organism_package` in the YAML. For
example, mouse analyses commonly use `org.Mm.eg.db`. Disable GSEA when no
appropriate mapping exists.
