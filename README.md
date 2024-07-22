Sure, here's a revised version of your readme with some adjustments for clarity and consistency:

---

# Ella QC Software Stack

This setup installs and configures the following tcl modules:

* cmake
* ninja
* python
* cutensor
* cupy
* cuquantum
* cuquantum-python
* HIP
	- HIP
	- hipBLAS
	- hipSOLVER
	- hipRAND
	- hipFORT
* spack

## Usage

1. Edit the `DATE_TAG` variable in `settings.sh`.
2. From the project root directory, run the following command:

    ```bash
    bash scripts/install_software_stack.sh
    ```

3. Configure the environment variables:

    ```bash
    export DATE_TAG=<date_tag>
    export PAWSEY_PROJECT=<my_project>
    export MYSOFTWARE=/pawsey/software/projects/<my_project>/$USER
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
