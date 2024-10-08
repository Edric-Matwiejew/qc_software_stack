# Ella QC Software Stack

This setup installs and configures the following tcl modules:

* CMake
* Ninja-build
* Python
* cuTENSOR
* cuPY
* cuQUANTUM
* cuQUANTUM-python
* HIP
	- hipBLAS
	- hipSOLVER
	- hipRAND
	- hipFORT
* Spack

## Installation

1. Edit the `DATE_TAG` variable in `settings.sh`.
2. Setup `$MODULEPATH`:
    ```bash
    export MODULEPATH=/opt/nvidia/hpc_sdk/modulefiles:$MYSOFTWARE/../modules/$DATE_TAG:$MODULEPATH
    ```
3. From the project root directory, run the following command:

    ```bash
    bash scripts/install_software_stack.sh
    ```

## Usage

Configure the environment variables:

```bash
export DATE_TAG=<date_tag>
export PAWSEY_PROJECT=<my_project>
export MYSOFTWARE=/pawsey/software/projects/<my_project>/<my_folder>
export MODULEPATH=/opt/nvidia/hpc_sdk/modulefiles:$MYSOFTWARE/../modules/$DATE_TAG:$MODULEPATH
```

## Notes

### Python
* Installed Python versions are specified by the `PYTHON_VERSIONS` variable in `settings.sh`.
* The Python user site and base are:
    ```bash
    PYTHONUSERSITE=PYTHONUSERBASE=$MYSOFTWARE/software/ella/$DATE_TAG/python-$PYTHON_VERSION
    ```

### cuPY and cuQUANTUM Python
* cuPY and cuQuantum will be built for all specified Python versions.

### Spack
* User cache, configuration, modules, and install tree are located under:
    ```bash
    $MYSOFTWARE/ella/$DATE_TAG/spack-$SPACKVERSION
    ```
* Spack is configured to generate tcl module files. To use them, add `$MYSOFTWARE/ella/$DATE_TAG/spack-$SPACKVERSION/modules` to your `MODULEPATH`. 
