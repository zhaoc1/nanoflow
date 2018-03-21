## Installation

1. Clone Jesse's conda-gcc5 repository and create an new environment `nanoflow` with GCC5 installed
  
  ```bash
  git clone https://github.com/ressy/conda-gcc5.git
  bash setup.py nanoflow
  ```
2. Clone this repository into a local directory and activate minions environment
  ```bash
  git clone https://github.com/zhaoc1/nanoflow.git nanoflow
  cd nanoflow
  source activate nanoflow
  conda install --file conda-requirements.txt
  ```
 
3. Clone Ryan Wick's Basecalling-comparison repository
  ```bash
  mkdir local
  cd local
  git clone https://github.com/rrwick/Basecalling-comparison.git
  ```

4. Download other packages into local directory
  ```bash
  ## Nanopolish v0.9.0
  git clone --recursive https://github.com/jts/nanopolish.git
  cd nanopolish
  make
  ```

## Usage
