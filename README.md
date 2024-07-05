# REopt API for MG-RAVENS project

This repository contains a "run" script, an example input file, and the Julia environment configuration (.toml files) to run a custom version of the REopt.jl Julia package for the MG-RAVENS API tool set. This allows interfacing with REopt.jl through the MG-RAVENS standardized JSON schema, which is based on the Common Information Model (CIM) for energy system transmission and distribution.

### Instructions

1. Provide an inputs file (or use the example REopt_example.json) in the MG-RAVENS schema. The name of this file should be the first argument when calling this script from the CLI (or update the first element in the ARGS list in the run script if running within a Julia REPL). Note, the example provided contains all the inputs that REopt would use. REopt will ignore other inputs that are not relevant for REopt. A Word Doc is also provided with comments to help explain how the input data are used with different linkages across data fields/keys.
2. Run the command below from the command line, after "cd"ing into the directory of this repository. If you are running this script in your own Julia environment (not the one defined by this Project.toml and Manifest.toml), then make sure you've `add`ed `REopt#mg-ravens` to your environment instead of the main REopt version. The second argument of this command is the output file, which is actually just the same input data file with results data/fields added or updated to it. 
```
 julia --project=. mgravens_run.jl "REopt_example.json" "mgravens_out.json"
 ```

- If you want to run the script from within a Julia REPL, update the `ARGS` list with the appropriate inputs and outputs file in the `mgravens_run.jl` file, and then run `include("mgravens_run.jl")` from the REPL.