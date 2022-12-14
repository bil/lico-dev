*******************************************************************************
Development Environment Setup
*******************************************************************************

#. Clone the LiCoRICE repository.

#. Python virtualenv setup

    From the top-level LiCoRICE directory, run:

    .. code-block:: bash

        ./install/env_setup.sh

    This script will take 15 to 30 minutes to complete.

#. `Install pyenv and pyenv-virtualenv in your shell config. <https://github.com/pyenv/pyenv#set-up-your-shell-environment-for-pyenv>`_ Bash users can use the following:

    .. code-block:: bash

        cat ./install/pyenv_config.sh >> ~/.bashrc
        if [ -f "~/.bash_profile" ]; then
          cat ./install/pyenv_config.sh >> ~/.bash_profile
        else
          cat ./install/pyenv_config.sh >> ~/.profile
        fi
        source ~/.bashrc

#. Bind to the newly built virtualenv:

    .. code-block:: bash

        pyenv activate licorice

    Or alternatively include a ``.python-version`` file in the top-level LiCoRICE directory with the single line:

    .. code-block::

        licorice

#. Ensure Correct Permissions

    .. include:: ../partials/_permissions.rst

#. Optional - Modify BIOS settings and compile realtime kernel.

    .. include:: ../partials/_rt_setup.rst
