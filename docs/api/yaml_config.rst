*******************************************************************************
YAML Configuration Reference
*******************************************************************************

LiCoRICE uses YAML configuration files to specify the model that will be constructed and run.


Models
===============================================================================

Models define the architecture of your real-time analysis pipeline from data
acquisition (sources) to processing (modules) to output (sinks). Models are
defined through `yaml <https://www.cloudbees.com/blog/yaml-tutorial-everything-you-need-get-started>`_
files and are broken up into the following sections:

* :ref:`api/yaml_config:config`
* :ref:`api/yaml_config:signals`
* :ref:`api/yaml_config:modules`


Config
-------------------------------------------------------------------------------

High-level configuration variables are set by the user here. Here we define aspects of the setup, timing, and ticks(our metric of time) in order to control the way our system interacts with the real world.

================= =============================================================
Keyword           Usage
================= =============================================================
tick_len          Set the time per tick in microseconds
num_ticks         Number of ticks to run the model for
init_buffer_ticks Number of ticks to run sources before modules start
================= =============================================================

TODO:

* source_init_ticks
* module_init_ticks
* sink_init_ticks


Signals
-------------------------------------------------------------------------------

Here we define how data will be passed between our modules. We also define how much of this data to keep over time and how to store it if necessary for our use case. At a high-level, signals are represented as NumPy arrays in our modules. However, in implementation, they are actually shared arrays, shared memory that allows for the fast transfer of data between models required for real-time analysis.


============= ===============================================================
Keyword       Usage
============= ===============================================================
shape         The shape of the incoming data as a NumPy array
dtype         The type of the data
history       How many ticks worth of data to keep
log           Whether or not to log the signal
log_storage   Specifications for how to log the data (see examples )
============= ===============================================================


Modules
-------------------------------------------------------------------------------

Modules are the primary building blocks of licorice. Here we define the name of our module, the language it's in (python or C), what signals, if any, will be streaming in, and what signals, if any, will be streaming out. We also define whether this module will use a parser to read or write external signals, a constructor to prepare data or initialize processes, or a destructor to stop processes or clean data.

LiCoRICE will automatically detect whether a module is a source, sink, or
internal module given the signals attributed to that module.

============ ==================================================================
Keyword      Usage
============ ==================================================================
language     The programming language used to write the module (Python or C)
constructor  Indicates that a constructor is used to initialize the module
parser       Indicates that a parser is used to read data from an external source
destructor   Indicates that a destructor is used to correctly breakdown a module
in           Under this key, you define each of your inputs for this module
out          Under this key, you define each of your outputs for this module
============ ==================================================================

External Signals
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

External signals are information that is passed in and out of our model. Having an external signal is what defines modules as either a sink or a source(any module should only ever have one). Given the inherent complexity of dealing with external devices or applications, additional information is needed to define these signals.

TODO

* in-built source drivers
* in-built sink drivers

Example Model
===============================================================================

.. code-block:: yaml
    :linenos:

    config:

      tick_len: 100000 # in microseconds
      # number of ticks to run for; defaults to None (run until terminated by the user)
      num_ticks: 10


    signals:

      signal_1:
        shape: (2, 2) # All signals are be treated as numpy arrays
        dtype: float64
        history: 1 # How much previous data to keep on the signal in the system

       signal_2:
        shape: 1 # Signals can also be 1D
        dtype: float64


    modules:

      sum_init:
          language: python  # can be C or python
          constructor: True. # signifies we will use a constructor
          in:   # An External Signal (Joystick in USB)
            name: jdev
            args:
                type: usb_input
            schema:
                max_packets_per_tick: 1 # defaults to 1 for sync, None for async
                data:
                    dtype: double
                    size: 2
          out:
            - signal_1

        sum:
            language: python
            in:
                - signal_1
            out:
                - signal_2

        sum_print:
            language: python
            in:
              - signal_2
