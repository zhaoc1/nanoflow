## Installation

1. Clone Jesse's conda-gcc5 directory and create an environment with GCC5 installed
  
  ```bash
  git clone https://github.com/ressy/conda-gcc5.git
  bash setup.py minions
  ```
2. Clone this directory into a local folder and activate minions environment
  ```bash
  git clone https://github.com/zhaoc1/minions-snakemake.git my_minions
  cd my_minions
  source activate minions
  ```
 
3. Clone Ryan Wick's Basecalling-comparison repository
  ```bash
  mkdir local
  cd local
  git clone https://github.com/rrwick/Basecalling-comparison.git
  ```

4. Download other packages into local directory
  ```bash
  ## Canu
  git clone https://github.com/marbl/canu.git
  cd canu/src
  make -j 4
  ## Unicycler
  git clone https://github.com/rrwick/Unicycler.git
  cd Unicycler
  python3 setup.py install
  ## Nanopolish
  git clone --recursive https://github.com/jts/nanopolish.git
  cd nanopolish
  make
  ```
