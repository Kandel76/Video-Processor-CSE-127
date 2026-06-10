Running 'make oas' in main directory will create the oas file described in "photodiode\_layout.py"

Below are the steps for manually doing so:

Install uv:
    curl -LsSf https://astral.sh/uv/install.sh | sh

Set up virtual environment and activate:
    uv venv --python 3.12
    source .venv/bin/activate

Install gdsfactory:
    uv pip install gdsfactory

Clone OPENIMAGESENSOR and gf180mcu:
    git clone https://github.com/njcoburn/OPENIMAGESENSOR.git
    cd OPENIMAGESENSOR && git clone https://github.com/QuantamHD/gf180mcu.git
    cd gf180mcu && git checkout ethan\_branch
    make

Set up virtual environment again and activate:
    uv sync
    source .venv/bin/activate

Go back to OPENIMAGESENSOR and run script:
    cd ..
    python3 test.py


