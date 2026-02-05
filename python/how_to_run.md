
**Create your conda environment** 
1. Install miniconda
2. Check that you have conda installed. In the terminal (it can be pycharm terminal): `conda --version`
3. Create a conda environment named ei_maps. In the terminal: `conda create -n ei_maps` By default this environment is 
saved in C:\Users\Cristina\miniconda3\envs\ei_maps
4. Activate the environment: `conda activate ei_maps`
5. Create a new pycharm interpreter named ei_maps. Click in the lower right corner of pycharm (.venv). 
Add new interpreter -> Add local interpreter. Environment: select existing. Type: conda, Name: ei_maps

**Install dependencies**
1. Install **neuromaps** from github. Clone the repository into repos/neuromaps. In the terminal
`pip install -e ../neuromaps/`
2. Install **netneurotools** from github (branch 0.2.X). `pip install -e ../netneurotools/`
3. Install tqdm

# Info
https://netneurolab.github.io/netneurotools/installation.html