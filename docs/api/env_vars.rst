******************************************************************************
Environment Variables
******************************************************************************

LiCoRICE uses the following environment variables to search for files and set output directories:


Paths
===============================================================================

The following environment variables instruct LiCORICE where to look for certain files and use PATH-style lists of paths separated by your OS'es path separator (commonly `:` for Linux).

``LICORICE_WORKING_PATH``

Overrides LiCoRICE base working path. The default path is the current working directory where LiCoRICE has been run from. A warning will be issued if this is not set. Set ``LICORICE_WORKING_PATH=.`` to suppress the warning and use the default behavior.

``LICORICE_TEMPLATE_PATH``

Overrides LiCoRICE's template search path. The default path is ``licorice/templates`` in the repo directory.

``LICORICE_GENERATOR_PATH``

Overrides LiCoRICE's generator search path. The default path is ``licorice/generators`` in the repo directory.

``LICORICE_MODULE_PATH``

Overrides LiCoRICE's module search path. The default path is the concatenation of the ``working_path`` and ``<working_path>/modules``.

``LICORICE_MODEL_PATH``

Overrides LiCoRICE's model search path. The default path is the concatenation of the ``working_path`` and ``<working_path>/models``.


Directories
===============================================================================

``LICORICE_OUTPUT_DIR``

Directory to output the LiCoRICE model. This is where rendered templates and compiled executables will live for a given model. The default is ``<working_path>/<model_name>.lico/out`` for the CLI and ``<working_path>/run.lico/out`` for the Python API.

``LICORICE_EXPORT_DIR``

Directory to export the LiCoRICE model. The default is ``<working_path>/<model_name>.lico/export`` for the CLI and ``<working_path>/run.lico/export`` for the Python API.

``LICORICE_TMP_MODULE_DIR``

Directory to move old LiCoRICE modules. This is used by the ``generate`` command to prevent accidental deletion of modules. The default is ``<working_path>/.modules``.

``LICORICE_TMP_OUTPUT_DIR``

Directory to output LiCoRICE model. This is where rendered templates and compiled executables will live for a given model. The default is ``<working_path>/<model_name>.lico/.out`` for the CLI and ``<working_path>/run.lico/.out`` for the Python API.
